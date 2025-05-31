import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:index/models/movie.dart';
import 'package:index/models/server.dart';
import 'package:index/models/stream.dart';
import 'package:index/models/tv_show.dart';
import 'package:index/utils/extractors/auto_embed.dart';
import 'package:index/utils/extractors/embedsu.dart';
import 'package:index/utils/extractors/kisskh.dart';
import 'package:index/utils/extractors/rive_stream.dart';
import 'package:index/utils/preferences.dart';

class Extractor {
  static List<Server> servers = [
    Server(name: 'Random', extractor: null),
    Server(name: 'AutoEmbed', extractor: AutoEmbed()),
    Server(name: 'EmbedSu', extractor: EmbedSu()),
    Server(name: 'KissKh', extractor: KissKh()),
    //Server(name: 'MoviesApi', extractor: MoviesApi()),
    Server(name: 'RiveStream', extractor: RiveStream()),
    //Server(name: 'Whvx', extractor: Whvx()),
  ];

  Movie? movie;
  Episode? episode;

  Extractor({
    this.movie,
    this.episode,
  });

  Future<MediaStream> getStream() async {
    late Map<String, dynamic> parameters;

    if (movie != null) {
      parameters = {
        'tmdbId': movie!.id,
        'title': movie!.title,
      };
    } else if (episode != null) {
      parameters = {
        'tmdbId': episode!.tvShowId,
        'title': episode!.tvShowName,
        'season': episode!.season,
        'episode': episode!.number,
      };
    }

    Preferences preferences = Preferences();

    Random random = Random();

    String serverName = await preferences.getServer();

    var extractor;

    if (serverName != 'Random') {
      Server server = servers.firstWhere((server) => server.name == serverName);
      extractor = server.extractor;
    }

    MediaStream stream = MediaStream();

    while (stream.url == null && servers.isNotEmpty) {
      int randomIndex = random.nextInt(servers.length);

      if (serverName == 'Random' && extractor == null) {
        Server server = servers[randomIndex];
        extractor = server.extractor;
      }

      stream = await extractor.extract(parameters);

      if (stream.url == null) {
        if (serverName == 'Random') servers.removeAt(randomIndex);
        stream = MediaStream();
      }
    }

    if (!kReleaseMode) print('$serverName: ${stream.url}');
    return stream;
  }
}