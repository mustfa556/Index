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
import 'package:index/models/movie.dart' as model;
import 'package:index/models/tv_show.dart' as model;
import 'package:index/screens/movie.dart';
import 'package:index/screens/tv_show.dart';
import 'package:index/utils/api_keys.dart';
import 'package:index/utils/db_names.dart';
import 'package:index/utils/enums.dart';
import 'package:index/utils/pop_up_menu.dart';
import 'package:index/utils/spinner.dart';
import 'package:index/utils/urls.dart';
import 'package:swipeable_page_route/swipeable_page_route.dart';

//ignore: must_be_immutable
class Favorites extends StatefulWidget {
  PageType pageType;

  Favorites({
    required this.pageType,
  });

  @override
  _FavoritesState createState() => _FavoritesState();
}

class _FavoritesState extends State<Favorites> {
  PageType? _pageType;
  Spinner? _spinner;
  FirebaseAuth _auth = FirebaseAuth.instance;
  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<dynamic> _favorites = [];
  List<int> _rawFavorites = [];

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
      ).then((task) {
        if (task != null && task == 'refresh') refresh();
      });
    }
  }

  Future<void> getFavorites() async {
    _spinner!.show();

    final user = _firestore.collection(DB.favorites).doc(_auth.currentUser!.uid);
    await user.get().then((DocumentSnapshot doc) {
      Map<dynamic, dynamic> data = (doc.data() ?? {}) as Map<dynamic, dynamic>;
      List<int> rawFavorites = ((data[_pageType == PageType.movies ? 'movies' : 'tv_shows'] ?? []) as List<dynamic>).cast<int>();
      setState(() => _rawFavorites = rawFavorites);
      for (int id in rawFavorites) getFavoriteDetails(id);
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

    _spinner!.dismiss();
  }

  Future<void> getFavoriteDetails(int id) async {
    Map<String, String> headers = {
      HttpHeaders.authorizationHeader: 'Bearer ${APIKeys.tmdbAccessTokenAuth}',
    };

    Uri uri = Uri.parse(
      _pageType == PageType.movies ? Urls.getMovieDetails(id) : Urls.getTvShowDetails(id),
    );

    Response request = await http.get(
      uri,
      headers: headers,
    );

    String response = request.body;
    if (!kReleaseMode) print(response);

    if (response.isNotEmpty) {
      var data = json.decode(response);

      var mediaModel = _pageType == PageType.movies ? model.Movie.fromJson(data) : model.TvShow.fromJson(data);

      setState(() => _favorites.add(mediaModel));
    } else {
      print('Failed to get favorite details: $id');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to get movie details',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          backgroundColor: Theme.of(context).cardColor,
        ),
      );
    }
  }

  removeFromRecentlyWatched(var mediaModel) async {
    List<int> rawFavorites = _rawFavorites;
    rawFavorites.removeWhere((id) => id == mediaModel.id);

    final user = _firestore.collection(DB.favorites).doc(_auth.currentUser!.uid);
    await user.set({
      'movies': rawFavorites,
    }, SetOptions(merge: true));

    setState(() {
      _favorites.remove(mediaModel);
      _rawFavorites = rawFavorites;
    });
  }

  refresh() async {
    _favorites = [];
    _rawFavorites = [];
    await getFavorites();
  }

  @override
  void initState() {
    _pageType = widget.pageType;
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _spinner = Spinner(context);
      await FirebaseAnalytics.instance.logScreenView(
        screenName: 'Favorites',
      );
      getFavorites();
    });
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
              return PopupMenuContainer<String>(
                items: [
                  PopupMenuItem(
                    value: 'remove',
                    child: Text(
                      'Remove',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                  ),
                ],
                onItemSelected: (action) async {
                  if (action != null) {
                    if (action == 'remove') removeFromRecentlyWatched(movie);
                  }
                },
                child: Container(
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

  Widget NoContent() {
    return Container(
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.new_releases_outlined,
            color: Colors.white54,
            size: 80,
          ),
          Container(
            margin: EdgeInsets.only(top: 10),
            child: Text(
              'You don\'t have any favorites',
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
      body: SafeArea(
        child: Container(
          margin: EdgeInsets.all(18),
          child: _favorites.isNotEmpty ? GridView.builder(
            itemCount: _favorites.length,
            itemBuilder: (context, index) {
              var mediaModel = _favorites[index];
              if (_pageType == PageType.movies) {
                return ResultCard(movie: mediaModel as model.Movie);
              } else {
                return ResultCard(tvShow: mediaModel as model.TvShow);
              }
            },
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              childAspectRatio: 1/2,
            ),
          ) : NoContent(),
        ),
      ),
    );
  }
}