import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:index/models/stream.dart';

class MoviesApi {
  final String baseUrl = 'https://moviesapi.club';

  Future<MediaStream?> extract(Map<String, dynamic> params) async {
    try {
      return await getStream(
        params['tmdbId'],
        params['season'],
        params['episode'],
      );
    } catch (e) {
      print('MoviesApi - Extraction error: $e');
      return null;
    }
  }

  Future<MediaStream> getStream(int tmdbId, int? season, int? episode) async {
    try {
      final link = season != null && episode != null
          ? '$baseUrl/tv/$tmdbId-$season-$episode'
          : '$baseUrl/movie/$tmdbId';

      final res = await http.get(
        Uri.parse(link),
        headers: {'referer': baseUrl},
      );
      final baseData = res.body;

      final document = html.parse(baseData);
      final embeddedUrl = document.querySelector('iframe')?.attributes['src'];

      if (embeddedUrl != null && embeddedUrl.isNotEmpty) {
        final dataResponse = await http.get(
          Uri.parse(embeddedUrl),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:101.0) Gecko/20100101 Firefox/101.0',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
            'Alt-Used': 'w1.moviesapi.club',
            'Upgrade-Insecure-Requests': '1',
            'Sec-Fetch-Dest': 'document',
            'Sec-Fetch-Mode': 'navigate',
            'Sec-Fetch-Site': 'none',
            'Sec-Fetch-User': '?1',
            'Pragma': 'no-cache',
            'Cache-Control': 'no-cache',
            'Referer': baseUrl,
          },
        );

        final data2 = dataResponse.body;
        final encryptedContentMatch = RegExp(r'''const\s+Encrypted\s*=\s*["'](\{.*?\})["']''').firstMatch(data2);
        final encryptedContent = encryptedContentMatch != null ? encryptedContentMatch.group(1) : '';

        if (encryptedContent != null && encryptedContent.isNotEmpty) {
          final decryptedResponse = await http.post(
            Uri.parse('https://ext.8man.me/api/decrypt?passphrase==JV[t}{trEV=Ilh5'),
            body: encryptedContent,
          );

          final finalData = json.decode(decryptedResponse.body);
          final videoUrl = finalData['videoUrl'];

          if (videoUrl != null && videoUrl.isNotEmpty) {
            return MediaStream(
              url: videoUrl,
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:101.0) Gecko/20100101 Firefox/101.0',
                'Referer': baseUrl,
                'Origin': baseUrl,
                'Accept': '*/*',
                'Accept-Language': 'en-US,en;q=0.5',
                'Sec-Fetch-Dest': 'empty',
                'Sec-Fetch-Mode': 'cors',
                'Sec-Fetch-Site': 'cross-site',
                'Pragma': 'no-cache',
                'Cache-Control': 'no-cache',
              },
            );
          }
        }
      }
    } catch (e) {
      print('MoviesApi - Error fetching stream: $e');
    }
    return MediaStream();
  }
}