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
import 'package:index/models/person.dart' as model;
import 'package:index/models/search_results.dart' as model;
import 'package:index/models/stream.dart';
import 'package:index/models/tv_show.dart' as model;
import 'package:index/screens/person_media.dart';
import 'package:index/screens/player.dart';
import 'package:index/utils/api_keys.dart';
import 'package:index/utils/db_names.dart';
import 'package:index/utils/enums.dart';
import 'package:index/utils/extractor.dart';
import 'package:index/utils/pop_up_menu.dart';
import 'package:index/utils/spinner.dart';
import 'package:index/utils/urls.dart';
import 'package:index/screens/view_all.dart';
import 'package:swipeable_page_route/swipeable_page_route.dart';
import 'package:url_launcher/url_launcher.dart';

//ignore: must_be_immutable
class TvShow extends StatefulWidget {
  model.TvShow tvShow;

  TvShow(this.tvShow);

  @override
  _TvShowState createState() => _TvShowState();
}

class _TvShowState extends State<TvShow> {
  model.TvShow? _tvShow;
  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isFavorite = false;
  List<int> _favoriteTvShows = [];
  Map<String, Map<String, dynamic>> _rawRecentlyWatched = {};
  model.SearchResults _recommendationsResults = model.SearchResults(page: 0, totalPages: 0, totalResults: 0);
  model.SearchResults _similarResults = model.SearchResults(page: 0, totalPages: 0, totalResults: 0);
  PagingController _recommendationsPagingController = PagingController(firstPageKey: 0);
  PagingController _similarPagingController = PagingController(firstPageKey: 0);
  late Spinner _spinner;
  bool _isLoading = true;
  int _currentSeason = 0;
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
        } else if (parameters['episodeId'] != null && parameters['progress'] != null) {
          refresh(
            episodeId: parameters['episodeId'],
            watchedProgress: parameters['progress'],
          );
        }
      });
    }
  }

  getTvShowDetails() async {
    _spinner.show();
    await Future.wait([
      isFavorite(),
      getSeasons(),
      getTrailerUrl(),
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
      List<int> favoriteTvShows = ((data['tv_shows'] ?? []) as List<dynamic>).cast<int>();

      if (favoriteTvShows.isNotEmpty) {
        setState(() {
          _isFavorite = favoriteTvShows.contains(_tvShow!.id);
          _favoriteTvShows = favoriteTvShows;
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
    List<int> favoriteTvShows = _favoriteTvShows;
    favoriteTvShows.add(_tvShow!.id);

    final user = _firestore.collection(DB.favorites).doc(_auth.currentUser!.uid);
    await user.set({
      'tv_shows': favoriteTvShows,
    }, SetOptions(merge: true));

    setState(() {
      _favoriteTvShows = favoriteTvShows;
      _isFavorite = true;
    });
  }

  removeFromFavorites() async {
    List<int> favoriteTvShows = _favoriteTvShows;
    favoriteTvShows.remove(_tvShow!.id);

    final user = _firestore.collection(DB.favorites).doc(_auth.currentUser!.uid);
    await user.set({
      'tv_shows': favoriteTvShows,
    }, SetOptions(merge: true));

    setState(() {
      _favoriteTvShows = favoriteTvShows;
      _isFavorite = false;
    });
  }

  Future<void> getSeasons() async {
    Map<String, String> headers = {
      HttpHeaders.authorizationHeader: 'Bearer ${APIKeys.tmdbAccessTokenAuth}',
    };

    Uri uri = Uri.parse(Urls.getTvShowDetails(_tvShow!.id));
    Response request = await http.get(
      uri,
      headers: headers,
    );

    String response = request.body;
    if (!kReleaseMode) print(response);

    if (response.isNotEmpty) {
      List<Map<String, dynamic>> seasonsData = (json.decode(response)['seasons'] as List<dynamic>).cast<Map<String, dynamic>>();

      List<model.Season> seasons = [];

      for (Map<String, dynamic> seasonData in seasonsData) {
        model.Season season = model.Season.fromJson(seasonData);

        if (season.number > 0) {
          if (season.airDate != null) {
            if (season.number == (_currentSeason + 1)) {
              List<model.Episode> episodes = await getEpisodes(season);
              season.episodes = episodes;
            }

            seasons.add(season);
          }

          setState(() => _tvShow!.seasons = seasons);
        }
      }
    } else {
      print('Failed to get tv show seasons');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to get seasons',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          backgroundColor: Theme.of(context).cardColor,
        ),
      );
    }
  }

  Future<List<model.Episode>> getEpisodes(model.Season season) async {
    Map<String, String> headers = {
      HttpHeaders.authorizationHeader: 'Bearer ${APIKeys.tmdbAccessTokenAuth}',
    };

    Uri uri = Uri.parse(Urls.getEpisodes(_tvShow!.id, season.number));

    Response request = await http.get(
      uri,
      headers: headers,
    );

    String response = request.body;
    if (!kReleaseMode) print(response);

    if (response.isNotEmpty) {
      List episodesData = json.decode(response)['episodes'] as List;
      List<model.Episode> episodes = [];

      for (var episodeData in episodesData) {
        episodeData['show_name'] = _tvShow!.name;
        model.Episode episode = model.Episode.fromJson(episodeData);
        if (episode.airDate != null) episodes.add(episode);
      }

      Map<String, Map<String, dynamic>>? recentlyWatched = await getRecentlyWatched(season.id);

      if (recentlyWatched != null) {
        for (model.Episode episode in episodes) {
          if (recentlyWatched.keys.contains('${episode.id}')) {
            Map<String, dynamic> episodeDetails = recentlyWatched['${episode.id}'] as Map<String, dynamic>;
            episode.isRecentlyWatched = true;
            episode.watchedProgress = episodeDetails['progress'] ?? 0;
          }
        }
      }

      return episodes;
    } else {
      print('Failed to get tv show episodes');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to get episodes',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          backgroundColor: Theme.of(context).cardColor,
        ),
      );
    }

    return [];
  }

  Future<Map<String, Map<String, dynamic>>?> getRecentlyWatched(int seasonId) async {
    Map<String, Map<String, dynamic>>? results;

    final user = _firestore.collection(DB.recentlyWatched).doc(_auth.currentUser!.uid);
    await user.get().then((DocumentSnapshot doc) {
      Map<dynamic, dynamic> data = (doc.data() ?? {}) as Map<dynamic, dynamic>;
      Map<String, Map<String, dynamic>> recentlyWatched = ((data['tv_shows'] ?? {}) as Map<dynamic, dynamic>).map<String, Map<String, dynamic>>((key, value) {
        return MapEntry(key, Map<String, dynamic>.from(value));
      });

      setState(() => _rawRecentlyWatched = recentlyWatched);

      if (recentlyWatched.keys.contains('${_tvShow!.id}')) {
        recentlyWatched['${_tvShow!.id}']!.remove('visibleInMenu');

        Map<String, Map<String, dynamic>> seasons = ((recentlyWatched['${_tvShow!.id}'] ?? {}) as Map<dynamic, dynamic>).map<String, Map<String, dynamic>>((key, value) {
          return MapEntry(key, Map<String, dynamic>.from(value));
        });

        if (seasons.keys.contains('$seasonId')) {
          Map<String, Map<String, dynamic>> episodes = ((seasons['$seasonId'] ?? {}) as Map<dynamic, dynamic>).map<String, Map<String, dynamic>>((key, value) {
            return MapEntry(key, Map<String, dynamic>.from(value));
          });

          results = episodes;
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

    return results;
  }

  Future<void> getTrailerUrl() async {
    String youtubeId = '';

    Map<String, String> headers = {
      HttpHeaders.authorizationHeader: 'Bearer ${APIKeys.tmdbAccessTokenAuth}',
    };

    Uri uri = Uri.parse(Urls.getTvShowVideosUrl(_tvShow!.id));

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
      if (youtubeVideos.isNotEmpty) {
        youtubeVideos.sort((a, b) => b['size'].compareTo(a['size']));
        youtubeId = youtubeVideos[0]['key'] ?? '';
      }
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
    setState(() => _tvShow!.trailerUrl = youtubeUrl);
  }

  Future<void> getCast() async {
    Map<String, String> headers = {
      HttpHeaders.authorizationHeader: 'Bearer ${APIKeys.tmdbAccessTokenAuth}',
    };

    Uri uri = Uri.parse(Urls.getTvShowCast(_tvShow!.id));

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

      setState(() => _tvShow!.cast = cast);
    } else {
      print('Failed to get tv show cast');
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

    Uri uri = Uri.parse(Urls.getTvShowRecommendations(_tvShow!.id)).replace(queryParameters: parameters);
    Response request = await http.get(
      uri,
      headers: headers,
    );

    String response = request.body;
    if (!kReleaseMode) print(response);

    if (response.isNotEmpty) {
      model.SearchResults searchResults = model.SearchResults.fromJson(
        PageType.tv_shows,
        json.decode(response),
      );

      bool isLastPage = pageKey == searchResults.totalResults;

      if (isLastPage) {
        _recommendationsPagingController.appendLastPage(searchResults.tvShows!);
      } else {
        int nextPageKey = pageKey + searchResults.tvShows!.length;
        _recommendationsPagingController.appendPage(searchResults.tvShows!, nextPageKey);
      }

      setState(() => _recommendationsResults = searchResults);
    } else {
      print('Failed to get tv show recommendations');
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

    Uri uri = Uri.parse(Urls.getTvShowSimilar(_tvShow!.id)).replace(queryParameters: parameters);
    Response request = await http.get(
      uri,
      headers: headers,
    );

    String response = request.body;
    if (!kReleaseMode) print(response);

    if (response.isNotEmpty) {
      model.SearchResults searchResults = model.SearchResults.fromJson(
        PageType.tv_shows,
        json.decode(response),
      );

      bool isLastPage = pageKey == searchResults.totalResults;

      if (isLastPage) {
        _similarPagingController.appendLastPage(searchResults.tvShows!);
      } else {
        int nextPageKey = pageKey + searchResults.tvShows!.length;
        _similarPagingController.appendPage(searchResults.tvShows!, nextPageKey);
      }

      setState(() => _similarResults = searchResults);
    } else {
      print('Failed to get similar tv shows');
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

  getStream(model.Episode episode) async {
    Extractor extractor = Extractor(episode: episode);
    MediaStream stream = await extractor.getStream();
    return stream;
  }

  getSubtitles(model.Episode episode) async {
    List<File> srtFiles = [];

    try {
      Map<String, dynamic> parameters = {
        'api_key': APIKeys.subdl,
        'tmdb_id': '${_tvShow!.id}',
        'season_number': '${episode.season}',
        'episode_number': '${episode.number}',
        'languages': 'EN',
        'subs_per_page': '5'
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

  addToRecentlyWatched(model.Season season, model.Episode episode) async {
    Map<String, dynamic> episodeData = {
      'progress': episode.duration * 60,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    Map<String, Map<String, dynamic>> recentlyWatched = _rawRecentlyWatched;

    if (recentlyWatched.isNotEmpty) {
      Map<String, dynamic> seasons = recentlyWatched['${_tvShow!.id}']!;
      recentlyWatched['${_tvShow!.id}']!.remove('visibleInMenu');

      seasons = seasons.map<String, Map<String, dynamic>>((key, value) {
        return MapEntry(key, Map<String, dynamic>.from(value));
      });

      if (seasons.containsKey('${season.id}')) {
        Map<String, Map<String, dynamic>> episodes = ((seasons['${season.id}'] ?? {}) as Map<dynamic, dynamic>).map<String, Map<String, dynamic>>((key, value) {
          return MapEntry(key, Map<String, dynamic>.from(value));
        });

        episodes['${episode.id}'] = episodeData;
        seasons['${season.id}'] = episodes;
      } else {
        seasons['${season.id}'] = {
          '${episode.id}': episodeData,
        };
      }

      recentlyWatched['${_tvShow!.id}'] = {};
      recentlyWatched['${_tvShow!.id}']!['visibleInMenu'] = true;
      recentlyWatched['${_tvShow!.id}']!.addAll(seasons);
    } else {
      recentlyWatched['${_tvShow!.id}'] = {
        'visibleInMenu': true,
        '${season.id}': {
          '${episode.id}': episodeData,
        },
      };
    }

    final user = _firestore.collection(DB.recentlyWatched).doc(_auth.currentUser!.uid);
    await user.set({
      'tv_shows': recentlyWatched,
    }, SetOptions(mergeFields: ['tv_shows']));

    model.TvShow updatedTvShow = _tvShow!;
    updatedTvShow.seasons!.firstWhere((s) => s.id == season.id).episodes!.firstWhere((e) => e.id == episode.id)
      ..isRecentlyWatched = true
      ..watchedProgress = episode.duration * 60;

    setState(() {
      _tvShow = updatedTvShow;
      _rawRecentlyWatched = recentlyWatched;
    });
  }

  removeFromRecentlyWatched(model.Season season, model.Episode episode) async {
    Map<String, Map<String, dynamic>> recentlyWatched = _rawRecentlyWatched;

    Map<String, dynamic> seasons = recentlyWatched['${_tvShow!.id}']!;
    recentlyWatched['${_tvShow!.id}']!.remove('visibleInMenu');

    seasons = seasons.map<String, Map<String, dynamic>>((key, value) {
      return MapEntry(key, Map<String, dynamic>.from(value));
    });

    Map<String, Map<String, dynamic>> episodes = ((seasons['${season.id}'] ?? {}) as Map<dynamic, dynamic>).map<String, Map<String, dynamic>>((key, value) {
      return MapEntry(key, Map<String, dynamic>.from(value));
    });

    episodes.removeWhere((id, value) => id == '${episode.id}');

    seasons['${season.id}'] = episodes;
    recentlyWatched['${_tvShow!.id}'] = {};
    recentlyWatched['${_tvShow!.id}']!['visibleInMenu'] = true;
    recentlyWatched['${_tvShow!.id}']!.addAll(seasons);

    if (episodes.isEmpty) seasons.remove('${season.id}');
    if (seasons.isEmpty) recentlyWatched.remove('${_tvShow!.id}');

    final user = _firestore.collection(DB.recentlyWatched).doc(_auth.currentUser!.uid);
    await user.set({
      'tv_shows': recentlyWatched,
    }, SetOptions(mergeFields: ['tv_shows']));

    model.TvShow updatedTvShow = _tvShow!;
    updatedTvShow.seasons!.firstWhere((s) => s.id == season.id).episodes!.firstWhere((e) => e.id == episode.id)
        ..isRecentlyWatched = false
        ..watchedProgress = null;

    setState(() {
      _tvShow = updatedTvShow;
      _rawRecentlyWatched = recentlyWatched;
    });
  }

  refresh({required int episodeId, required int watchedProgress}) async {
    for(model.Episode episode in _tvShow!.seasons![_currentSeason].episodes!) {
      if (episode.id == episodeId) {
        setState(() {
          episode.isRecentlyWatched = true;
          episode.watchedProgress = watchedProgress;
        });
      }
    }
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
  void initState() {
    _tvShow = widget.tvShow;

    initConnectivity();

    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _spinner = Spinner(context);
      await FirebaseAnalytics.instance.logScreenView(
        screenName: 'TV Show - ${_tvShow!.name}',
      );
      await getTvShowDetails();
    });
  }

  @override
  void dispose() {
    _connectionSubscription.cancel();
    super.dispose();
  }

  Widget TrailerPoster() {
    return CachedNetworkImage(
      imageUrl: Urls.getBestImageUrl(context) + _tvShow!.backdropPath,
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
                        Uri.parse(_tvShow!.trailerUrl!),
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
        _tvShow!.name,
        style: Theme.of(context).textTheme.titleMedium,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget FirstAirYear() {
    String firstAirYear = _tvShow!.firstAirDate.split('-')[0];
    return Container(
      width: double.infinity,
      child: Text(
        firstAirYear,
        style: Theme.of(context).textTheme.displayMedium!.copyWith(color: Colors.white54),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget Overview() {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 20),
      child: Text(
        _tvShow!.overview,
        style: Theme.of(context).textTheme.displaySmall!.copyWith(color: Colors.white54),
        textAlign: TextAlign.justify,
      ),
    );
  }

  Widget Seasons() {
    model.Season season = _tvShow!.seasons![_currentSeason];
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 30),
      child: Column(
        children: [
          Row(
            children: [
              DropdownMenu<model.Season>(
                initialSelection: season,
                requestFocusOnTap: false,
                enableFilter: false,
                enableSearch: false,
                textStyle: Theme.of(context).textTheme.displayLarge,
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSelected: (model.Season? season) async {
                  if (season != null) {
                    if (season.episodes == null) {
                      _spinner.show();

                      List<model.Episode> episodes = await getEpisodes(season);
                      int seasonIndex = _tvShow!.seasons!.indexOf(season);

                      setState(() => _tvShow!.seasons![seasonIndex].episodes = episodes);

                      _spinner.dismiss();
                    }

                    setState(() => _currentSeason = _tvShow!.seasons!.indexOf(season));
                  }
                },
                dropdownMenuEntries: _tvShow!.seasons!.map<DropdownMenuEntry<model.Season>>((model.Season season) {
                  return DropdownMenuEntry<model.Season>(
                    value: season,
                    label: season.name,
                    style: MenuItemButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Theme.of(context).cardColor,
                    ),
                  );
                }).toList(),
              ),
              Spacer(),
            ],
          ),
          Container(
            margin: EdgeInsets.only(top: 10),
            child: ListView.builder(
              physics: NeverScrollableScrollPhysics(),
              scrollDirection: Axis.vertical,
              shrinkWrap: true,
              itemCount: season.episodes!.length,
              itemBuilder: (context, index) => Episode(season, season.episodes![index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget Episode(model.Season season, model.Episode episode) {
    return PopupMenuContainer<String>(
      items: [
        PopupMenuItem(
          value: 'already_watched',
          child: Text(
            'Already watched',
            style: Theme.of(context).textTheme.displaySmall,
          ),
        ),
        if (episode.isRecentlyWatched) PopupMenuItem(
          value: 'remove',
          child: Text(
            'Remove',
            style: Theme.of(context).textTheme.displaySmall,
          ),
        ),
      ],
      onItemSelected: (action) async {
        if (action != null) {
          if (action == 'already_watched') addToRecentlyWatched(season, episode);
          if (action == 'remove') removeFromRecentlyWatched(season, episode);
        }
      },
      child: InkWell(
        onTap: () async {
          _spinner.show();
          MediaStream stream = await getStream(episode);
          List<File>? subtitles = await getSubtitles(episode);
          _spinner.dismiss();

          if (stream.url != null) {
            navigate(
              destination: Player(
                id: _tvShow!.id,
                seasonId: season.id,
                episodeId: episode.id,
                title: episode.name,
                stream: stream,
                subtitles: subtitles,
                pageType: PageType.tv_shows,
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
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Row(
                children: [
                  CachedNetworkImage(
                    imageUrl: Urls.getBestImageUrl(context) + episode.stillPath,
                    placeholder: (context, url) {
                      return Container(
                        width: MediaQuery.of(context).size.width * .3,
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Align(
                              alignment: Alignment.center,
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        ),
                      );
                    },
                    imageBuilder: (context, image) {
                      return Container(
                        width: MediaQuery.of(context).size.width * .3,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: AspectRatio(
                            aspectRatio: 16 / 10,
                            child: Container(
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: image,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: episode.isRecentlyWatched ? Column(
                                children: [
                                  Spacer(),
                                  LinearProgressIndicator(
                                    value: episode.watchedProgress! / (episode.duration * 60),
                                    valueColor: AlwaysStoppedAnimation(Theme.of(context).primaryColor),
                                    backgroundColor: Colors.transparent,
                                  ),
                                ],
                              ) : Container(),
                            ),
                          ),
                        ),
                      );
                    },
                    errorWidget: (context, url, error) {
                      return Container(
                        width: MediaQuery.of(context).size.width * .3,
                        child: AspectRatio(
                          aspectRatio: 16 / 10,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Align(
                              alignment: Alignment.center,
                              child: Icon(Icons.error, color: Colors.white54),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(left: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            episode.name,
                            style: Theme.of(context).textTheme.displayMedium!.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 2,
                          ),
                          Padding(padding: EdgeInsets.only(top: 2)),
                          Text(
                            formatDuration(Duration(minutes: episode.duration)),
                            style: Theme.of(context).textTheme.displaySmall!.copyWith(color: Colors.white54),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(top: 18),
                child: Text(
                  episode.overview,
                  style: Theme.of(context).textTheme.displaySmall!.copyWith(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
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
              itemCount: _tvShow!.cast!.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: EdgeInsets.only(right: (index + 1) != _tvShow!.cast!.length ? 18 : 0),
                  child: PersonCard(_tvShow!.cast![index]),
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
                      pageType: PageType.tv_shows,
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
                itemBuilder: (context, tvShow, index) {
                  return Container(
                    margin: EdgeInsets.only(right: (index + 1) != pagingController.nextPageKey ? 18 : 0),
                    child: TvShowCard(tvShow as model.TvShow),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget TvShowCard(model.TvShow tvShow) {
    List<String> firstAirContent = tvShow.firstAirDate.split('-');
    String firstAirYear = firstAirContent[0];

    return Column(
      children: [
        Expanded(
          child: CachedNetworkImage(
            imageUrl: '${Urls.imageBase_w185}${tvShow.posterPath}',
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
                              '${tvShow.voteAverage}',
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                          ),
                        ],
                      ),
                      Spacer(),
                    ],
                  ),
                  onTap: () => navigate(destination: TvShow(tvShow)),
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
            tvShow.name,
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
            firstAirYear,
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
              _tvShow!.trailerUrl = null;
              _tvShow!.cast = null;
              _rawRecentlyWatched = {};
              _recommendationsResults = model.SearchResults(page: 0, totalPages: 0, totalResults: 0);
              _similarResults = model.SearchResults(page: 0, totalPages: 0, totalResults: 0);
              _recommendationsPagingController = PagingController(firstPageKey: 0);
              _similarPagingController = PagingController(firstPageKey: 0);
            });
            getTvShowDetails();
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
                      FirstAirYear(),
                      Overview(),
                      Seasons(),
                      if (_tvShow!.cast != null && _tvShow!.cast!.isNotEmpty) Cast(),
                      Category('Recommendations', source: Urls.getTvShowRecommendations(_tvShow!.id), pagingController: _recommendationsPagingController),
                      Category('Similar', source: Urls.getTvShowSimilar(_tvShow!.id), pagingController: _similarPagingController),
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