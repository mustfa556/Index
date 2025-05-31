import 'dart:convert';

import 'package:index/models/server.dart';
import 'package:index/models/subtitle_style.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Preferences {
  static final Preferences _instance = Preferences._internal();

  factory Preferences() {
    return _instance;
  }

  Preferences._internal();

  static SharedPreferences? _prefs;

  static init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  setServer(Server server) async {
    await _prefs?.setString('server', server.name);
  }

  setSeekDuration(int seekDuration) async {
    await _prefs?.setInt('seekDuration', seekDuration);
  }

  setSubtitlesStyle(SubtitleStyle subtitlesStyle) async {
    await _prefs?.setString('subtitleStyle', json.encode(subtitlesStyle.toJson()));
  }

  Future<String> getServer() async {
    return _prefs?.getString('server') ?? 'Random';
  }

  Future<int> getSeekDuration() async {
    return _prefs?.getInt('seekDuration') ?? 15;
  }

  Future<SubtitleStyle> getSubtitlesStyle() async {
    Map<String, dynamic> data = json.decode(_prefs?.getString('subtitleStyle') ?? '{}');
    return SubtitleStyle.fromJson(data);
  }

  Future<void> clear() async {
    await _prefs?.clear();
  }
}