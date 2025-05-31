import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import 'package:index/screens/tv_show.dart';
import 'package:index/utils/api_keys.dart';
import 'package:index/screens/movie.dart';
import 'package:index/models/movie.dart' as model;
import 'package:index/models/search_results.dart' as model;
import 'package:index/models/tv_show.dart' as model;
import 'package:index/utils/db_names.dart';
import 'package:index/utils/enums.dart';
import 'package:index/utils/urls.dart';
import 'package:swipeable_page_route/swipeable_page_route.dart';

//ignore: must_be_immutable
class Search extends StatefulWidget {
  PageType pageType;

  Search({
    required this.pageType,
  });

  @override
  _SearchState createState() => _SearchState();
}

class _SearchState extends State<Search> {
  PageType? _pageType;
  bool _isSearched = false;
  TextEditingController _searchController = TextEditingController();
  model.SearchResults _searchResults = model.SearchResults(page: 0, totalPages: 0, totalResults: 0);
  PagingController _pagingController = PagingController(firstPageKey: 0);
  List<String> _recentSearches = [];
  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  FirebaseAuth _auth = FirebaseAuth.instance;
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
      );
    }
  }

  getRecentSearches() async {
    final user = _firestore.collection(DB.recentSearches).doc(_auth.currentUser!.uid);
    await user.get().then((DocumentSnapshot doc) {
      Map<dynamic, dynamic> data = (doc.data() ?? {}) as Map<dynamic, dynamic>;
      List<String> recentSearches = ((data[_pageType == PageType.movies ? 'movies' : 'tv_shows'] ?? []) as List<dynamic>).cast<String>();

      setState(() => _recentSearches = recentSearches);
    }, onError: (e) {
      print("Error getting recent searches: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to get recent searches',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          backgroundColor: Theme.of(context).cardColor,
        ),
      );
    });
  }

  addToRecentSearches(String query) async {
    List<String> recentSearches = _recentSearches;
    recentSearches.add(query);

    final user = _firestore.collection(DB.recentSearches).doc(_auth.currentUser!.uid);
    await user.set({
      _pageType == PageType.movies ? 'movies' : 'tv_shows': recentSearches,
    }, SetOptions(merge: true));

    setState(() => _recentSearches = recentSearches);
  }

  removeFromRecentSearches(String query) async {
    List<String> recentSearches = _recentSearches;
    recentSearches.remove(query);

    final user = _firestore.collection(DB.recentSearches).doc(_auth.currentUser!.uid);
    await user.set({
      (_pageType == PageType.movies ? 'movies' : 'tv_shows'): recentSearches,
    }, SetOptions(merge: true));

    setState(() => _recentSearches = recentSearches);
  }

  search({required String query, required int pageKey}) async {
    Map<String, dynamic> parameters = {
      'query': query,
      'include_adult': 'false',
      'page': pageKey == 0 ? '1' : '${_searchResults.page + 1}',
    };
    Map<String, String> headers = {
      HttpHeaders.authorizationHeader: 'Bearer ${APIKeys.tmdbAccessTokenAuth}',
    };

    String url = _pageType == PageType.movies ? Urls.searchMovies : Urls.searchTvShows;

    Uri uri = Uri.parse(url).replace(queryParameters: parameters);

    Response request = await http.get(
      uri,
      headers: headers,
    );

    String response = request.body;
    if (!kReleaseMode) print(response);

    if (response.isNotEmpty) {
      model.SearchResults searchResults = model.SearchResults.fromJson(
        _pageType!,
        json.decode(response),
      );

      setState(() => _searchResults = searchResults);

      bool isLastPage = pageKey == searchResults.totalResults;

      if (_pageType == PageType.movies) {
        if (isLastPage) {
          _pagingController.appendLastPage(searchResults.movies!);
        } else {
          int nextPageKey = pageKey + searchResults.movies!.length;
          _pagingController.appendPage(searchResults.movies!, nextPageKey);
        }
      } else {
        if (isLastPage) {
          _pagingController.appendLastPage(searchResults.tvShows!);
        } else {
          int nextPageKey = pageKey + searchResults.tvShows!.length;
          _pagingController.appendPage(searchResults.tvShows!, nextPageKey);
        }
      }
    } else {
      _pagingController.error = 'error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to get results',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          backgroundColor: Theme.of(context).cardColor,
        ),
      );
    }
  }

  submitSearch(String query, {required bool isRecentSearch}) {
    if (query.isNotEmpty) {
      FocusManager.instance.primaryFocus?.unfocus();

      if (!_isSearched) {
        setState(() {
          if (isRecentSearch) _searchController.text = query;
          _isSearched = true;
        });
      }

      if (!isRecentSearch) addToRecentSearches(query);

      _pagingController.addPageRequestListener((pageKey) {
        search(
          query: query,
          pageKey: pageKey,
        );
      });
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

  @override
  void initState() {
    _pageType = widget.pageType;
    super.initState();

    initConnectivity();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await FirebaseAnalytics.instance.logScreenView(
        screenName: 'Search',
      );
      await getRecentSearches();
    });
  }

  @override
  void dispose() {
    _pagingController.dispose();
    _connectionSubscription.cancel();
    super.dispose();
  }

  AppBar SearchAppBar() {
    return AppBar(
      leading: BackButton(
        onPressed: () => Navigator.pop(context, 'refresh'),
      ),
      title: TextField(
        controller: _searchController,
        readOnly: _isConnectedToInternet ? _isSearched : false,
        textInputAction: TextInputAction.search,
        cursorColor: Colors.white,
        style: Theme.of(context).textTheme.displayMedium,
        decoration: InputDecoration(
          hintText: 'Type here...',
          hintStyle: Theme.of(context).textTheme.displayMedium!.copyWith(color: Colors.white54),
          border: InputBorder.none,
        ),
        onTapOutside: (event) => FocusManager.instance.primaryFocus?.unfocus(),
        onSubmitted: (query) => submitSearch(query, isRecentSearch: _recentSearches.contains(query)),
      )
    );
  }

  Widget ResultCard({model.Movie? movie, model.TvShow? tvShow}) {
    String posterUrl, title, releaseDate;
    double voteAverage;

    if (_pageType == PageType.movies) {
      posterUrl = '${Urls.imageBase_w185}${movie!.posterPath}';
      title = movie.title;
      releaseDate = movie.releaseDate;
      voteAverage = movie.voteAverage;
    } else {
      posterUrl = '${Urls.imageBase_w185}${tvShow!.posterPath}';
      title = tvShow.name;
      releaseDate = tvShow.firstAirDate;
      voteAverage = tvShow.voteAverage;
    }

    List<String> releaseDateContent = releaseDate.split('-');
    releaseDate = releaseDateContent[0];

    return Column(
      children: [
        Expanded(
          child: CachedNetworkImage(
            imageUrl: posterUrl,
            placeholder: (context, url) {
              return Container(
                width: double.infinity,
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
                width: double.infinity,
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
                              '$voteAverage',
                              style: Theme.of(context).textTheme.displaySmall,
                            ),
                          ),
                        ],
                      ),
                      Spacer(),
                    ],
                  ),
                  onTap: () {
                    if (_pageType == PageType.movies) {
                      navigate(destination: Movie(movie!));
                    } else {
                      navigate(destination: TvShow(tvShow!));
                    }
                  },
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
          width: double.infinity,
          margin: EdgeInsets.only(top: 10),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.displayMedium,
          ),
        ),
        Container(
          width: double.infinity,
          margin: EdgeInsets.only(
            top: 5,
            bottom: 10,
          ),
          child: Text(
            releaseDate,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.displaySmall!.copyWith(color: Colors.white54),
          ),
        ),
      ],
    );
  }

  Widget RecentSearches() {
    return ListView.builder(
      itemCount: _recentSearches.length,
      itemBuilder: (context, index) {
        String query = _recentSearches[index];
        return ListTile(
          leading: Icon(
            Icons.history,
            color: Colors.white54,
          ),
          title: Text(
            query,
            style: Theme.of(context).textTheme.displayMedium,
          ),
          trailing: IconButton(
            icon: Icon(
              Icons.close,
              color: Colors.white54,
            ),
            onPressed: () async => await removeFromRecentSearches(query),
          ),
          onTap: () => submitSearch(query, isRecentSearch: true),
        );
      },
    );
  }

  Widget SearchResults() {
    return PagedGridView(
      pagingController: _pagingController,
      builderDelegate: PagedChildBuilderDelegate(
        itemBuilder: (context, media, index) {
          if (_pageType == PageType.movies) {
            return ResultCard(movie: media as model.Movie);
          } else {
            return ResultCard(tvShow: media as model.TvShow);
          }
        },
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        childAspectRatio: 1/2,
      ),
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
      resizeToAvoidBottomInset: false,
      appBar: _pageType != null ? SearchAppBar() : null,
      body: _pageType != null ? SafeArea(
        child: Container(
          padding: EdgeInsets.all(18),
          child: _isConnectedToInternet ? (_isSearched ? SearchResults() : RecentSearches()) : NoInternet(),
        ),
      ) : Container(),
    );
  }
}