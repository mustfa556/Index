import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:index/models/stream.dart';

class AutoEmbed {
  final String baseUrl = 'autoembed.cc';

  Future<MediaStream> extract(Map<String, dynamic> parameters) async {
    try {
      int tmdbId = parameters['tmdbId'];
      int? season = parameters['season'];
      int? episode = parameters['episode'];

      String serverUrl = season == null && episode == null
          ? 'https://$baseUrl/embed/oplayer.php?id=$tmdbId'
          : 'https://$baseUrl/embed/oplayer.php?id=$tmdbId&s=$season&e=$episode';

      String? streamUrl = await findStream(serverUrl, server: 1);

      if (streamUrl == null) {
        serverUrl = season == null && episode == null
            ? 'https://$baseUrl/embed/player.php?id=$tmdbId'
            : 'https://$baseUrl/embed/player.php?id=$tmdbId&s=$season&e=$episode';

        streamUrl = await findStream(serverUrl, server: 2);

        if (streamUrl == null) {
          serverUrl = season == null && episode == null
              ? 'https://tom.$baseUrl/api/getVideoSource?type=movie&id=$tmdbId'
              : 'https://tom.$baseUrl/api/getVideoSource?type=tv&id=$tmdbId/$season/$episode';

          streamUrl = await findStream(
            serverUrl,
            headers: {
              'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:101.0) Gecko/20100101 Firefox/101.0',
              'Referer': 'https://$baseUrl/',
            },
            server: 3,
          );
        }
      }

      return MediaStream(url: streamUrl);
    } catch (err) {
      print('AutoEmbed - Error fetching stream: $err');
      return MediaStream();
    }
  }

  Future<String?> findStream(String url, {Map<String, String>? headers, required int server}) async {
    try {
      final response = await http.get(Uri.parse(url), headers: headers);
      if (response.statusCode == 200) {
        if (server != 3) {
          return extractStreamFromMultiScript(response.body);
        } else {
          var data = json.decode(response.body);
          return data['videoSource'];
        }
      } else {
        print('AutoEmbed $server - Failed to fetch HTML. Status code: ${response.statusCode}');
        return null;
      }
    } catch (err) {
      print('AutoEmbed $server - Error in findStream: $err');
      return null;
    }
  }

  String? extractStreamFromMultiScript(String scriptContent) {
    RegExp regex = RegExp(r'"title":\s*"([^"]+)",\s*"file":\s*"(https:\/\/[^"]+)"');
    Iterable<RegExpMatch> matches = regex.allMatches(scriptContent);

    for (var match in matches) {
      String language = match.group(1) ?? '';
      String? url = match.group(2);

      if (language == 'English') return url;
    }

    return null;
  }
}