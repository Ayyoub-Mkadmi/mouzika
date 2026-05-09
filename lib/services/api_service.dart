import 'dart:convert';
import 'package:mouzika/backend/youtube_service.dart';

import '../models/video_result.dart';

class ApiService {
  static YouTubeService _ytService = YouTubeService();

  /// Consecutive failure count — if too many, recreate the service to clear
  /// any stale internal state.
  static int _consecutiveFailures = 0;

  static Future<List<VideoResult>> searchVideos(String query) async {
    // Recreate service if we've had too many consecutive failures
    if (_consecutiveFailures >= 3) {
      _ytService.dispose();
      _ytService = YouTubeService();
      _consecutiveFailures = 0;
    }

    try {
      final jsonString = await _ytService.searchVideos(query);
      final data = jsonDecode(jsonString);
      final List results = data['results'];
      _consecutiveFailures = 0; // reset on success
      return results.map((e) => VideoResult.fromJson(e)).toList();
    } catch (e) {
      _consecutiveFailures++;
      throw Exception('Failed to fetch search results: $e');
    }
  }
}
