import 'dart:async';
import 'dart:io';

import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:index/models/duration_state.dart';
import 'package:index/models/stream.dart';
import 'package:index/utils/db_names.dart';
import 'package:index/utils/enums.dart';
import 'package:index/utils/preferences.dart';
import 'package:index/models/subtitle_style.dart' as local;
import 'package:subtitle_wrapper_package/subtitle_wrapper_package.dart';
import 'package:swipeable_page_route/swipeable_page_route.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

//ignore: must_be_immutable
class Player extends StatefulWidget {
  int id;
  int? seasonId, episodeId;
  String title;
  MediaStream stream;
  List<File>? subtitles;
  PageType pageType;

  Player({
    required this.id,
    this.seasonId,
    this.episodeId,
    required this.title,
    required this.stream,
    this.subtitles,
    required this.pageType,
  });

  @override
  _PlayerState createState() => _PlayerState();
}

class _PlayerState extends State<Player> with TickerProviderStateMixin {
  int? _id, _seasonId, _episodeId;
  String? _title;
  MediaStream? _stream;
  List<File>? _subtitles;
  PageType? _pageType;
  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  FirebaseAuth _auth = FirebaseAuth.instance;
  VideoPlayerController? _videoPlayerController;
  SubtitleController _subtitleController = SubtitleController(
    subtitleType: SubtitleType.srt,
    showSubtitles: false,
  );
  int _seekDuration = 0;
  DurationState _durationState = DurationState();
  int _watchedProgress = 0;
  bool _isSeekedToWatchedProgress = false;
  bool _isPlaying = true;
  bool _showControls = true;
  bool _showSubtitles = false;
  int _selectedSubtitle = 0;
  late AnimationController _scaleVideoAnimationController;
  Animation<double> _scaleVideoAnimation = const AlwaysStoppedAnimation<double>(1.0);
  bool _isZoomedIn = false;
  double _lastZoomGestureScale = 1.0;
  Preferences _preferences = Preferences();
  SubtitleStyle _subtitleStyle = SubtitleStyle();

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

  updateRecentlyWatched() async {
    final user = _firestore.collection(DB.recentlyWatched).doc(_auth.currentUser!.uid);
    await user.get().then((DocumentSnapshot doc) {
      Map<dynamic, dynamic> data = (doc.data() ?? {}) as Map<dynamic, dynamic>;
      var recentlyWatched;

      if (_pageType == PageType.movies) {
        recentlyWatched = ((data['movies'] ?? {}) as Map<dynamic, dynamic>).map<String, Map<String, dynamic>>((key, value) {
          return MapEntry(key, Map<String, dynamic>.from(value));
        });
        bool isInRecentlyWatched = recentlyWatched.keys.contains('$_id');

        if (recentlyWatched.isNotEmpty && isInRecentlyWatched) {
          Map<String, dynamic> movie = recentlyWatched['$_id']!;

          if (_videoPlayerController != null) movie['progress'] = _durationState.progress.inSeconds;
          movie['timestamp'] = DateTime.now().millisecondsSinceEpoch;

          if (movie['progress'] != null && movie['progress'] != 0) {
            setState(() => _watchedProgress = movie['progress']);
          }
        } else {
          if (_durationState.total.inSeconds > 0) {
            recentlyWatched['$_id'] = {
              'progress': _durationState.progress.inSeconds,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            };
          }
        }
      } else {
        recentlyWatched = ((data['tv_shows'] ?? {}) as Map<dynamic, dynamic>).map<String, Map<String, dynamic>>((key, value) {
          return MapEntry(key, Map<String, dynamic>.from(value));
        });

        if (recentlyWatched.keys.contains('$_id')) {
          if (_durationState.total.inSeconds > 0) {
            recentlyWatched['$_id']['visibleInMenu'] = true;
          }

          Map<String, dynamic> seasons = recentlyWatched['$_id'] as Map<String, dynamic>;

          if (seasons.containsKey('$_seasonId')) {
            Map<String, dynamic> episodes = seasons['$_seasonId'] as Map<String, dynamic>;

            if (episodes.keys.contains('$_episodeId')) {
              Map<String, dynamic> episode = episodes['$_episodeId'] as Map<String, dynamic>;

              if (_videoPlayerController != null) episode['progress'] = _durationState.progress.inSeconds;
              episode['timestamp'] = DateTime.now().millisecondsSinceEpoch;

              if (episode['progress'] != null && episode['progress'] != 0) {
                setState(() => _watchedProgress = episode['progress']);
              }
            } else {
              if (_durationState.total.inSeconds > 0) {
                episodes['$_episodeId'] = {
                  'progress': _videoPlayerController != null ? _durationState.progress.inSeconds : 0,
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                };
              }
            }
          } else {
            if (_durationState.total.inSeconds > 0) {
              seasons['$_seasonId'] = {
                '$_episodeId': {
                  'progress': _videoPlayerController != null ? _durationState.progress.inSeconds : 0,
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                },
              };
            }
          }
        } else {
          if (_durationState.total.inSeconds > 0) {
            recentlyWatched['$_id'] = {
              'visibleInMenu': true,
              '$_seasonId': {
                '$_episodeId': {
                  'progress': _videoPlayerController != null ? _durationState.progress.inSeconds : 0,
                  'timestamp': DateTime.now().millisecondsSinceEpoch,
                },
              },
            };
          }
        }
      }

      user.set({
        _pageType!.name: recentlyWatched,
      }, SetOptions(mergeFields: [_pageType!.name]));
    }, onError: (e) => print("Error getting user: $e"));
  }

  initializePlayer() async {
    local.SubtitleStyle localSubtitlesStyle = await _preferences.getSubtitlesStyle();
    SubtitleStyle subtitleStyle = SubtitleStyle(
      fontSize: localSubtitlesStyle.fontSize,
      textColor: local.SubtitleStyle.colors[localSubtitlesStyle.color]!,
      hasBorder: localSubtitlesStyle.hasBorder,
      borderStyle: SubtitleBorderStyle(
        strokeWidth: localSubtitlesStyle.borderStyle.strokeWidth,
        style: localSubtitlesStyle.borderStyle.style,
        color: local.Subtitle.Style.colors[localSubtitlesStyle.borderStyle.color]!,
      ),
    );
    setState(() => _subtitleStyle = subtitleStyle);

    setState(() {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(_stream!.url!),
        httpHeaders: _stream!.headers ?? {},
      );
    });

    _videoPlayerController!.initialize()
        .then((value) => playerInitListener())
        .catchError((error) => Navigator.pop(context, {'error': error}));
    _videoPlayerController!.addListener(playerListener);
  }

  setTargetNativeScale(double newValue) {
    if (!newValue.isFinite) return;
    setState(() {
      _scaleVideoAnimation = Tween<double>(begin: 1.0, end: newValue).animate(
        CurvedAnimation(
          parent: _scaleVideoAnimationController,
          curve: Curves.easeInOut,
        ),
      );
    });
  }

  playerInitListener() async {
    int seekDuration = await _preferences.getSeekDuration();
    setState(() => _seekDuration = seekDuration);

    final screenSize = MediaQuery.of(context).size;
    final videoSize = _videoPlayerController!.value.size;
    if (videoSize.width > 0) {
      final newTargetScale = screenSize.width / (videoSize.width * screenSize.height / videoSize.height);
      setTargetNativeScale(newTargetScale);
    }

    await _videoPlayerController!.play();

    Future.delayed(Duration(seconds: 5), () {
      if (mounted) setState(() => _showControls = false);
    });

    Timer.periodic(Duration(seconds: 15), (timer) {
      if (mounted) updateRecentlyWatched();
    });
  }

  playerListener() async {
    bool isPlaying = _videoPlayerController!.value.isPlaying;
    setState(() => _isPlaying = isPlaying);

    await Future.delayed(Duration(milliseconds: 500));

    if (_videoPlayerController!.value.hasError) {
      Navigator.pop(context, {'error': _videoPlayerController!.value.errorDescription});
      return;
    }

    Duration progress = _videoPlayerController!.value.position;
    Duration total = _videoPlayerController!.value.duration;
    bool isBuffering = false;

    if (isPlaying && _videoPlayerController!.value.isBuffering && (progress == _durationState.progress)) isBuffering = true;

    if (!_isSeekedToWatchedProgress && total.inSeconds != 0 && progress.inSeconds < _watchedProgress) {
      Duration watchedProgress = Duration(seconds: _watchedProgress);
      await seek(watchedProgress);
      setState(() => _isSeekedToWatchedProgress = true);
    }

    if (mounted) {
      setState(() {
        _durationState = DurationState(
          progress: progress,
          total: total,
          isBuffering: isBuffering,
        );
      });
    }

    if (total.inSeconds != 0 && progress == total) {
      await updateRecentlyWatched();
      endSession();
      Navigator.pop(context, {
        if (_episodeId != null) 'episodeId': _episodeId,
        'progress': _durationState.progress.inSeconds,
      });
    }
  }

  playPause() async {
    if (_isPlaying) {
      await _videoPlayerController!.pause();
    } else {
      await _videoPlayerController!.play();
    }
  }

  seekForward() async {
    Duration currentPosition = await _videoPlayerController!.value.position;
    Duration targetPosition = Duration(seconds: currentPosition.inSeconds + _seekDuration);
    await _videoPlayerController!.seekTo(targetPosition);
  }

  seekBack() async {
    Duration currentPosition = await _videoPlayerController!.value.position;
    Duration targetPosition = Duration(
      seconds: currentPosition.inSeconds - (currentPosition.inSeconds < _seekDuration ? currentPosition.inSeconds : _seekDuration),
    );
    await _videoPlayerController!.seekTo(targetPosition);
  }

  seek(Duration target) async => await _videoPlayerController!.seekTo(target);

  forceLandscape() async {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  forcePortrait() async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }

  setSubtitle(int index) async {
    String? subtitleContent = index >= 0 ? await _subtitles![index].readAsString() : null;

    setState(() {
      _subtitleController = SubtitleController(
        subtitleType: SubtitleType.srt,
        subtitlesContent: subtitleContent,
        showSubtitles: index >= 0,
      );
      _selectedSubtitle = index;
      _showSubtitles = index >= 0;
    });
  }

  showSubtitleSelector() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select subtitle'),
          content: Container(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _subtitles!.length,
              itemBuilder: (context, index) {
                bool isSelected = index == _selectedSubtitle;
                return ListTile(
                  title: Text(
                    'English ${index + 1}',
                    style: Theme.of(context).textTheme.displayMedium!.copyWith(
                      color: isSelected ? Theme.of(context).primaryColor : Colors.white,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  onTap: () async {
                    setSubtitle(index);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  endSession() {
    forcePortrait();
    WakelockPlus.disable();

    _videoPlayerController!.removeListener(playerListener);
    _videoPlayerController!.dispose();
  }

  @override
  void initState() {
    _id = widget.id;
    _seasonId = widget.seasonId;
    _episodeId = widget.episodeId;
    _title = widget.title;
    _stream = widget.stream;
    _subtitles = widget.subtitles;
    _pageType = widget.pageType;

    super.initState();

    forceLandscape();
    WakelockPlus.enable();

    _scaleVideoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 125),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await updateRecentlyWatched();
      await initializePlayer();
    });
  }

  @override
  void dispose() {
    endSession();
    super.dispose();
  }

  Widget Player() {
    return SubtitleWrapper(
      subtitleController: _subtitleController,
      videoPlayerController: _videoPlayerController!,
      subtitleStyle: _subtitleStyle,
      videoChild: ScaleTransition(
        scale: _scaleVideoAnimation,
        child: Center(
          child: AspectRatio(
            aspectRatio: _videoPlayerController!.value.aspectRatio,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: VideoPlayer(_videoPlayerController!),
            ),
          ),
        ),
      ),
    );
  }

  Widget Controls() {
    return AnimatedOpacity(
      opacity: _showControls ? 1 : 0,
      duration: Duration(milliseconds: 300),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Theme.of(context).scaffoldBackgroundColor.withOpacity(.5),
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.topCenter,
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: AppBar(
                    backgroundColor: Colors.transparent,
                    leading: BackButton(
                      onPressed: () async {
                        await updateRecentlyWatched();
                        Navigator.pop(context, {
                          if (_episodeId != null) 'episodeId': _episodeId,
                          'progress': _durationState.progress.inSeconds,
                        });
                      },
                    ),
                    title: Text(_title!),
                    actions: [
                      if (_subtitles != null && _subtitles!.isNotEmpty) InkWell(
                        borderRadius: BorderRadius.circular(1000),
                        onTap: () async {
                          if (_showSubtitles) {
                            if (_isPlaying) await _videoPlayerController!.pause();
                            showSubtitleSelector();
                            await _videoPlayerController!.play();
                          } else {
                            setSubtitle(0);
                            setState(() => _showSubtitles = true);
                          }
                        },
                        onLongPress: () => setSubtitle(-1),
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(_showSubtitles ? Icons.closed_caption_rounded : Icons.closed_caption_off),
                        ),
                      ),
                      IconButton(
                        icon: Icon(!_isZoomedIn ? Icons.zoom_out_map : Icons.zoom_in_map),
                        onPressed: () => setState(() {
                          if (_durationState.total.inSeconds > 0) {
                            if (_isZoomedIn) {
                              _scaleVideoAnimationController.reverse();
                            } else {
                              _scaleVideoAnimationController.forward();
                            }
                            _isZoomedIn = !_isZoomedIn;
                            _lastZoomGestureScale = 1.0;
                          }
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: FaIcon(
                        FontAwesomeIcons.rotateLeft,
                        color: Colors.white,
                        size: 25,
                      ),
                      onPressed: () => _durationState.total.inSeconds > 0 ? seekBack() : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                      ),
                      child: !_durationState.isBuffering ? IconButton(
                        icon: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 42,
                        ),
                        onPressed: () => playPause(),
                      ) : CircularProgressIndicator(),
                    ),
                    IconButton(
                      icon: FaIcon(
                        FontAwesomeIcons.rotateRight,
                        color: Colors.white,
                        size: 25,
                      ),
                      onPressed: () => _durationState.total.inSeconds > 0 ? seekForward() : null,
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(
                    left: 18,
                    right: 18,
                    bottom: 18,
                  ),
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: ProgressBar(
                      progress: _durationState.progress,
                      total: _durationState.total,
                      progressBarColor: Theme.of(context).primaryColor,
                      baseBarColor: Theme.of(context).primaryColor.withOpacity(.2),
                      bufferedBarColor: Theme.of(context).primaryColor.withOpacity(.5),
                      thumbColor: Theme.of(context).primaryColor,
                      timeLabelTextStyle: Theme.of(context).textTheme.displaySmall,
                      timeLabelPadding: 10,
                      onSeek: (target) => seek(target),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _videoPlayerController != null ? GestureDetector(
        onTap: () {
          if (_durationState.total.inSeconds > 0) {
            if (_showControls) {
              setState(() => _showControls = false);
            } else {
              setState(() => _showControls = true);
              Future.delayed(Duration(seconds: 5), () {
                if (mounted && _isPlaying) {
                  setState(() => _showControls = false);
                }
              });
            }
          }
        },
        onScaleUpdate: (details) {
          _lastZoomGestureScale = details.scale;
        },
        onScaleEnd: (details) {
          if (_durationState.total.inSeconds > 0) {
            if (_lastZoomGestureScale < 1.0) {
              setState(() {
                _isZoomedIn = true;
                _scaleVideoAnimationController.forward();
              });
            } else if (_lastZoomGestureScale > 1.0) {
              setState(() {
                _isZoomedIn = false;
                _scaleVideoAnimationController.reverse();
              });
            }
            _lastZoomGestureScale = 1.0;
          }
        },
        onDoubleTapDown: (details) async {
          if (_durationState.total.inSeconds > 0) {
            setState(() => _showControls = true);
            Future.delayed(Duration(seconds: 3), () {
              if (mounted && _isPlaying) {
                setState(() => _showControls = false);
              }
            });

            Future.delayed(Duration(milliseconds: 500), () async {
              var position = details.globalPosition;
              if (position.dx < MediaQuery.of(context).size.width / 2) {
                await seekBack();
              } else {
                await seekForward();
              }
            });
          }
        },
        child: Stack(
          children: [
            Container(color: Colors.black),
            Player(),
            Controls(),
          ],
        ),
      ) : Container(),
    );
  }
}