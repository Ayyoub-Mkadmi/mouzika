import 'dart:convert';
import 'package:mouzika/backend/youtube_service.dart';

import '../models/video_result.dart';

class ApiService {
  static final YouTubeService _ytService = YouTubeService();

  static Future<List<VideoResult>> searchVideos(String query) async {
    try {
      final jsonString = await _ytService.searchVideos(query);
      final data = jsonDecode(jsonString);
      final List results = data['results'];
      return results.map((e) => VideoResult.fromJson(e)).toList();
    } catch (e) {
      throw Exception('Failed to fetch search results: $e');
    }
  }
}
