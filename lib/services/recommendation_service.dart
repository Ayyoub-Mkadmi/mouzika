import 'dart:convert';
import 'dart:math';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/track.dart';
import '../models/video_result.dart';
import 'api_service.dart';

/// A local recommendation engine that analyses the user's downloaded songs,
/// search history, and recently played tracks to suggest similar music.
///
/// **How it works:**
/// 1. Collects signal data from downloaded tracks + search history
/// 2. Extracts keywords (artist names, meaningful words) from titles
/// 3. Generates YouTube search queries from those keywords
/// 4. Deduplicates against already-downloaded songs
/// 5. Caches results for 1 hour to avoid redundant API calls
class RecommendationService {
  static final RecommendationService _instance =
      RecommendationService._internal();
  factory RecommendationService() => _instance;
  RecommendationService._internal();

  /// Cache key for SharedPreferences
  static const String _cacheKey = 'recommendation_cache';
  static const String _cacheTimeKey = 'recommendation_cache_time';
  static const String _searchHistoryKey = 'search_history';

  /// Cache TTL — 1 hour
  static const Duration _cacheTTL = Duration(hours: 1);

  /// Words to strip from titles (noise words)
  static final RegExp _noisePattern = RegExp(
    r'\b(official|video|music|lyrics|lyric|audio|hd|hq|4k|1080p|720p|remix|'
    r'feat|ft|featuring|prod|produced|by|the|and|with|from|full|version|'
    r'visualizer|clip|officiel|explicit|clean|live|performance|session|'
    r'acoustic|cover|karaoke|instrumental|extended|original|mix|edit|'
    r'remaster|remastered|deluxe|bonus|track|song|new|latest|best|top|'
    r'mv|m\/v|teaser|trailer|preview)\b',
    caseSensitive: false,
  );

  /// Patterns to split "Artist - Title" style titles
  static final RegExp _separatorPattern = RegExp(r'\s*[-–—|:]\s*');

  /// Characters to strip
  static final RegExp _specialChars = RegExp(r'[^\w\s]');

  /* ------------------------------------------------------------------ */
  /*  Public API                                                        */
  /* ------------------------------------------------------------------ */

  /// Record a search query for future recommendations.
  Future<void> recordSearch(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_searchHistoryKey) ?? [];

    // Avoid duplicates, keep most recent first, cap at 30
    history.remove(query.trim());
    history.insert(0, query.trim());
    if (history.length > 30) history.removeLast();

    await prefs.setStringList(_searchHistoryKey, history);
  }

  /// Get recommendations. Returns cached results if fresh enough,
  /// otherwise fetches new ones transparently.
  Future<List<VideoResult>> getRecommendations({bool forceRefresh = false}) async {
    // Check cache first
    if (!forceRefresh) {
      final cached = await _getCachedRecommendations();
      if (cached != null) return cached;
    }

    // Generate fresh recommendations
    final recommendations = await _generateRecommendations();

    // Cache results
    await _cacheRecommendations(recommendations);

    return recommendations;
  }

  /// Clear the recommendation cache (useful after downloading new songs).
  Future<void> invalidateCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove(_cacheTimeKey);
  }

  /* ------------------------------------------------------------------ */
  /*  Core recommendation logic                                         */
  /* ------------------------------------------------------------------ */

  Future<List<VideoResult>> _generateRecommendations() async {
    final queries = await _buildSearchQueries();
    if (queries.isEmpty) return [];

    final List<VideoResult> allResults = [];
    final Set<String> seenIds = {};

    // Get IDs of already-downloaded tracks to exclude
    final downloadedIds = _getDownloadedVideoIds();

    // Fetch results for each query (limit to 3 queries to avoid spam)
    final selectedQueries = queries.take(3).toList();

    for (final query in selectedQueries) {
      try {
        final results = await ApiService.searchVideos(query);
        for (final result in results) {
          // Deduplicate and exclude already-downloaded
          if (!seenIds.contains(result.videoId) &&
              !downloadedIds.contains(result.videoId)) {
            seenIds.add(result.videoId);
            allResults.add(result);
          }
        }
      } catch (_) {
        // Silently skip failed queries — we may still have results from others
        continue;
      }
    }

    // Shuffle and limit to 15 recommendations
    allResults.shuffle(Random());
    return allResults.take(15).toList();
  }

  /// Build search queries from user's music profile.
  Future<List<String>> _buildSearchQueries() async {
    final artists = <String, int>{};
    final keywords = <String, int>{};
    final queries = <String>[];

    // Source 1: Downloaded tracks (strongest signal)
    final trackBox = Hive.isBoxOpen('tracks')
        ? Hive.box<Track>('tracks')
        : null;

    if (trackBox != null) {
      for (final track in trackBox.values) {
        _analyzeTitle(track.title, artists, keywords, weight: 2);
      }
    }

    // Source 2: Search history (secondary signal)
    final prefs = await SharedPreferences.getInstance();
    final searchHistory = prefs.getStringList(_searchHistoryKey) ?? [];
    for (final query in searchHistory.take(10)) {
      _analyzeTitle(query, artists, keywords, weight: 1);
    }

    // Source 3: Recently played
    if (Hive.isBoxOpen('recently_played')) {
      final recentBox = Hive.box<String>('recently_played');
      final recentIds = recentBox.values.toSet();
      if (trackBox != null) {
        for (final track in trackBox.values) {
          if (recentIds.contains(track.videoId)) {
            _analyzeTitle(track.title, artists, keywords, weight: 3);
          }
        }
      }
    }

    // Build queries from top artists
    final sortedArtists = artists.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sortedArtists.take(2)) {
      queries.add('${entry.key} songs');
    }

    // Build queries from top keywords
    final sortedKeywords = keywords.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final entry in sortedKeywords.take(2)) {
      queries.add('${entry.key} music');
    }

    // If we have downloaded tracks, add a "similar to" query
    if (trackBox != null && trackBox.isNotEmpty) {
      final randomTrack = trackBox.values.elementAt(
        Random().nextInt(trackBox.length),
      );
      final cleanTitle = _cleanTitle(randomTrack.title);
      if (cleanTitle.isNotEmpty) {
        queries.add('songs like $cleanTitle');
      }
    }

    // Fallback: if no data, suggest trending
    if (queries.isEmpty) {
      queries.addAll([
        'trending music 2026',
        'top hits this week',
        'popular songs new',
      ]);
    }

    // Shuffle to vary results each time
    queries.shuffle(Random());
    return queries;
  }

  /// Parse a title to extract artist names and meaningful keywords.
  void _analyzeTitle(
    String title,
    Map<String, int> artists,
    Map<String, int> keywords, {
    int weight = 1,
  }) {
    // Try to extract artist from "Artist - Title" pattern
    final parts = title.split(_separatorPattern);
    if (parts.length >= 2) {
      final artist = parts[0].trim();
      if (artist.isNotEmpty && artist.length > 1 && artist.length < 40) {
        artists[artist] = (artists[artist] ?? 0) + weight;
      }
    }

    // Extract meaningful keywords
    final cleaned = title
        .replaceAll(_noisePattern, '')
        .replaceAll(_specialChars, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    for (final word in cleaned.split(' ')) {
      if (word.length > 2 && !_isStopWord(word)) {
        keywords[word.toLowerCase()] =
            (keywords[word.toLowerCase()] ?? 0) + weight;
      }
    }
  }

  String _cleanTitle(String title) {
    return title
        .replaceAll(_noisePattern, '')
        .replaceAll(_specialChars, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Set<String> _getDownloadedVideoIds() {
    try {
      final trackBox = Hive.box<Track>('tracks');
      return trackBox.values.map((t) => t.videoId).toSet();
    } catch (_) {
      return {};
    }
  }

  bool _isStopWord(String word) {
    const stopWords = {
      'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been',
      'being', 'have', 'has', 'had', 'do', 'does', 'did', 'will',
      'would', 'could', 'should', 'may', 'might', 'can', 'shall',
      'of', 'in', 'to', 'for', 'on', 'at', 'by', 'from', 'up',
      'out', 'if', 'or', 'and', 'but', 'not', 'no', 'so', 'too',
      'very', 'just', 'about', 'into', 'over', 'after', 'with',
      'its', 'it', 'my', 'me', 'you', 'your', 'we', 'our', 'us',
      'he', 'she', 'his', 'her', 'they', 'them', 'their', 'this',
      'that', 'these', 'those', 'all', 'each', 'every', 'both',
    };
    return stopWords.contains(word.toLowerCase());
  }

  /* ------------------------------------------------------------------ */
  /*  Caching                                                           */
  /* ------------------------------------------------------------------ */

  Future<List<VideoResult>?> _getCachedRecommendations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheTimeStr = prefs.getString(_cacheTimeKey);
      if (cacheTimeStr == null) return null;

      final cacheTime = DateTime.parse(cacheTimeStr);
      if (DateTime.now().difference(cacheTime) > _cacheTTL) return null;

      final cacheJson = prefs.getString(_cacheKey);
      if (cacheJson == null) return null;

      final List decoded = jsonDecode(cacheJson);
      return decoded.map((e) => VideoResult.fromJson(e)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheRecommendations(List<VideoResult> results) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(results.map((r) => r.toJson()).toList());
      await prefs.setString(_cacheKey, json);
      await prefs.setString(_cacheTimeKey, DateTime.now().toIso8601String());
    } catch (_) {
      // Caching failure is non-critical
    }
  }
}
