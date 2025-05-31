import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:index/firebase_options.dart';
import 'package:index/screens/splash.dart';
import 'package:index/utils/preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await Preferences.init();
  await initializeFirebase();
  runApp(Index());
}

initializeFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseCrashlytics crashlytics = await FirebaseCrashlytics.instance;
  runZonedGuarded<Future<void>>(() async {
    if (!kIsWeb) {
      await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);
      FlutterError.onError = crashlytics.recordFlutterFatalError;
    }
  }, (error, stack) async {
    if (!kIsWeb) await crashlytics.recordError(error, stack, fatal: true);
  });
}

class Index extends StatelessWidget {
  const Index({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Index',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: Color(0xFFAB261D),
        scaffoldBackgroundColor: Color(0xFF120201),
        dialogBackgroundColor: Color(0xFF250604),
        cardColor: Color(0xFF250604),
        appBarTheme: AppBarTheme(
          scrolledUnderElevation: 0,
          backgroundColor: Color(0xFF120201),
          titleTextStyle: GoogleFonts.freckleFace(
            textStyle: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          iconTheme: IconThemeData(color: Colors.white),
          centerTitle: false,
        ),
        textTheme: TextTheme(
          titleLarge: GoogleFonts.freckleFace(
            textStyle: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          titleMedium: GoogleFonts.freckleFace(
            textStyle: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          titleSmall: GoogleFonts.freckleFace(
            textStyle: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          displayLarge: GoogleFonts.lexend(
            textStyle: TextStyle(
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          displayMedium: GoogleFonts.lexend(
            textStyle: TextStyle(
              fontSize: 15,
              color: Colors.white,
            ),
          ),
          displaySmall: GoogleFonts.lexend(
            textStyle: TextStyle(
              fontSize: 14,
              color: Colors.white,
            ),
          ),
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(color: Color(0xFFAB261D)),
        tabBarTheme: TabBarTheme(
          indicatorColor: Color(0xFFAB261D),
          labelColor: Color(0xFFAB261D),
          dividerColor: Color(0xFF250604),
          unselectedLabelColor: Colors.white54,
        ),
        menuTheme: MenuThemeData(
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(Color(0xFF250604)),
          ),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          showDragHandle: true,
          backgroundColor: Color(0xFF250604),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(25),
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Color(0xFF250604),
          behavior: SnackBarBehavior.floating,
        )
      ),
      home: Splash(),
    );
  }
}
