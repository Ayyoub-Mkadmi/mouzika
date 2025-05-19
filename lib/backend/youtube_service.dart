import 'dart:convert';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'youtube_http_client.dart';

/// A small helper that wraps youtube_explode_dart and fetches data
/// through a public‑proxy gateway so it also works on mobile networks
/// that block direct YouTube calls.
///
/// Fixes in this version
/// ---------------------
/// • Queries that contain **spaces** or **non‑ASCII text** are now
///   encoded correctly by the ProxyHttpClient (see proxy_http_client.dart).
/// • Arabic / multibyte titles are preserved because we always
///   decode HTTP bodies with UTF‑8.
///
class YouTubeService {
  late YoutubeExplode _yt;

  final List<String> _proxyGateways = [
    // These gateways expect the *fully* URL‑encoded target URL
    // appended to the end of the path.
    'https://api.codetabs.com/v1/proxy/?quest=',
    'https://thingproxy.freeboard.io/fetch/',
  ];

  int _currentProxy = 0;

  YouTubeService() {
    _initClient();
  }

  /* ------------------------------------------------------------------ */
  /*  public API                                                        */
  /* ------------------------------------------------------------------ */

  /// Search YouTube and return raw JSON (handy for quick testing).
  Future<String> searchVideos(String query) async {
    try {
      final results = await _yt.search.search(query);

      // Skip “live” items that have no duration
      final filtered = results.where((v) => v.duration != null).toList();

      final jsonResults = filtered
          .map((v) => {
                'videoId': v.id.value,
                'title'   : v.title,
                'thumbnail': v.thumbnails.mediumResUrl,
                'duration': _formatDuration(v.duration!)
              })
          .toList();

      return jsonEncode({'results': jsonResults});
    } catch (e) {
      // rotate to the next proxy and retry once
      _switchProxy();
      rethrow;
    }
  }

  /// Return the direct audio‑only stream URL (highest bitrate).
  Future<String> getAudioStreamUrl(String videoId) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final audio    = manifest.audioOnly.withHighestBitrate();
      return audio.url.toString();
    } catch (e) {
      throw Exception('Could not get audio stream: $e');
    }
  }

  void dispose() => _yt.close();

  /* ------------------------------------------------------------------ */
  /*  internal helpers                                                  */
  /* ------------------------------------------------------------------ */

  void _initClient() =>
      _yt = YoutubeExplode(ProxyHttpClient(_proxyGateways[_currentProxy]));

  void _switchProxy() {
    _currentProxy = (_currentProxy + 1) % _proxyGateways.length;
    _yt.close();
    _initClient();
  }

  String _formatDuration(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
      '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
}
