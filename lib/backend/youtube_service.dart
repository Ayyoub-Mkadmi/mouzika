import 'dart:convert';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'youtube_http_client.dart';

/// A wrapper around youtube_explode_dart that provides **automatic retry
/// with transparent fallback** across multiple connection strategies:
///
///   1. Direct connection (no proxy — fastest, works on most mobile networks)
///   2. Proxy gateway #1
///   3. Proxy gateway #2
///
/// On each search call the service tries strategy 1 first; if it fails it
/// silently rotates through the remaining strategies before giving up.
/// The user never sees intermediate failures — only the final result or
/// a single consolidated error.
class YouTubeService {
  /// Connection strategies, ordered by preference.
  /// `null` means "direct" (no proxy).
  final List<String?> _strategies = [
    null, // direct — try first
    'https://api.codetabs.com/v1/proxy/?quest=',
    'https://thingproxy.freeboard.io/fetch/',
  ];

  /// Index of the strategy that succeeded last time (sticky preference).
  int _preferredStrategy = 0;

  /// The currently active explode instance.
  YoutubeExplode? _yt;

  YouTubeService();

  /* ------------------------------------------------------------------ */
  /*  public API                                                        */
  /* ------------------------------------------------------------------ */

  /// Search YouTube and return raw JSON.
  /// Automatically retries across all strategies before throwing.
  Future<String> searchVideos(String query) async {
    Object? lastError;

    // Try every strategy starting from the preferred one.
    for (var attempt = 0; attempt < _strategies.length; attempt++) {
      final idx = (_preferredStrategy + attempt) % _strategies.length;
      try {
        final yt = _getClient(idx);
        final results = await yt.search
            .search(query)
            .timeout(const Duration(seconds: 12));

        // Skip "live" items that have no duration
        final filtered = results.where((v) => v.duration != null).toList();

        final jsonResults = filtered
            .map((v) => {
                  'videoId': v.id.value,
                  'title': v.title,
                  'thumbnail': v.thumbnails.mediumResUrl,
                  'duration': _formatDuration(v.duration!),
                  'channelTitle': v.author,
                })
            .toList();

        // This strategy worked — remember it for next time.
        _preferredStrategy = idx;
        return jsonEncode({'results': jsonResults});
      } catch (e) {
        lastError = e;
        // Dispose the failed client so we start fresh on next attempt.
        _disposeClient();
        continue; // try next strategy
      }
    }

    throw Exception('All search strategies failed: $lastError');
  }

  /// Return the direct audio‑only stream URL (highest bitrate).
  /// Also retries across strategies.
  Future<String> getAudioStreamUrl(String videoId) async {
    Object? lastError;

    for (var attempt = 0; attempt < _strategies.length; attempt++) {
      final idx = (_preferredStrategy + attempt) % _strategies.length;
      try {
        final yt = _getClient(idx);
        final manifest = await yt.videos.streamsClient
            .getManifest(videoId)
            .timeout(const Duration(seconds: 15));
        final audio = manifest.audioOnly.withHighestBitrate();
        _preferredStrategy = idx;
        return audio.url.toString();
      } catch (e) {
        lastError = e;
        _disposeClient();
        continue;
      }
    }

    throw Exception('Could not get audio stream: $lastError');
  }

  void dispose() => _disposeClient();

  /* ------------------------------------------------------------------ */
  /*  internal helpers                                                   */
  /* ------------------------------------------------------------------ */

  /// Get or create a YoutubeExplode client for the given strategy index.
  YoutubeExplode _getClient(int strategyIndex) {
    // Always create a fresh client to ensure clean state for each strategy.
    _disposeClient();
    final gateway = _strategies[strategyIndex];
    if (gateway == null) {
      _yt = YoutubeExplode(); // direct — no proxy
    } else {
      _yt = YoutubeExplode(ProxyHttpClient(gateway));
    }
    return _yt!;
  }

  void _disposeClient() {
    try {
      _yt?.close();
    } catch (_) {}
    _yt = null;
  }

  String _formatDuration(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
      '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
}
