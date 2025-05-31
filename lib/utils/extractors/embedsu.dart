import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:index/models/stream.dart';

class EmbedSu {
  final String baseUrl = "https://embed.su";
  final Map<String, String> headers = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Referer': 'https://embed.su',
    'Origin': 'https://embed.su',
  };

  Future<MediaStream> extract(Map<String, dynamic> params) async {
    int tmdbId = params['tmdbId'];
    int? season = params['season'];
    int? episode = params['episode'];

    try {
      String urlSearch;
      if (season != null && episode != null) {
        urlSearch = '$baseUrl/embed/tv/$tmdbId/$season/$episode';
      } else {
        urlSearch = '$baseUrl/embed/movie/$tmdbId';
      }

      final htmlSearch = await http.get(Uri.parse(urlSearch), headers: headers);
      final textSearch = htmlSearch.body;

      final hashEncodeMatch = RegExp(r'JSON\.parse\(atob\(\`([^\`]+)\`').firstMatch(textSearch);
      final hashEncode = hashEncodeMatch?.group(1) ?? "";

      if (hashEncode.isEmpty) return MediaStream();

      final hashDecode = jsonDecode(await stringAtob(hashEncode));
      final mEncrypt = hashDecode['hash'];
      if (mEncrypt == null) return MediaStream();

      final firstDecode = (await stringAtob(mEncrypt))
          .split('.')
          .map((item) => item.split('').reversed.join(''))
          .toList();
      final secondDecode = jsonDecode(await stringAtob(firstDecode.join('').split('').reversed.join('')));

      if (secondDecode.isEmpty) return MediaStream();

      for (var item in secondDecode) {
        if (item['name'].toString().toLowerCase() != 'viper') continue;

        final urlDirect = '$baseUrl/api/e/${item['hash']}';
        late final dataDirect;
        try {
          final response = await http.get(Uri.parse(urlDirect), headers: headers);
          if (response.statusCode == 200) {
            dataDirect = jsonDecode(response.body);
          }
        } catch (e) {
          return MediaStream();
        }

        if (dataDirect == null || dataDirect['source'] == null) continue;

        final requestDirectSize = await http.get(Uri.parse(dataDirect['source']), headers: headers);
        final parseRequest = requestDirectSize.body.split('\n');

        List<Map<String, dynamic>> directQuality = [];
        for (var item in parseRequest) {
          if (!item.contains('/proxy/')) continue;
          final sizeQualityMatch = RegExp(r'/([0-9]+)/').firstMatch(item);
          final sizeQuality = sizeQualityMatch != null ? int.parse(sizeQualityMatch.group(1)!) : 1080;

          var dURL = "$baseUrl$item".replaceAll('embed.su/api/proxy/viper/', '').replaceAll('.png', '.m3u8');
          directQuality.add({'url': dURL, 'quality': sizeQuality, 'isM3U8': true});
        }

        if (directQuality.isEmpty) continue;

        directQuality.sort((a, b) => b['quality'].compareTo(a['quality']));
        final bestQuality = directQuality.first;

        return MediaStream(
          url: bestQuality['url'],
          headers: {
            'Referer': baseUrl,
            'User-Agent': headers['User-Agent']!,
            'Accept': '*/*',
          },
        );
      }
    } catch (e) {
      return MediaStream();
    }
    return MediaStream();
  }

  Future<String> stringAtob(String input) async {
    final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';
    String str = input.replaceAll(RegExp(r'=+$'), '');
    String output = '';

    if (str.length % 4 == 1) {
      throw Exception('Atob failed: The string to be decoded is not correctly encoded.');
    }

    int bc = 0, bs = 0;
    int buffer;
    for (var i = 0; i < str.length; i++) {
      buffer = chars.indexOf(str[i]);
      if (buffer == -1) continue;
      bs = bc % 4 != 0 ? bs * 64 + buffer : buffer;
      if (bc++ % 4 == 0) continue;
      output += String.fromCharCode(255 & bs >> (-2 * bc & 6));
    }
    return output;
  }
}