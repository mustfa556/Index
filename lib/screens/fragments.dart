import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:index/screens/favorites.dart';
import 'package:index/screens/landing.dart';
import 'package:index/models/navigation_page.dart';
import 'package:index/screens/movies.dart';
import 'package:index/screens/search.dart';
import 'package:index/screens/settings.dart';
import 'package:index/screens/tv_shows.dart';
import 'package:index/utils/enums.dart';
import 'package:swipeable_page_route/swipeable_page_route.dart';

//ignore: must_be_immutable
class Fragments extends StatefulWidget {
  int initialPageIndex, initialFavoritesTabIndex;

  Fragments({
    this.initialPageIndex = 0,
    this.initialFavoritesTabIndex = 0,
  });

  @override
  _FragmentsState createState() => _FragmentsState();
}

class _FragmentsState extends State<Fragments> with TickerProviderStateMixin {
  late int _selectedPageIndex;
  List<NavigationPage> _navigationPages = [];
  late TabController _tabController;
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

  checkUserSession() async {
    await FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null) {
        navigate(
          destination: Landing(),
          replace: true,
        );
      }
    });
  }

  populatePages() {
    _selectedPageIndex = widget.initialPageIndex;
    _tabController = TabController(length: 2, initialIndex: widget.initialFavoritesTabIndex, vsync: this);
    setState(() {
      _navigationPages = [
        NavigationPage(
          icon: Icons.movie,
          title: 'Movies',
          widget: Movies(),
          pageType: PageType.movies,
        ),
        NavigationPage(
          icon: Icons.video_library,
          title: 'TV Shows',
          widget: TvShows(),
          pageType: PageType.tv_shows,
        ),
        NavigationPage(
          icon: Icons.favorite,
          title: 'Favorites',
          widget: TabBarView(
            controller: _tabController,
            children: [
              Favorites(pageType: PageType.movies),
              Favorites(pageType: PageType.tv_shows),
            ],
          ),
          pageType: PageType.favorites,
        ),
        NavigationPage(
          icon: Icons.settings,
          title: 'Settings',
          widget: Settings(),
          pageType: PageType.settings,
        ),
      ];
    });
  }

  initConnectivity() async {
    bool isConnectedToInternet = await InternetConnection().hasInternetAccess;
    setState(() => _isConnectedToInternet = isConnectedToInternet);

    _connectionSubscription = InternetConnection().onStatusChange.listen((InternetStatus status) async {
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
    super.initState();
    initConnectivity();
    checkUserSession();
    populatePages();
  }

  @override
  void dispose() {
    _connectionSubscription.cancel();
    super.dispose();
  }

  Widget NavigationTile(int index) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: 18,
      ),
      child: ListTile(
        iconColor: Colors.white,
        selectedColor: Theme.of(context).primaryColor,
        selectedTileColor: Theme.of(context).primaryColor.withOpacity(.3),
        titleTextStyle: Theme.of(context).textTheme.displayMedium!.copyWith(
          fontWeight: _selectedPageIndex == index ? FontWeight.w900 : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        selected: _selectedPageIndex == index,
        leading: Icon(_navigationPages[index].icon),
        title: Container(
          padding: _selectedPageIndex == index ? EdgeInsets.symmetric(vertical: 16) : EdgeInsets.zero,
          child: Text(_navigationPages[index].title),
        ),
        onTap: () {
          setState(() => _selectedPageIndex = index);
          Navigator.pop(context);
        },
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
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(_navigationPages[_selectedPageIndex].title),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        bottom: _isConnectedToInternet && _selectedPageIndex == 2 ? TabBar(
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
        actions: [
          (_isConnectedToInternet && _selectedPageIndex <= 1) ? IconButton(
            icon: Icon(
              Icons.search,
              color: Colors.white,
            ),
            onPressed: () {
              navigate(
                destination: Search(pageType: _navigationPages[_selectedPageIndex].pageType),
              );
            },
          ) : Container(),
        ],
      ),
      body: _isConnectedToInternet ? _navigationPages[_selectedPageIndex].widget : NoInternet(),
      drawer: SafeArea(
        top: true,
        left: true,
        right: true,
        bottom: false,
        child: Drawer(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                height: 200,
                child: Center(
                  child: Image.asset(
                  'assets/icon.png',
                    width: 80,
                    height: 80,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(bottom: 20),
                child: Divider(color: Theme.of(context).cardColor),
              ),
              for (final (index, _) in _navigationPages.indexed) NavigationTile(index),
            ],
          ),
        ),
      ),
    );
  }
}