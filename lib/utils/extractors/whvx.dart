import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:index/models/stream.dart';

class Whvx {
  final List<Map<String, String>> servers = [
    {'provider': 'orion', 'baseUrl': 'https://api.whvx.net'},
    {'provider': 'astra', 'baseUrl': 'https://api.whvx.net'},
  ];

  Future<MediaStream> extract(Map<String, dynamic> params) async {
    int tmdbId = params['tmdbId'];
    int? season = params['season'];
    int? episode = params['episode'];
    String type = season != null && episode != null ? 'show' : 'movie';

    for (var server in servers) {
      String provider = server['provider']!;
      String baseUrl = server['baseUrl']!;

      try {
        final searchQuery = jsonEncode({
          'tmdbId': tmdbId,
          'type': type,
          if (season != null) 'season': season,
          if (episode != null) 'episode': episode,
        });

        final headers = {
          'Accept': '*/*',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36',
          'Origin': 'https://www.vidbinge.com',
        };

        final tokenRes = await http.get(Uri.parse('https://ext.8man.me/api/whvxToken')).timeout(Duration(seconds: 4));
        if (tokenRes.statusCode != 200) continue;
        final tokenJson = jsonDecode(tokenRes.body);
        String token = Uri.encodeComponent(tokenJson['token']);

        final searchUrl = Uri.parse('$baseUrl/search?query=$searchQuery&provider=$provider&token=$token');
        final searchRes = await http.get(searchUrl, headers: headers).timeout(Duration(seconds: 4));
        if (searchRes.statusCode != 200) continue;
        final searchJson = jsonDecode(searchRes.body);
        String? resourceId = searchJson['url'];
        if (resourceId == null) continue;

        final streamUrl = Uri.parse('$baseUrl/source?resourceId=${Uri.encodeComponent(resourceId)}&provider=$provider');
        final streamRes = await http.get(streamUrl, headers: headers).timeout(Duration(seconds: 4));
        final streamJson = jsonDecode(streamRes.body);

        String? streamLink = streamJson['stream']?[0]['playlist'];
        if (streamLink != null) {
          return MediaStream(
            url: streamLink,
            headers: {'Origin': 'https://www.vidbinge.com'},
          );
        }
      } catch (e) {
        print('Whvx - Error with $provider server: $e');
      }
    }

    return MediaStream();
  }
}