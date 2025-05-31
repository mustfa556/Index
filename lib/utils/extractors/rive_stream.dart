import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:index/models/stream.dart';

class RiveStream {
  String baseUrl = 'https://rivestream.live';

  Future<MediaStream> extract(Map<String, dynamic> params) async {
    try {
      String? link = await getRiveStream(
        params['tmdbId'],
        params['season'],
        params['episode'],
      );
      return MediaStream(url: link);
    } catch (e) {
      print('Rive - Extraction error: $e');
      return MediaStream();
    }
  }

  Future<String?> getRiveStream(int tmdbId, int? season, int? episode) async {
    final secret = generateSecretKey(tmdbId);
    final servers = [
      'hydrax',
      'fastx',
      'filmecho',
      'nova',
      'vidcloud',
      'ee3',
      'showbox',
    ];
    final route = season != null && episode != null
        ? '/api/backendfetch?requestID=tvVideoProvider&id=$tmdbId&season=$season&episode=$episode&secretKey=$secret&service='
        : '/api/backendfetch?requestID=movieVideoProvider&id=$tmdbId&secretKey=$secret&service=';
    final url = Uri.encodeFull(baseUrl + route);

    for (final server in servers) {
      try {
        final res = await http.get(Uri.parse(url + server));

        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (data['data'] != null && data['data']['sources'] != null) {
            final source = data['data']['sources'][0];
            final link = source['url'];
            return link;
          }
        }
      } catch (e) {
        print('Rive - Error fetching from server $server: $e');
      }
    }
    return null;
  }

  String generateSecretKey(int id) {
    final secretChars = [
      'N', '1y', 'R', 'efH', 'bR', 'CY', 'HF', 'JL', '5', 'A', 'mh', '4', 'F7g', 'GzH',
      '7cb', 'gfg', 'f', 'Q', '8', 'c', 'YP', 'I', 'KL', 'CzW', 'YTL', '4', 'u', '3',
      'Vlg', '9q', 'NzG', '9CK', 'AbS', 'jUG', 'Fd', 'c3S', 'VWx', 'wp', 'bgx', 'V',
      'o1H', 'Pa', 'yk', 'a', 'KJ', 'VnV', 'O', 'm', 'ihF', 'x',
    ];
    return secretChars[id % secretChars.length];
  }
}