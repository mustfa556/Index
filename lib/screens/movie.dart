import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:index/models/movie.dart' as model;
import 'package:index/models/person.dart' as model;
import 'package:index/models/search_results.dart' as model;
import 'package:index/models/stream.dart';
import 'package:index/screens/person_media.dart';
import 'package:index/screens/player.dart';
import 'package:index/utils/api_keys.dart';
import 'package:index/utils/db_names.dart';
import 'package:index/utils/enums.dart';
import 'package:index/utils/extractor.dart';
import 'package:index/utils/spinner.dart';
import 'package:index/utils/urls.dart';
import 'package:index/screens/view_all.dart';
import 'package:swipeable_page_route/swipeable_page_route.dart';
import 'package:url_launcher/url_launcher.dart';

//ignore: must_be_immutable
class Movie extends StatefulWidget {
  model.Movie movie;

  Movie(this.movie);

  @override
  _MovieState createState() => _MovieState();
}

class _MovieState extends State<Movie> {
  model.Movie? _movie;
  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isFavorite = false;
  List<int> _favoriteMovies = [];
  model.SearchResults _recommendationsResults = model.SearchResults(page: 0, totalPages: 0, totalResults: 0);
  model.SearchResults _similarResults = model.SearchResults(page: 0, totalPages: 0, totalResults: 0);
  PagingController _recommendationsPagingController = PagingController(firstPageKey: 0);
  PagingController _similarPagingController = PagingController(firstPageKey: 0);
  late Spinner _spinner;
  bool _isLoading = true;
  bool _isConnectedToInternet = true;
  late StreamSubscription _connectionSubscription;

  navigate({required Widget destination, bool replace = false}) async {
    SwipeablePageRoute pageTransition = SwipeablePageRoute(
      canOnlySwipeFromEdge: true,
      builder: (BuildContext context) => destination,
    );

    if (replace) {
      await Navigator.pushReplacement(
        context,
        pageTransition,
      );
    } else {
      await Navigator.push(
        context,
        pageTransition,
      ).then((parameters) async {
        await Future.delayed(Duration(seconds: 1));
        if (parameters != null) {
          if (parameters['error'] != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Playback error. Try again',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                backgroundColor: Theme.of(context).cardColor,
              ),
            );
          } else if (parameters['progress'] != null) {
            refresh(watchedProgress: parameters['progress']);
          }
        }
      });
    }
  }

  getMovieDetails() async {
    _spinner.show();
    await Future.wait([
      isFavorite(),
      isRecentlyWatched(),
      getTrailerUrl(),
      getDuration(),
      getCast(),
    ]);

    _recommendationsPagingController.addPageRequestListener((pageKey) async {
      await getRecommendations(pageKey);
    });
    _similarPagingController.addPageRequestListener((pageKey) async {
      await getSimilar(pageKey);
    });

    _spinner.dismiss();
    setState(() => _isLoading = false);
  }

  Future<void> isFavorite() async {
    final user = _firestore.collection(DB.favorites).doc(_auth.currentUser!.uid);
    await user.get().then((DocumentSnapshot doc) {
      Map<dynamic, dynamic> data = (doc.data() ?? {}) as Map<dynamic, dynamic>;
      List<int> favoriteMovies = ((data['movies'] ?? []) as List<dynamic>).cast<int>();

      if (favoriteMovies.isNotEmpty) {
        setState(() {
          _isFavorite = favoriteMovies.contains(_movie!.id);
          _favoriteMovies = favoriteMovies;
        });
      }
    }, onError: (e) {
      print("Error getting favorites: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to get favorites',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          backgroundColor: Theme.of(context).cardColor,
        ),
      );
    });
  }

  addToFavorites() async {
    List<int> favoriteMovies = _favoriteMovies;
    favoriteMovies.add(_movie!.id);

    final user = _firestore.collection(DB.favorites).doc(_auth.currentUser!.uid);
    await user.set({
      'movies': favoriteMovies,
    }, SetOptions(merge: true));

    setState(() {
      _favoriteMovies = favoriteMovies;
      _isFavorite = true;
    });
  }

  removeFromFavorites() async {
    List<int> favoriteMovies = _favoriteMovies;
    favoriteMovies.remove(_movie!.id);

    final user = _firestore.collection(DB.favorites).doc(_auth.currentUser!.uid);
    await user.set({
      'movies': favoriteMovies,
    }, SetOptions(merge: true));

    setState(() {
      _favoriteMovies = favoriteMovies;
      _isFavorite = false;
    });
  }

  Future<void> isRecentlyWatched() async {
    final user = _firestore.collection(DB.recentlyWatched).doc(_auth.currentUser!.uid);
    await user.get().then((DocumentSnapshot doc) {
      Map<dynamic, dynamic> data = (doc.data() ?? {}) as Map<dynamic, dynamic>;
      Map<String, Map<String, dynamic>> recentlyWatched = ((data['movies'] ?? {}) as Map<dynamic, dynamic>).map<String, Map<String, dynamic>>((key, value) {
        return MapEntry(key, Map<String, dynamic>.from(value));
      });

      if (recentlyWatched.isNotEmpty) {
        bool isRecentlyWatched = recentlyWatched.keys.contains('${_movie!.id}');
        setState(() => _movie!.isRecentlyWatched = isRecentlyWatched);

        if (isRecentlyWatched) {
          int watchedProgress = recentlyWatched['${_movie!.id}']?['progress'] ?? 0;
          setState(() => _movie!.watchedProgress = watchedProgress);
        }
      }
    }, onError: (e) {
      print("Error getting recently watched: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to get recently watched',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          backgroundColor: Theme.of(context).cardColor,
        ),
      );
    });
  }

  Future<void> getTrailerUrl() async {
    String youtubeId = '';

    Map<String, String> headers = {
      HttpHeaders.authorizationHeader: 'Bearer ${APIKeys.tmdbAccessTokenAuth}',
    };

    Uri uri = Uri.parse(Urls.getMovieVideosUrl(_movie!.id));

    Response request = await http.get(
      uri,
      headers: headers,
    );

    String response = request.body;
    if (!kReleaseMode) print(response);

    if (response.isNotEmpty) {
      List videos = json.decode(response)['results'] as List;
      List youtubeVideos = videos.where((video) {
        return video['site'] == 'YouTube' && video['type'] == 'Trailer' && video['official'] == true;
      }).toList();
      youtubeVideos.sort((a, b) => b['size'].compareTo(a['size']));
      youtubeId = youtubeVideos[0]['key'] ?? '';
    } else {
      print('Failed to get trailer youtube url');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to get trailer',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          backgroundColor: Theme.of(context).cardColor,
        ),
      );
    }

    String youtubeUrl = 'https://www.youtube.com/watch?v=$youtubeId';
    setState(() => _movie!.trailerUrl = youtubeUrl);
  }

  Future<void> getDuration() async {
    Map<String, String> headers = {
      HttpHeaders.authorizationHeader: 'Bearer ${APIKeys.tmdbAccessTokenAuth}',
    };

    Uri uri = Uri.parse(Urls.getMovieDetails(_movie!.id));

    Response request = await http.get(
      uri,
      headers: headers,
    );

    String response = request.body;
    if (!kReleaseMode) print(response);

    if (response.isNotEmpty) {
      Map<String, dynamic> details = json.decode(response) as Map<String, dynamic>;
      int duration = details['runtime'];
      setState(() => _movie!.duration = duration);
    } else {
      print('Failed to get movie duration');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to get duration',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          backgroundColor: Theme.of(context).cardColor,
        ),
      );
    }
  }

  getStream() async {
    Extractor extractor = Extractor(movie: _movie);
    MediaStream? stream = await extractor.getStream();
    return stream;
  }

  getSubtitles() async {
    List<File> srtFiles = [];

    try {
      Map<String, dynamic> parameters = {
        'api_key': APIKeys.subdl,
        'tmdb_id': '${_movie!.id}',
        'languages': 'EN',
        'subs_per_page': '5',
      };

      Uri uri = Uri.parse(Urls.subtitles).replace(
        queryParameters: parameters,
      );
      final response = await http.get(uri);

      if (!kReleaseMode) print(response.body);

      if (response.statusCode == 200) {
        final subtitlesData = jsonDecode(response.body);

        List subtitles = subtitlesData['subtitles'];

        Directory directory = await getTemporaryDirectory();
        String destinationDirectory = directory.path;

        for (var subtitle in subtitles) {
          String zipUrl = subtitle['url'];
          String fullZipUrl = Urls.subdlDownloadBase + '$zipUrl';

          final zipResponse = await http.get(Uri.parse(fullZipUrl));

          if (zipResponse.statusCode == 200) {
            final bytes = zipResponse.bodyBytes;
            final archive = ZipDecoder().decodeBytes(bytes);

            for (final file in archive) {
              if (file.isFile) {
                String fileName = file.name;
                String extension = path.extension(fileName);

                if (extension == '.srt') {
                  final data = file.content as List<int>;

                  File srtFile = File('$destinationDirectory/$fileName');
                  await srtFile.writeAsBytes(data);

                  srtFiles.add(srtFile);
                }
              }
            }
          } else {
            print('Failed to download subtitle ZIP: ${zipResponse.statusCode}');
          }
        }
      } else {
        print('Failed to fetch subtitles from API: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e');
    }

    return srtFiles;
  }

  Future<void> getCast() async {
    Map<String, String> headers = {
      HttpHeaders.authorizationHeader: 'Bearer ${APIKeys.tmdbAccessTokenAuth}',
    };

    Uri uri = Uri.parse(Urls.getMovieCast(_movie!.id));

    Response request = await http.get(
      uri,
      headers: headers,
    );

    String response = request.body;
    if (!kReleaseMode) print(response);

    if (response.isNotEmpty) {
      List data = json.decode(response)['cast'] as List;
      List<model.Person> allCast = data.map((json) => model.Person.fromJson(json)).toList();
      List<model.Person> cast = allCast.where((model.Person person) => person.department == 'Acting').toList();

      setState(() => _movie!.cast = cast);
    } else {
      print('Failed to get movie cast');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to get cast',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          backgroundColor: Theme.of(context).cardColor,
        ),
      );
    }
  }

  getRecommendations(int pageKey) async {
    Map<String, dynamic> parameters = {
      'page': '${_recommendationsResults.page + 1}',
    };
    Map<String, String> headers = {
      HttpHeaders.authorizationHeader: 'Bearer ${APIKeys.tmdbAccessTokenAuth}',
    };

    Uri uri = Uri.parse(Urls.getMovieRecommendations(_movie!.id)).replace(queryParameters: parameters);
    Response request = await http.get(
      uri,
      headers: headers,
    );

    String response = request.body;
    if (!kReleaseMode) print(response);

    if (response.isNotEmpty) {
      model.SearchResults searchResults = model.SearchResults.fromJson(
        PageType.movies,
        json.decode(response),
      );

      bool isLastPage = pageKey == searchResults.totalResults;

      if (isLastPage) {
        _recommendationsPagingController.appendLastPage(searchResults.movies!);
      } else {
        int nextPageKey = pageKey + searchResults.movies!.length;
        _recommendationsPagingController.appendPage(searchResults.movies!, nextPageKey);
      }

      setState(() => _recommendationsResults = searchResults);
    } else {
      print('Failed to get movie recommendations');
      _recommendationsPagingController.error = 'error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to get recommendations',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          backgroundColor: Theme.of(context).cardColor,
        ),
      );
    }
  }

  getSimilar(int pageKey) async {
    Map<String, dynamic> parameters = {
      'page': '${_similarResults.page + 1}',
    };
    Map<String, String> headers = {
      HttpHeaders.authorizationHeader: 'Bearer ${APIKeys.tmdbAccessTokenAuth}',
    };

    Uri uri = Uri.parse(Urls.getMovieSimilar(_movie!.id)).replace(queryParameters: parameters);
    Response request = await http.get(
      uri,
      headers: headers,
    );

    String response = request.body;
    if (!kReleaseMode) print(response);

    if (response.isNotEmpty) {
      model.SearchResults searchResults = model.SearchResults.fromJson(
        PageType.movies,
        json.decode(response),
      );

      bool isLastPage = pageKey == searchResults.totalResults;

      if (isLastPage) {
        _similarPagingController.appendLastPage(searchResults.movies!);
      } else {
        int nextPageKey = pageKey + searchResults.movies!.length;
        _similarPagingController.appendPage(searchResults.movies!, nextPageKey);
      }

      setState(() => _similarResults = searchResults);
    } else {
      print('Failed to get similar movies');
      _similarPagingController.error = 'error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to get similar',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          backgroundColor: Theme.of(context).cardColor,
        ),
      );
    }
  }

  refresh({required int watchedProgress}) async {
    setState(() {
      _movie!.isRecentlyWatched = true;
      _movie!.watchedProgress = watchedProgress;
    });
  }

  initConnectivity() async {
    bool isConnectedToInternet = await InternetConnection().hasInternetAccess;
    setState(() => _isConnectedToInternet = isConnectedToInternet);

    _connectionSubscription = InternetConnection().onStatusChange.listen((InternetStatus status) {
      switch (status) {
        case InternetStatus.connected:
          if (mounted) setState(() => _isConnectedToInternet = true);
          break;
        case InternetStatus.disconnected:
          if (mounted) setState(() => _isConnectedToInternet = false);
          break;
      }
    });
  }

  @override
  void initState() {
    _movie = widget.movie;
    super.initState();

    initConnectivity();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _spinner = Spinner(context);
      await FirebaseAnalytics.instance.logScreenView(
        screenName: 'Movie - ${_movie!.title}',
      );
      await getMovieDetails();
    });
  }

  @override
  void dispose() {
    _connectionSubscription.cancel();
    super.dispose();
  }

  Widget TrailerPoster() {
    return CachedNetworkImage(
      imageUrl: Urls.getBestImageUrl(context) + _movie!.backdropPath,
      placeholder: (context, url) {
        return Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.width * 0.4,
          child: Align(
            alignment: Alignment.center,
            child: CircularProgressIndicator(),
          ),
        );
      },
      imageBuilder: (context, image) {
        return Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.25,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: image,
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            color: Theme.of(context).primaryColor.withOpacity(0.5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: IconButton(
                    icon: Icon(Icons.play_arrow),
                    color: Colors.white,
                    onPressed: () async {
                      await launchUrl(
                        Uri.parse(_movie!.trailerUrl!),
                        mode: LaunchMode.externalNonBrowserApplication,
                      );
                    },
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(top: 10),
                  child: Text(
                    'Play trailer',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      errorWidget: (context, url, error) => Icon(Icons.error),
    );
  }

  Widget Title() {
    return Container(
      width: double.infinity,
      child: Text(
        _movie!.title,
        style: Theme.of(context).textTheme.titleMedium,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget ReleaseYearAndRuntime() {
    String releaseYear = _movie!.releaseDate.split('-')[0];
    String runtime = formatDuration(Duration(minutes: _movie!.duration!));
    return Container(
      width: double.infinity,
      child: Text(
        '$releaseYear \u2981 $runtime',
        style: Theme.of(context).textTheme.displayMedium!.copyWith(color: Colors.white54),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget WatchedProgress() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        child: LinearProgressIndicator(
          value: _movie!.watchedProgress! / (_movie!.duration! * 60),
          valueColor: AlwaysStoppedAnimation(Theme.of(context).primaryColor),
          backgroundColor: Theme.of(context).primaryColor.withOpacity(.2),
        ),
      ),
    );
  }

  Widget Play() {
    return Container(
      width: double.infinity,
      height: 50,
      margin: EdgeInsets.only(top: 20),
      child: ElevatedButton(
        child: Container(
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                margin: EdgeInsets.only(right: 5),
                child: Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              Text(
                'Play',
                style: Theme.of(context).textTheme.titleSmall!.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () async {
          _spinner.show();
          MediaStream stream = await getStream();
          List<File>? subtitles = await getSubtitles();
          _spinner.dismiss();

          if (stream.url != null) {
            navigate(
              destination: Player(
                id: _movie!.id,
                title: _movie!.title,
                stream: stream,
                subtitles: subtitles,
                pageType: PageType.movies,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'No stream link found',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                backgroundColor: Theme.of(context).cardColor,
              ),
            );
          }
        },
      ),
    );
  }

  Widget Overview() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 20),
      child: Text(
        _movie!.overview,
        style: Theme.of(context).textTheme.displaySmall!.copyWith(color: Colors.white54),
        textAlign: TextAlign.justify,
      ),
    );
  }

  Widget Cast() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 30),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            child: Text(
              'Cast',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Container(
            height: MediaQuery.of(context).size.height * 0.25,
            margin: EdgeInsets.only(top: 10),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _movie!.cast!.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: EdgeInsets.only(right: (index + 1) != _movie!.cast!.length ? 18 : 0),
                  child: PersonCard(_movie!.cast![index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget PersonCard(model.Person person) {
    return Column(
      children: [
        Expanded(
          child: CachedNetworkImage(
            imageUrl: '${Urls.imageBase_w300}${person.profilePath}',
            placeholder: (context, url) {
              return Container(
                width: MediaQuery.of(context).size.width * 0.4,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Align(
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(),
                ),
              );
            },
            imageBuilder: (context, image) {
              return InkWell(
                customBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () => navigate(destination: PersonMedia(person)),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.4,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: image,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
            errorWidget: (context, url, error) {
              return Container(
                width: MediaQuery.of(context).size.width * 0.4,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Align(
                  alignment: Alignment.center,
                  child: Icon(Icons.error, color: Colors.white54),
                ),
              );
            },
          ),
        ),
        Container(
          width: MediaQuery.of(context).size.width * 0.4,
          margin: EdgeInsets.only(top: 10),
          child: Text(
            person.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.displayMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget Category(String title, {required String source, required PagingController pagingController}) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 30),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Spacer(),
              GestureDetector(
                onTap: () {
                  navigate(
                    destination: ViewAll(
                      title: title,
                      source: source,
                      pageType: PageType.movies,
                    ),
                  );
                },
                child: Text(
                  'View all',
                  style: Theme.of(context).textTheme.displaySmall!.copyWith(color: Colors.white54),
                ),
              ),
            ],
          ),
          Container(
            height: MediaQuery.of(context).size.height * 0.25,
            margin: EdgeInsets.only(top: 10),
            child: PagedListView(
              pagingController: pagingController,
              scrollDirection: Axis.horizontal,
              builderDelegate: PagedChildBuilderDelegate(
                itemBuilder: (context, movie, index) {
                  return Container(
                    margin: EdgeInsets.only(right: (index + 1) != pagingController.nextPageKey ? 18 : 0),
                    child: MovieCard(movie as model.Movie),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget MovieCard(model.Movie movie) {
    List<String> releaseDateContent = movie.releaseDate.split('-');
    String releaseYear = releaseDateContent[0];

    return Column(
      children: [
        Expanded(
          child: CachedNetworkImage(
            imageUrl: '${Urls.imageBase_w185}${movie.posterPath}',
            placeholder: (context, url) {
              return Container(
                width: MediaQuery.of(context).size.width * 0.3,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Align(
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(),
                ),
              );
            },
            imageBuilder: (context, image) {
              return Container(
                width: MediaQuery.of(context).size.width * 0.3,
                height: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: image,
                    fit: BoxFit.cover,
                  ),
                ),
                child: InkWell(
                  customBorder: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(
                              vertical: 5,
                              horizontal: 8,
                            ),
                            margin: EdgeInsets.only(
                              top: 5,
                              right: 5,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              color: Theme.of(context).primaryColor,
                            ),
                            child: Text(
                              '${movie.voteAverage}',
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                          ),
                        ],
                      ),
                      Spacer(),
                    ],
                  ),
                  onTap: () => navigate(destination: Movie(movie)),
                ),
              );
            },
            errorWidget: (context, url, error) {
              return Container(
                width: MediaQuery.of(context).size.width * 0.3,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Align(
                  alignment: Alignment.center,
                  child: Icon(Icons.error, color: Colors.white54),
                ),
              );
            },
          ),
        ),
        Container(
          width: MediaQuery.of(context).size.width * 0.3,
          margin: EdgeInsets.only(top: 10),
          child: Text(
            movie.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.displayMedium,
            textAlign: TextAlign.left,
          ),
        ),
        Container(
          width: MediaQuery.of(context).size.width * 0.3,
          margin: EdgeInsets.only(top: 10),
          child: Text(
            releaseYear,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.displaySmall!.copyWith(color: Colors.white54),
            textAlign: TextAlign.left,
          ),
        ),
      ],
    );
  }

  Widget NoInternet() {
    return Container(
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_sharp,
            color: Colors.white54,
            size: 80,
          ),
          Container(
            margin: EdgeInsets.only(top: 10),
            child: Text(
              'You have lost internet connection',
              style: Theme.of(context).textTheme.displayMedium!.copyWith(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  String formatDuration(Duration duration) {
    int hours = duration.inHours;
    int minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours} ${hours == 1 ? 'hr' : 'hrs'}${minutes > 0 ? ' ${minutes} ${minutes == 1 ? 'min' : 'mins'}' : ''}';
    } else {
      return '$minutes ${minutes == 1 ? 'min' : 'mins'}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => Navigator.pop(context, 'refresh'),
        ),
        actions: [
          if (_isConnectedToInternet) IconButton(
            icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
            color: _isFavorite ? Colors.red : Colors.white,
            onPressed: () async {
              if (_isFavorite) {
                await removeFromFavorites();
              } else {
                await addToFavorites();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isConnectedToInternet ? RefreshIndicator(
          color: Theme.of(context).primaryColor,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          onRefresh: () async {
            _recommendationsPagingController.dispose();
            _similarPagingController.dispose();

            setState(() {
              _isLoading = true;
              _isFavorite = false;
              _movie!.trailerUrl = null;
              _movie!.cast = null;
              _recommendationsResults = model.SearchResults(page: 0, totalPages: 0, totalResults: 0);
              _similarResults = model.SearchResults(page: 0, totalPages: 0, totalResults: 0);
              _recommendationsPagingController = PagingController(firstPageKey: 0);
              _similarPagingController = PagingController(firstPageKey: 0);
            });
            getMovieDetails();
          },
          child: !_isLoading ? SingleChildScrollView(
            child: Column(
              children: [
                TrailerPoster(),
                Container(
                  margin: EdgeInsets.all(18),
                  child: Column(
                    children: [
                      Title(),
                      ReleaseYearAndRuntime(),
                      if (_movie!.isRecentlyWatched != null && _movie!.isRecentlyWatched!) WatchedProgress(),
                      Play(),
                      Overview(),
                      if (_movie!.cast != null && _movie!.cast!.isNotEmpty) Cast(),
                      Category('Recommendations', source: Urls.getMovieRecommendations(_movie!.id), pagingController: _recommendationsPagingController),
                      Category('Similar', source: Urls.getMovieSimilar(_movie!.id), pagingController: _similarPagingController),
                    ],
                  ),
                ),
              ],
            ),
          ) : Container(),
        ) : NoInternet(),
      ),
    );
  }
}