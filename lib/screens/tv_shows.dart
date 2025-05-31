import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:index/models/genre.dart' as model;
import 'package:index/models/search_results.dart' as model;
import 'package:index/models/streaming_platform.dart';
import 'package:index/models/tv_show.dart' as model;
import 'package:index/screens/tv_show.dart';
import 'package:index/utils/api_keys.dart';
import 'package:index/utils/db_names.dart';
import 'package:index/utils/enums.dart';
import 'package:index/utils/pop_up_menu.dart';
import 'package:index/utils/spinner.dart';
import 'package:index/utils/urls.dart';
import 'package:index/screens/view_all.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:swipeable_page_route/swipeable_page_route.dart';

class TvShows extends StatefulWidget {
  @override
  _TvShowsState createState() => _TvShowsState();
}

class _TvShowsState extends State<TvShows> {
  List<model.TvShow> _onTheAir = [], _recentlyWatched = [];
  Map<String, Map<String, dynamic>>? _rawRecentlyWatched;
  CarouselSliderController _onTheAirController = CarouselSliderController();
  int _currentOnTheAirIndex = 0;
  model.SearchResults _popularResults = model.SearchResults(page: 0, totalPages: 0, totalResults: 0);
  model.SearchResults _topRatedResults = model.SearchResults(page: 0, totalPages: 0, totalResults: 0);
  PagingController _popularPagingController = PagingController(firstPageKey: 0);
  PagingController _topRatedPagingController = PagingController(firstPageKey: 0);
  List<StreamingPlatform> _streamingPlatforms = [
    StreamingPlatform(id: 8, logoPath: '/netflix.png', name: 'Netflix'),
    StreamingPlatform(id: 9, logoPath: '/amazon_prime_video.png', name: 'Amazon Prime Video'),
    StreamingPlatform(id: 2, logoPath: '/apple_tv.png', name: 'Apple TV'),
    StreamingPlatform(id: 337, logoPath: '/disney_plus.png', name: 'Disney+'),
    StreamingPlatform(id: 15, logoPath: '/hulu.png', name: 'Hulu'),
  ];
  List<model.Genre> _genres = [];
  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  FirebaseAuth _auth = FirebaseAuth.instance;
  late Spinner _spinner;
  bool _isLoading = true;

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
      ).then((action) async {
        await Future.delayed(Duration(seconds: 1));
        if (action == 'refresh') {
          setState(() => _recentlyWatched.clear());
          getRecentlyWatched();
        }
      });
    }
  }

  getCategories() async {
    _spinner.show();
    _popularPagingController.addPageRequestListener((pageKey) async {
      model.SearchResults searchResults = await getTvShows(Urls.popularTvShows, pageKey: pageKey, resultsModel: _popularResults, pagingController: _popularPagingController);
      setState(() => _popularResults = searchResults);
    });
    _topRatedPagingController.addPageRequestListener((pageKey) async {
      model.SearchResults searchResults = await getTvShows(Urls.topRatedTvShows, pageKey: pageKey, resultsModel: _topRatedResults, pagingController: _topRatedPagingController);
      setState(() => _topRatedResults = searchResults);
    });
    await Future.wait([
      getOnTheAir(),
      getRecentlyWatched(),
      getGenres(),
    ]);
    setState(() => _isLoading = false);
    _spinner.dismiss();
  }

  Future<void> getOnTheAir() async {
    Map<String, String> headers = {
      HttpHeaders.authorizationHeader: 'Bearer ${APIKeys.tmdbAccessTokenAuth}',
    };

    Uri uri = Uri.parse(Urls.onTheAirTvShows);
    Response request = await http.get(
      uri,
      headers: headers,
    );

    String response = request.body;
    if (!kReleaseMode) print(response);

    if (response.isNotEmpty) {
      List data = json.decode(response)['results'] as List;
      List<model.TvShow> onTheAir = data.map((json) => model.TvShow.fromJson(json)).toList();

      setState(() => _onTheAir = onTheAir.length > 10 ? onTheAir.sublist(0, 10) : onTheAir);
    } else {
      print('Error getting on the air tv shows');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to get on the air',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          backgroundColor: Theme.of(context).cardColor,
        ),
      );
    }
  }

  Future<model.SearchResults> getTvShows(String url, {required int pageKey, required model.SearchResults resultsModel, required PagingController pagingController}) async {
    Map<String, dynamic> parameters = {
      'page': '${resultsModel.page + 1}',
    };
    Map<String, String> headers = {
      HttpHeaders.authorizationHeader: 'Bearer ${APIKeys.tmdbAccessTokenAuth}',
    };

    Uri uri = Uri.parse(url).replace(queryParameters: parameters);

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
        pagingController.appendLastPage(searchResults.tvShows!);
      } else {
        int nextPageKey = pageKey + searchResults.tvShows!.length;
        pagingController.appendPage(searchResults.tvShows!, nextPageKey);
      }

      return searchResults;
    } else {
      pagingController.error = 'error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to get TV shows',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          backgroundColor: Theme.of(context).cardColor,
        ),
      );
      return resultsModel;
    }
  }

  Future<void> getRecentlyWatched() async {
    final user = _firestore.collection(DB.recentlyWatched).doc(_auth.currentUser!.uid);
    await user.get().then((DocumentSnapshot doc) {
      Map<dynamic, dynamic> data = (doc.data() ?? {}) as Map<dynamic, dynamic>;
      Map<String, Map<String, dynamic>> rawRecentlyWatched = ((data['tv_shows'] ?? {}) as Map<dynamic, dynamic>).map<String, Map<String, dynamic>>((key, value) {
        return MapEntry(key, Map<String, dynamic>.from(value));
      });

      for (String id in rawRecentlyWatched.keys) {
        if (rawRecentlyWatched[id]!['visibleInMenu'] != false) getTvShowsDetails(int.parse(id));
      }

      setState(() => _rawRecentlyWatched = rawRecentlyWatched);
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

  Future<void> getTvShowsDetails(int id) async {
    Map<String, String> headers = {
      HttpHeaders.authorizationHeader: 'Bearer ${APIKeys.tmdbAccessTokenAuth}',
    };

    Uri uri = Uri.parse(Urls.getTvShowDetails(id)).replace();

    Response request = await http.get(
      uri,
      headers: headers,
    );

    String response = request.body;
    if (!kReleaseMode) print(response);

    if (response.isNotEmpty) {
      var data = json.decode(response);
      model.TvShow tvShow = model.TvShow.fromJson(data);
      setState(() {
        _recentlyWatched.add(tvShow);
      });
    } else {
      print('Failed to get tv show details: $id');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to get TV show details',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          backgroundColor: Theme.of(context).cardColor,
        ),
      );
    }
  }

  Future<void> getGenres() async {
    Map<String, String> headers = {
      HttpHeaders.authorizationHeader: 'Bearer ${APIKeys.tmdbAccessTokenAuth}',
    };

    Uri uri = Uri.parse(Urls.tvShowGenres).replace();

    Response request = await http.get(
      uri,
      headers: headers,
    );

    String response = request.body;
    if (!kReleaseMode) print(response);

    if (response.isNotEmpty) {
      List data = json.decode(response)['genres'] as List;
      List<model.Genre> genres = data.map((json) => model.Genre.fromJson(json)).toList();
      setState(() => _genres = genres);
    } else {
      print('Failed to get genres');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to get genres',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          backgroundColor: Theme.of(context).cardColor,
        ),
      );
    }
  }

  Future<String> getGenreBackdrop(model.Genre genre) async {
    String backdropPath = '';

    if (genre.backdropPath == null) {
      Map<String, dynamic> parameters = {
        'with_genres': '${genre.id}',
      };
      Map<String, String> headers = {
        HttpHeaders.authorizationHeader: 'Bearer ${APIKeys.tmdbAccessTokenAuth}',
      };

      Uri uri = Uri.parse(Urls.discoverTvShow).replace(queryParameters: parameters);
      Response request = await http.get(
        uri,
        headers: headers,
      );

      String response = request.body;
      if (!kReleaseMode) print(response);

      List tvShows = json.decode(response)['results'] as List;

      Random random = Random();
      int randomIndex = random.nextInt(tvShows.length);

      model.TvShow movie = model.TvShow.fromJson(tvShows[randomIndex]);

      for (model.Genre g in _genres) {
        if (g.id == genre.id && g.backdropPath == null) g.backdropPath = movie.backdropPath;
      }

      backdropPath = movie.backdropPath;
    } else {
      backdropPath = genre.backdropPath!;
    }

    return backdropPath;
  }

  removeFromRecentlyWatched(model.TvShow tvShow) async {
    Map<String, Map<String, dynamic>> rawRecentlyWatched = _rawRecentlyWatched!;
    rawRecentlyWatched['${tvShow.id}']!['visibleInMenu'] = false;

    final user = _firestore.collection(DB.recentlyWatched).doc(_auth.currentUser!.uid);
    await user.set({
      'tv_shows': rawRecentlyWatched,
    }, SetOptions(mergeFields: ['tv_shows']));

    setState(() {
      _recentlyWatched.remove(tvShow);
      _rawRecentlyWatched = rawRecentlyWatched;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _spinner = Spinner(context);
      await FirebaseAnalytics.instance.logScreenView(
        screenName: 'TV Shows',
      );
      getCategories();
    });
  }

  @override
  void dispose() {
    _popularPagingController.dispose();
    _topRatedPagingController.dispose();
    super.dispose();
  }

  Widget OnTheAir(List<model.TvShow> tvShows) {
    return Column(
      children: [
        Container(
          child: CarouselSlider.builder(
            carouselController: _onTheAirController,
            itemCount: tvShows.length,
            options: CarouselOptions(
              aspectRatio: 2,
              autoPlay: true,
              enlargeCenterPage: true,
              onPageChanged: (int index, CarouselPageChangedReason reason) => setState(() => _currentOnTheAirIndex = index),
            ),
            itemBuilder: (context, index, realIndex) => TvShowPoster(tvShows[index]),
          ),
        ),
        Container(
          margin: EdgeInsets.only(top: 20),
          child: AnimatedSmoothIndicator(
            activeIndex: _currentOnTheAirIndex,
            count: tvShows.length,
            effect: ExpandingDotsEffect(
              dotWidth: 10,
              dotHeight: 10,
              dotColor: Colors.white30,
              activeDotColor: Theme.of(context).primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget TvShowPoster(model.TvShow tvShow) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              child: CachedNetworkImage(
                imageUrl: '${Urls.getBestImageUrl(context)}${tvShow.backdropPath}',
                fit: BoxFit.cover,
                placeholder: (context, url) {
                  return Container(
                    decoration: BoxDecoration(color: Theme.of(context).cardColor),
                    child: Align(
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(),
                    ),
                  );
                },
                errorWidget: (context, url, error) {
                  return Container(
                    decoration: BoxDecoration(color: Theme.of(context).cardColor),
                    child: Align(
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.error,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Colors.transparent,
                    Theme.of(context).primaryColor.withOpacity(.1),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
              child: Column(
                children: [
                  Spacer(),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.only(
                      left: 14,
                      bottom: 8,
                    ),
                    child: Text(
                      tvShow.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => navigate(destination: TvShow(tvShow)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget Category(String title, {String? source, PagingController? pagingController, List<model.TvShow>? tvShows}) {
    Widget titleContainer = Row(
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Spacer(),
        if (tvShows == null) GestureDetector(
          onTap: () {
            navigate(
              destination: ViewAll(
                title: title,
                source: source!,
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
    );
    late Widget contentContainer;

    if (pagingController != null) {
      contentContainer = PagedListView(
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
      );
    } else {
      contentContainer = ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tvShows!.length,
        itemBuilder: (context, index) {
          return Container(
            margin: EdgeInsets.only(right: (index + 1) != tvShows.length ? 18 : 0),
            child: TvShowCard(tvShows[index], recentlyWatched: true),
          );
        },
      );
    }

    return Container(
      margin: EdgeInsets.only(top: 30),
      child: Column(
        children: [
          titleContainer,
          Container(
            height: MediaQuery.of(context).size.height * 0.25,
            margin: EdgeInsets.only(top: 10),
            child: contentContainer,
          ),
        ],
      ),
    );
  }

  Widget TvShowCard(model.TvShow tvShow, {bool recentlyWatched = false}) {
    List<String> firstAirDateContent = tvShow.firstAirDate.split('-');
    String firstAirYear = firstAirDateContent[0];

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
              return PopupMenuContainer<String>(
                items: recentlyWatched ? [
                  PopupMenuItem(
                    value: 'remove',
                    child: Text(
                      'Remove',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ),
                ] : null,
                onItemSelected: (action) async {
                  if (action != null) {
                    if (action == 'remove') removeFromRecentlyWatched(tvShow);
                  }
                },
                child: Container(
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
                    onTap: () => navigate(destination: TvShow(tvShow)),
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
          width: MediaQuery.of(context).size.width * 0.3,
          margin: EdgeInsets.only(top: 10),
          child: Text(
            tvShow.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.displayMedium,
          ),
        ),
        Container(
          width: MediaQuery.of(context).size.width * 0.3,
          margin: EdgeInsets.only(top: 5),
          child: Text(
            firstAirYear,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.displaySmall!.copyWith(color: Colors.white54),
          ),
        ),
      ],
    );
  }

  Widget StreamingPlatforms(List<StreamingPlatform> streamingPlatforms) {
    return Container(
      margin: EdgeInsets.only(top: 30),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            child: Text(
              'Providers',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Container(
            height: MediaQuery.of(context).size.height * 0.15,
            margin: EdgeInsets.only(top: 10),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: streamingPlatforms.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: EdgeInsets.only(right: (index + 1) != streamingPlatforms.length ? 18 : 0),
                  child: StreamingPlatformCard(streamingPlatforms[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget StreamingPlatformCard(StreamingPlatform streamingPlatform) {
    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          padding: EdgeInsets.all(18),
          child: Image.asset(
            'assets${streamingPlatform.logoPath}',
            width: MediaQuery.of(context).size.width * .4,
            color: Colors.white,
          ),
        ),
        onTap: () => navigate(
          destination: ViewAll(
            title: streamingPlatform.name,
            source: Urls.discoverTvShow,
            parameters: {
              'with_watch_providers': '${streamingPlatform.id}',
              'watch_region': 'US',
            },
            pageType: PageType.tv_shows,
          ),
        ),
      ),
    );
  }

  Widget Genres(List<model.Genre> genres) {
    return Container(
      margin: EdgeInsets.only(top: 30),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            child: Text(
              'Genres',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Container(
            height: MediaQuery.of(context).size.height * 0.2,
            margin: EdgeInsets.only(top: 10),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: genres.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: EdgeInsets.only(right: (index + 1) != genres.length ? 18 : 0),
                  child: GenreCard(genres[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget GenreCardImageBuilder(model.Genre genre, {required ImageProvider image}) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * .6,
      child: Column(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Container(
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
                  child: Container(),
                  onTap: () => navigate(
                    destination: ViewAll(
                      title: genre.name,
                      source: Urls.discoverTvShow,
                      parameters: {'with_genres': '${genre.id}'},
                      pageType: PageType.tv_shows,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(top: 10),
            child: Text(
              genre.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.displayMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget GenreCard(model.Genre genre) {
    Widget error = Container(
      width: MediaQuery.of(context).size.width * .6,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Container(),
      ),
    );

    Widget placeholder = Container(
      width: MediaQuery.of(context).size.width * .6,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Align(
          alignment: Alignment.center,
          child: CircularProgressIndicator(),
        ),
      ),
    );

    Widget future = FutureBuilder<String>(
      future: getGenreBackdrop(genre),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        switch (snapshot.connectionState) {
          case ConnectionState.waiting: return placeholder;
          default:
            if (snapshot.hasError) return error;
            else
              return CachedNetworkImage(
                imageUrl: '${Urls.getBestImageUrl(context)}${snapshot.data!}',
                placeholder: (context, url) => placeholder,
                imageBuilder: (context, image) {
                  return GenreCardImageBuilder(genre, image: image);
                },
                errorWidget: (context, url, _) => error,
              );
        }
      },
    );

    Widget card = CachedNetworkImage(
      imageUrl: '${Urls.getBestImageUrl(context)}${genre.backdropPath}',
      placeholder: (context, url) => placeholder,
      imageBuilder: (context, image) {
        return GenreCardImageBuilder(genre, image: image);
      },
      errorWidget: (context, url, _) => error,
    );

    if (genre.backdropPath == null) {
      return future;
    } else {
      return card;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        color: Theme.of(context).primaryColor,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        onRefresh: () async {
          _popularPagingController.dispose();
          _topRatedPagingController.dispose();

          setState(() {
            _isLoading = true;
            _onTheAir = [];
            _recentlyWatched = [];
            _rawRecentlyWatched = {};
            _genres = [];
            _popularResults = model.SearchResults(page: 0, totalPages: 0, totalResults: 0);
            _topRatedResults = model.SearchResults(page: 0, totalPages: 0, totalResults: 0);
            _popularPagingController = PagingController(firstPageKey: 0);
            _topRatedPagingController = PagingController(firstPageKey: 0);
          });
          getCategories();
        },
        child: !_isLoading ? SingleChildScrollView(
          child: SafeArea(
            child: Container(
              margin: EdgeInsets.all(18),
              child: Column(
                children: [
                  OnTheAir(_onTheAir),
                  if (_recentlyWatched.isNotEmpty) Category('Recently watched', tvShows: _recentlyWatched),
                  Category('Popular', source: Urls.popularTvShows, pagingController: _popularPagingController),
                  Category('Top rated', source: Urls.topRatedTvShows, pagingController: _topRatedPagingController),
                  StreamingPlatforms(_streamingPlatforms),
                  Genres(_genres),
                ],
              ),
            ),
          ),
        ) : Container(),
      ),
    );
  }
}