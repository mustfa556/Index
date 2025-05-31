import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:index/screens/fragments.dart';
import 'package:index/utils/spinner.dart';
import 'package:swipeable_page_route/swipeable_page_route.dart';
import 'package:video_player/video_player.dart';

class Landing extends StatefulWidget {
  @override
  _LandingState createState() => _LandingState();
}

class _LandingState extends State<Landing> {
  VideoPlayerController? _controller;
  Spinner? _spinner;

  initializeVideo() {
    _controller = VideoPlayerController.asset('assets/cover_portrait.mp4');
    _controller!.initialize().then((_) {
      _controller!.play();
      _controller!.setLooping(true);
    });
  }

  googleAuthentication() async {
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

      navigate(destination: Fragments());
    } catch (e) {
      print(e);

      _spinner!.dismiss();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to authenticate',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          backgroundColor: Theme.of(context).cardColor,
        ),
      );
    }
  }

  navigate({required Widget destination}) async {
    SwipeablePageRoute pageTransition = SwipeablePageRoute(
      canOnlySwipeFromEdge: true,
      builder: (BuildContext context) => destination,
    );

    await Navigator.pushReplacement(
      context,
      pageTransition,
    );
  }

  @override
  void initState() {
    super.initState();

    initializeVideo();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _spinner = Spinner(context);
      await FirebaseAnalytics.instance.logScreenView(
        screenName: 'Landing',
      );
    });
  }

  @override
  void dispose() {
    super.dispose();
    if (_controller != null) {
      _controller!.pause();
      _controller!.dispose();
      _controller = null;
    }
  }

  Widget BackgroundTint() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor.withOpacity(.5),
    );
  }

  Widget ContinueWithGoogle() {
    return Container(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        child: Container(
          width: double.infinity,
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(
                    FontAwesomeIcons.google,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.only(
                  right: 16,
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Spacer(),
                      Text(
                        'Continue with Google',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                      Spacer(),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          side: BorderSide(
            width: 3,
            color: Colors.white,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        onPressed: () {
          googleAuthentication();
        },
      ),
    );
  }

  Widget Content() {
    return Column(
      children: [
        Spacer(),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: 24,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.only(top: 36),
                child: Container(
                  width: double.infinity,
                  child: Text(
                    'Welcome!',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
              Container(
                margin: EdgeInsets.symmetric(vertical: 20),
                child: Container(
                  width: double.infinity,
                  child: Text(
                    'Discover a vast library of entertainment, from blockbuster hits to indie gems, all tailored to your tastes. Enjoy unlimited streaming on any device, create your personalized watchlist, and get ready for an unparalleled viewing experience.',
                    style: Theme.of(context).textTheme.displayMedium,
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
              SafeArea(
                top: false,
                left: false,
                right: false,
                bottom: true,
                child: Container(
                  margin: EdgeInsets.only(
                    bottom: 18,
                  ),
                  child: ContinueWithGoogle(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _controller != null ? Stack(
        children: [
          VideoPlayer(_controller!),
          BackgroundTint(),
          Content(),
        ],
      ) : Container(),
    );
  }
}