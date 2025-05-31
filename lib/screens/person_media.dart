import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:index/models/movie.dart' as model;
import 'package:index/models/person.dart' as model;
import 'package:index/models/tv_show.dart'  as model;
import 'package:index/screens/movie.dart';
import 'package:index/screens/tv_show.dart';
import 'package:index/utils/api_keys.dart';
import 'package:index/utils/enums.dart';
import 'package:index/utils/spinner.dart';
import 'package:index/utils/urls.dart';
import 'package:swipeable_page_route/swipeable_page_route.dart';

//ignore: must_be_immutable
class PersonMedia extends StatefulWidget {
  model.Person person;

  PersonMedia(this.person);

  @override
  _PersonMediaState createState() => _PersonMediaState();
}

class _PersonMediaState extends State<PersonMedia> with TickerProviderStateMixin  {
  model.Person? _person;
  List<model.Movie> _movies = [];
  List<model.TvShow> _tvShows = [];
  late TabController _tabController;
  PageType _pageType = PageType.movies;
  Spinner? _spinner;
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

  getMedia() async {
    _spinner!.show();
    await Future.wait([
      getMovies(),
      getTvShows(),
    ]);
    _spinner!.dismiss();
  }

  Future<void> getMovies() async {
    Map<String, String> headers = {
      HttpHeaders.authorizationHeader: 'Bearer ${APIKeys.tmdbAccessTokenAuth}',
    };

    Uri uri = Uri.parse(Urls.getPersonMovies(_person!.id));
    Response request = await http.get(
      uri,
      headers: headers,
    );

    String response = request.body;
    if (!kReleaseMode) print(response);

    if (response.isNotEmpty) {
      List data = json.decode(response)['cast'] as List;
      List<model.Movie> movies = data.map((json) => model.Movie.fromJson(json)).toList();
      setState(() => _movies = movies);
    } else {
      print('Failed to get person movies');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to get movies',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          backgroundColor: Theme.of(context).cardColor,
        ),
      );
    }
  }

  Future<void> getTvShows() async {
    Map<String, String> headers = {
      HttpHeaders.authorizationHeader: 'Bearer ${APIKeys.tmdbAccessTokenAuth}',
    };

    Uri uri = Uri.parse(Urls.getPersonTvShows(_person!.id));
    Response request = await http.get(
      uri,
      headers: headers,
    );

    String response = request.body;
    if (!kReleaseMode) print(response);

    if (response.isNotEmpty) {
      List data = json.decode(response)['cast'] as List;
      List<model.TvShow> tvShows = data.map((json) => model.TvShow.fromJson(json)).toList();
      setState(() => _tvShows = tvShows);
    } else {
      print('Failed to get person tv shows');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to get TV shows',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          backgroundColor: Theme.of(context).cardColor,
        ),
      );
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
    _person = widget.person;
    super.initState();

    initConnectivity();

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      PageType pageType = _tabController.index == 0 ? PageType.movies : PageType.tv_shows;
      setState(() => _pageType = pageType);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _spinner = Spinner(context);
      await FirebaseAnalytics.instance.logScreenView(
        screenName: 'Person Media',
      );
      getMedia();
    });
  }

  @override
  void dispose() {
    _connectionSubscription.cancel();
    super.dispose();
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
              'The person has no content',
              style: Theme.of(context).textTheme.displayMedium!.copyWith(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }

  Widget Movies() {
    return _movies.isNotEmpty ? GridView.builder(
      itemCount: _movies.length,
      itemBuilder: (context, index) => ResultCard(movie: _movies[index]),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        childAspectRatio: 1/2,
      ),
    ) : NoContent();
  }

  Widget TvShows() {
    return _tvShows.isNotEmpty ? GridView.builder(
      itemCount: _tvShows.length,
      itemBuilder: (context, index) => ResultCard(tvShow: _tvShows[index]),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        childAspectRatio: 1/2,
      ),
    ) : NoContent();
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
        title: Text(_person!.name),
        bottom: _isConnectedToInternet ? TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: Icon(Icons.movie),
              text: 'Movies',
            ),
            Tab(
              icon: Icon(Icons.video_library),
              text: 'TV Shows',
            ),
          ],
        ) : null,
      ),
      body: SafeArea(
        child: Container(
          margin: EdgeInsets.all(18),
          child: _isConnectedToInternet ? TabBarView(
            controller: _tabController,
            children: [
              Movies(),
              TvShows(),
            ],
          ) : NoInternet(),
        ),
      ),
    );
  }
}