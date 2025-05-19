import 'dart:typed_data';
import 'package:http/http.dart' as http;

class YouTubeMp3PlayerService {
  static const String _rapidApiKey =
      '30f0a8d6e4msh13d82afdd7da410p195c0ejsn41d7f2805fb1';
  static const String _rapidApiHost =
      'youtube-mp3-audio-video-downloader.p.rapidapi.com';
  static const String _baseUrl =
      'https://youtube-mp3-audio-video-downloader.p.rapidapi.com/download-mp3/';

  /// Accepts a full YouTube URL or video ID and returns the MP3 as Uint8List
  static Future<Uint8List> convertVideoToMp3(
    String videoUrlOrId, {
    String quality = 'low',
  }) async {
    final videoId = _extractVideoId(videoUrlOrId);
    if (videoId == null) {
      throw Exception("Invalid YouTube URL or ID.");
    }

    final url = Uri.parse("$_baseUrl$videoId?quality=$quality");

    final response = await http.get(
      url,
      headers: {
        'x-rapidapi-key': _rapidApiKey,
        'x-rapidapi-host': _rapidApiHost,
      },
    );

    if (response.statusCode == 200) {
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('audio/mpeg') ||
          contentType.contains('application/octet-stream')) {
        return response.bodyBytes;
      } else {
        throw Exception("Unexpected content type: $contentType");
      }
    } else {
      throw Exception(
        "Failed to download MP3. Status code: ${response.statusCode}",
      );
    }
  }

  /// Extracts the video ID from a full URL or returns the input if it's already an ID
  static String? _extractVideoId(String urlOrId) {
    final idPattern = RegExp(r'(?:v=|\/)([0-9A-Za-z_-]{11})');
    final match = idPattern.firstMatch(urlOrId);

    if (match != null) {
      return match.group(1);
    } else if (urlOrId.length == 11 &&
        RegExp(r'^[\w-]{11}$').hasMatch(urlOrId)) {
      return urlOrId; // already a valid video ID
    } else {
      return null;
    }
  }
}
