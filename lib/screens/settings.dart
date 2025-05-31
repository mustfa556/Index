import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_settings_ui/flutter_settings_ui.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:index/screens/landing.dart';
import 'package:index/models/server.dart';
import 'package:index/screens/open_source_libraries.dart';
import 'package:index/screens/subtitles_preferences.dart';
import 'package:index/utils/db_names.dart';
import 'package:index/utils/extractor.dart';
import 'package:index/utils/preferences.dart';
import 'package:index/utils/spinner.dart';
import 'package:index/utils/urls.dart';
import 'package:swipeable_page_route/swipeable_page_route.dart';
import 'package:url_launcher/url_launcher.dart';

class Settings extends StatefulWidget {
  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  Preferences _preferences = Preferences();
  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  FirebaseAuth _auth = FirebaseAuth.instance;
  Spinner? _spinner;

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

  openServerSelector() async {
    String savedServerName = await _preferences.getServer();
    List<Server> servers = Extractor.servers;

    await showModalBottomSheet(
      context: context,
      builder: (context) {
        String serverName = savedServerName;

        return StatefulBuilder(
          builder: (context, setState) {
            return ListView.builder(
              shrinkWrap: true,
              itemCount: servers.length,
              itemBuilder: (context, index) {
                Server server = servers[index];
                bool isSelected = server.name == serverName;

                return ListTile(
                  selected: isSelected,
                  selectedColor: Theme.of(context).primaryColor,
                  selectedTileColor: Theme.of(context).primaryColor.withOpacity(.2),
                  titleTextStyle: Theme.of(context).textTheme.displayMedium!.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  title: Text(server.name),
                  leading: isSelected ? Icon(Icons.check) : null,
                  onTap: () async {
                    await _preferences.setServer(server);
                    setState(() => serverName = server.name);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  openSeekDurationSelector() async {
    int savedSeekDuration = await _preferences.getSeekDuration();
    List<int> seekDurations = [5, 15, 30, 45, 60];

    await showModalBottomSheet(
      context: context,
      builder: (context) {
        int seekDuration = savedSeekDuration;

        return StatefulBuilder(
          builder: (context, setState) {
            return ListView.builder(
              shrinkWrap: true,
              itemCount: seekDurations.length,
              itemBuilder: (context, index) {
                bool isSelected = seekDurations[index] == seekDuration;

                return ListTile(
                  selected: isSelected,
                  selectedColor: Theme.of(context).primaryColor,
                  selectedTileColor: Theme.of(context).primaryColor.withOpacity(.2),
                  titleTextStyle: Theme.of(context).textTheme.displayMedium!.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  title: Text(seekDurations[index] != 60 ? '${seekDurations[index]} s' : '1 m'),
                  leading: isSelected ? Icon(Icons.check) : null,
                  onTap: () async {
                    await _preferences.setSeekDuration(seekDurations[index]);
                    setState(() => seekDuration = seekDurations[index]);
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  openAbout() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String version = packageInfo.version;

    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          width: double.infinity,
          margin: EdgeInsets.all(18),
          child: SafeArea(
            top: false,
            left: false,
            right: false,
            bottom: Platform.isIOS,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/icon.png',
                  width: 200,
                  height: 200,
                ),
                Container(
                  margin: EdgeInsets.only(top: 25),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: Theme.of(context).textTheme.displayMedium,
                      children: [
                        TextSpan(text: 'Developed by '),
                        TextSpan(
                          text: 'Moses Mbaga',
                          style: Theme.of(context).textTheme.displayMedium!.copyWith(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                          recognizer: TapGestureRecognizer()..onTap = () async {
                            await launchUrl(Uri.parse(Urls.mosesGithub));
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  margin: EdgeInsets.only(top: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        child: Text(
                          '$version',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                      ),
                      Text(
                        ' · ',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      GestureDetector(
                        onTap: () async {
                          await launchUrl(Uri.parse(Urls.github));
                        },
                        child: Text(
                          'GitHub',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displayMedium!.copyWith(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  showDeleteAccountConfirmation() async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Delete account'),
          content: Text('Are you sure that you want to close your account? Your account will be delete your account, along with all the saved data.\nYou can create a new account at any time.\n\nFor security reasons, you will be asked to re-authenticate first'),
          actions: [
            TextButton(
              child: Text(
                'Cancel',
                style: Theme.of(context).textTheme.displayMedium!.copyWith(color: Colors.white54),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(
                'Delete',
                style: Theme.of(context).textTheme.displayMedium!.copyWith(color: Theme.of(context).primaryColor),
              ),
              onPressed: () => reauthenticate(),
            ),
          ],
        );
      },
    );
  }

  reauthenticate() async {
    _spinner!.show();

    GoogleSignIn instance = GoogleSignIn();

    GoogleSignInAccount? googleUser = await instance.signIn();
    GoogleSignInAuthentication? googleAuth = await googleUser?.authentication;

    var credential = GoogleAuthProvider.credential(
      accessToken: googleAuth?.accessToken,
      idToken: googleAuth?.idToken,
    );

    try {
      FirebaseAuth auth = FirebaseAuth.instance;
      await auth.signInWithCredential(credential);

      _spinner!.dismiss();

      deleteAccount();
    } catch (e) {
      print(e);

      _spinner!.dismiss();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to re-authenticate',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          backgroundColor: Theme.of(context).cardColor,
        ),
      );
    }
  }

  deleteAccount() async {
    _spinner!.show();

    await Future.wait([
      clearRecentSearches(showSpinner: false, showSnackBar: false),
      clearFavorites(showSpinner: false, showSnackBar: false),
      clearRecentlyWatched(showSpinner: false, showSnackBar: false),
    ]);
    await _preferences.clear();

    await _auth.currentUser!.delete();

    _spinner!.dismiss();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Account deleted',
          style: Theme.of(context).textTheme.displayMedium,
        ),
        backgroundColor: Theme.of(context).cardColor,
      ),
    );

    navigate(destination: Landing(), replace: true);
  }

  Future<void> clearRecentSearches({bool showSpinner = true, bool showSnackBar = true}) async {
    if (showSpinner) _spinner!.show();
    await _firestore.collection(DB.recentSearches).doc(_auth.currentUser!.uid).delete();
    if (showSpinner) _spinner!.dismiss();

    if (showSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recent searches cleared successfully',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          backgroundColor: Theme.of(context).cardColor,
        ),
      );
    }
  }

  Future<void> clearFavorites({bool showSpinner = true, bool showSnackBar = true}) async {
    if (showSpinner) _spinner!.show();
    await _firestore.collection(DB.favorites).doc(_auth.currentUser!.uid).delete();
    if (showSpinner) _spinner!.dismiss();

    if (showSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Favorites cleared successfully',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          backgroundColor: Theme.of(context).cardColor,
        ),
      );
    }
  }

  Future<void> clearRecentlyWatched({bool showSpinner = true, bool showSnackBar = true}) async {
    if (showSpinner) _spinner!.show();
    await _firestore.collection(DB.recentlyWatched).doc(_auth.currentUser!.uid).delete();
    if (showSpinner) _spinner!.dismiss();

    if (showSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Recently watched cleared successfully',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          backgroundColor: Theme.of(context).cardColor,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _spinner = Spinner(context);

      await FirebaseAnalytics.instance.logScreenView(
        screenName: 'Settings',
      );
    });
  }

  Widget UserCard() {
    String photoUrl = _auth.currentUser!.photoURL ?? '';
    String name = _auth.currentUser!.displayName ?? 'User';
    String email = _auth.currentUser!.email ?? 'user@email.com';

    return Container(
      margin: EdgeInsets.only(
        top: 18,
        left: 18,
        right: 18,
      ),
      child: Row(
        children: [
          SizedBox(
            width: MediaQuery.of(context).size.width * .2,
            height: MediaQuery.of(context).size.width * .2,
            child: CircleAvatar(
              backgroundColor: Theme.of(context).cardColor,
              child: CachedNetworkImage(
                imageUrl: photoUrl,
                placeholder: (context, url) {
                  return Align(
                    alignment: Alignment.center,
                    child: CircularProgressIndicator(),
                  );
                },
                imageBuilder: (context, image) {
                  return Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1000),
                      image: DecorationImage(
                        image: image,
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
                errorWidget: (context, url, error) {
                  return Container(
                    width: double.infinity,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(1000)),
                    child: Icon(
                      Icons.account_circle,
                      color: Theme.of(context).primaryColor,
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                  Padding(padding: EdgeInsets.symmetric(vertical: 2.5)),
                  Text(
                    email,
                    style: Theme.of(context).textTheme.displayMedium!.copyWith(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Text SectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall!.copyWith(
        fontSize: 20,
        color: Theme.of(context).primaryColor,
      ),
    );
  }

  SettingsTile SectionTile({
    required String title,
    String? description,
    required IconData icon,
    Widget? trailing,
    required Function(BuildContext context) onPressed,
  }) {
    return SettingsTile(
      title: Text(
        title,
        style: Theme.of(context).textTheme.displayMedium,
      ),
      description: description != null ? Text(
        description,
        style: Theme.of(context).textTheme.displaySmall!.copyWith(color: Colors.white54),
      ) : null,
      leading: Icon(icon),
      trailing: trailing,
      backgroundColor: Platform.isIOS ? Theme.of(context).cardColor: Colors.transparent,
      onPressed: onPressed,
    );
  }

  SettingsList Settings() {
    SettingsThemeData settingsThemeData = SettingsThemeData(
      titleTextColor: Theme.of(context).primaryColor,
      settingsListBackground: Theme.of(context).scaffoldBackgroundColor,
    );

    return SettingsList(
      lightTheme: settingsThemeData,
      darkTheme: settingsThemeData,
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      sections: [
        SettingsSection(
          title: SectionTitle('Playback'),
          tiles: [
            SectionTile(
              title: 'Server',
              description: 'Select a server that works best for you',
              icon: Icons.dns_outlined,
              trailing: Platform.isIOS ? Icon(Icons.keyboard_arrow_right_outlined) : null,
              onPressed: (context) => openServerSelector(),
            ),
            SectionTile(
              title: 'Subtitles',
              description: 'Customize the subtitles style to fit your preference',
              icon: Icons.subtitles_outlined,
              trailing: Platform.isIOS ? Icon(Icons.keyboard_arrow_right_outlined) : null,
              onPressed: (context) => navigate(destination: SubtitlesPreferences()),
            ),
            SectionTile(
              title: 'Seek duration',
              description: 'Adjust how long the seek forward/backward duration is',
              icon: Icons.update,
              trailing: Platform.isIOS ? Icon(Icons.keyboard_arrow_right_outlined) : null,
              onPressed: (context) => openSeekDurationSelector(),
            ),
          ],
        ),
        SettingsSection(
          title: SectionTitle('App'),
          tiles: [
            SectionTile(
              title: 'About',
              icon: Icons.info_outline_rounded,
              trailing: Platform.isIOS ? Icon(Icons.keyboard_arrow_right_outlined) : null,
              onPressed: (context) => openAbout(),
            ),
            SectionTile(
              title: 'Open Source libraries',
              icon: Icons.description_outlined,
              trailing: Platform.isIOS ? Icon(Icons.keyboard_arrow_right_outlined) : null,
              onPressed: (context) => navigate(destination: OpenSourceLibraries()),
            ),
          ],
        ),
        SettingsSection(
          title: SectionTitle('Other'),
          tiles: [
            SectionTile(
              title: 'Clear recent searches',
              description: 'Deletes all the recent search queries',
              icon: Icons.search_off,
              trailing: Platform.isIOS ? Icon(Icons.keyboard_arrow_right_outlined) : null,
              onPressed: (context) => clearRecentSearches(),
            ),
            SectionTile(
              title: 'Clear favorites',
              description: 'Deletes all your favorites',
              icon: Icons.favorite_border,
              trailing: Platform.isIOS ? Icon(Icons.keyboard_arrow_right_outlined) : null,
              onPressed: (context) => clearFavorites(),
            ),
            SectionTile(
              title: 'Clear recently watched',
              description: 'Deletes all the progress of recently watched movies and TV shows',
              icon: Icons.video_library_outlined,
              trailing: Platform.isIOS ? Icon(Icons.keyboard_arrow_right_outlined) : null,
              onPressed: (context) => clearRecentlyWatched(),
            ),
            SectionTile(
              title: 'Delete account',
              description: 'Delete your account, along with all the saved data. You can create a new account at any time',
              icon: Icons.no_accounts_rounded,
              trailing: Platform.isIOS ? Icon(Icons.keyboard_arrow_right_outlined) : null,
              onPressed: (context) => showDeleteAccountConfirmation(),
            ),
            SectionTile(
              title: 'Sign out',
              icon: Icons.exit_to_app,
              trailing: Platform.isIOS ? Icon(Icons.keyboard_arrow_right_outlined) : null,
              onPressed: (context) async {
                await GoogleSignIn().signOut();
                await FirebaseAuth.instance.signOut();
                navigate(destination: Landing(), replace: true);
              },
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            UserCard(),
            Settings(),
          ],
        ),
      ),
    );
  }
}