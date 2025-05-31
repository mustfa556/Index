import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:index/models/open_source_library.dart';
import 'package:swipeable_page_route/swipeable_page_route.dart';
import 'package:url_launcher/url_launcher.dart';

class OpenSourceLibraries extends StatefulWidget {
  @override
  _OpenSourceLibrariesState createState() => _OpenSourceLibrariesState();
}

class _OpenSourceLibrariesState extends State<OpenSourceLibraries> {
  List<OpenSourceLibrary> _libraries = [
    OpenSourceLibrary(name: 'archive', pubPath: '/archive'),
    OpenSourceLibrary(name: 'audio_video_progress_bar', pubPath: '/audio_video_progress_bar'),
    OpenSourceLibrary(name: 'cached_network_image', pubPath: '/cached_network_image'),
    OpenSourceLibrary(name: 'carousel_slider', pubPath: '/carousel_slider'),
    OpenSourceLibrary(name: 'connectivity_plus', pubPath: '/connectivity_plus'),
    OpenSourceLibrary(name: 'firebase_analytics', pubPath: '/firebase_analytics'),
    OpenSourceLibrary(name: 'firebase_auth', pubPath: '/firebase_auth'),
    OpenSourceLibrary(name: 'firebase_core', pubPath: '/firebase_core'),
    OpenSourceLibrary(name: 'firebase_crashlytics', pubPath: '/firebase_crashlytics'),
    OpenSourceLibrary(name: 'cloud_firestore', pubPath: '/cloud_firestore'),
    OpenSourceLibrary(name: 'firebase_remote_config', pubPath: '/firebase_remote_config'),
    OpenSourceLibrary(name: 'flutter_settings_ui', pubPath: '/flutter_settings_ui'),
    OpenSourceLibrary(name: 'font_awesome_flutter', pubPath: '/font_awesome_flutter'),
    OpenSourceLibrary(name: 'google_fonts', pubPath: '/google_fonts'),
    OpenSourceLibrary(name: 'google_sign_in', pubPath: '/google_sign_in'),
    OpenSourceLibrary(name: 'http', pubPath: '/http'),
    OpenSourceLibrary(name: 'infinite_scroll_pagination', pubPath: '/infinite_scroll_pagination'),
    OpenSourceLibrary(name: 'package_info_plus', pubPath: '/package_info_plus'),
    OpenSourceLibrary(name: 'path_provider', pubPath: '/path_provider'),
    OpenSourceLibrary(name: 'shared_preferences', pubPath: '/shared_preferences'),
    OpenSourceLibrary(name: 'smooth_page_indicator', pubPath: '/smooth_page_indicator'),
    OpenSourceLibrary(name: 'subtitle_wrapper_package', pubPath: '/subtitle_wrapper_package'),
    OpenSourceLibrary(name: 'swipeable_page_route', pubPath: '/swipeable_page_route'),
    OpenSourceLibrary(name: 'url_launcher', pubPath: '/url_launcher'),
    OpenSourceLibrary(name: 'wakelock_plus', pubPath: '/wakelock_plus'),
    OpenSourceLibrary(name: 'video_player', pubPath: '/video_player'),
  ];

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await FirebaseAnalytics.instance.logScreenView(
        screenName: 'Open Source Libraries',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Open Source libraries'),
      ),
      body: ListView.builder(
        itemCount: _libraries.length,
        itemBuilder: (context, index) {
          OpenSourceLibrary library = _libraries[index];
          return ListTile(
            title: Text(
              library.name,
              style: Theme.of(context).textTheme.displayMedium,
            ),
            onTap: () async {
              await launchUrl(Uri.parse('https://pub.dev/packages${library.pubPath}'));
            },
          );
        },
      ),
    );
  }
}