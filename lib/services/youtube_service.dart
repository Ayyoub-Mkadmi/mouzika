import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:mp3_runner/services/youtube_http_client.dart';

class YouTubeService {
  late YoutubeExplode _yt;
  final List<String> _proxyUrls = [
    'https://api.codetabs.com/v1/proxy/?quest=',
    'https://thingproxy.freeboard.io/fetch/',
  ];
  int _currentProxyIndex = 0;

  YouTubeService() {
    _initClient();
  }

  void _initClient() {
    _yt = YoutubeExplode(ProxyHttpClient(_proxyUrls[_currentProxyIndex]));
  }

  Future<String> searchVideos(String query) async {
    try {
      final results = await _yt.search.search(query);
      final filteredVideos = results.where((v) => v.duration != null).toList();
      
      // Convert videos to JSON format
      final jsonResults = filteredVideos.map((video) => {
        "videoId": video.id.value,
        "title": video.title,
        "thumbnail": video.thumbnails.mediumResUrl,
        "duration": _formatDuration(video.duration!)
      }).toList();

      return jsonEncode({"results": jsonResults});
    } catch (e) {
      _currentProxyIndex = (_currentProxyIndex + 1) % _proxyUrls.length;
      _yt.close();
      _initClient();
      throw Exception('Search failed. Trying different proxy... ($e)');
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<String> getAudioStreamUrl(String videoId) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final audioStream = manifest.audioOnly.withHighestBitrate();
      return audioStream.url.toString();
    } catch (e) {
      throw Exception('Could not get audio stream: $e');
    }
  }

  void dispose() {
    _yt.close();
  }
}