import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class YouTubeMp3PlayerService {
  // Key to retrieve the API key from SharedPreferences
  static const String _apiKeyPrefKey = 'rapidApiKey'; 

  // *** Default API Key (the original hardcoded one) ***
  static const String _defaultApiKey = 
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
    // --- Load API Key Dynamically with Default Fallback ---
    final prefs = await SharedPreferences.getInstance();
    // Get saved key, if null or empty, use the default key
    String? apiKey = prefs.getString(_apiKeyPrefKey);
    
    if (apiKey == null || apiKey.trim().isEmpty) {
      apiKey = _defaultApiKey; // Use default if no custom key is saved
    }
    // --- End Load API Key ---

    final videoId = _extractVideoId(videoUrlOrId);
    if (videoId == null) {
      throw Exception("URL ou ID YouTube invalide.");
    }

    final url = Uri.parse("$_baseUrl$videoId?quality=$quality");

    try {
      final response = await http.get(
        url,
        headers: {
          // Use the loaded or default API key
          'x-rapidapi-key': apiKey,
          'x-rapidapi-host': _rapidApiHost,
        },
      );

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'] ?? '';
        if (contentType.contains('audio/mpeg') ||
            contentType.contains('application/octet-stream')) {
          return response.bodyBytes;
        } else {
          if (contentType.contains('application/json')) {
             throw Exception("Erreur de l'API: ${response.body}");
          } else {
            throw Exception("Type de contenu inattendu: $contentType");
          }
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
         // Check if the default key was used and failed
         final bool usedDefaultKey = apiKey == _defaultApiKey;
         String errorMsg = "Échec du téléchargement MP3. Clé API invalide ou expirée (Code: ${response.statusCode}).";
         if (usedDefaultKey) {
            errorMsg += " La clé par défaut a peut-être expiré. Veuillez configurer votre propre clé dans les paramètres (accès caché : 4 clics rapides sur l'écran de recherche).";
         } else {
            errorMsg += " Veuillez vérifier votre clé dans les paramètres.";
         }
        throw Exception(errorMsg);
      } else {
         String errorMessage = "Échec du téléchargement MP3. Code: ${response.statusCode}";
         if ((response.headers['content-type'] ?? '').contains('application/json')) {
            errorMessage += " Détails: ${response.body}";
         }
        throw Exception(errorMessage);
      }
    } catch (e) {
      print("Erreur lors de l'appel API YouTube Downloader: $e");
      rethrow; 
    }
  }

  /// Extracts the video ID from a full URL or returns the input if it's already an ID
  static String? _extractVideoId(String urlOrId) {
    // Improved regex to handle more URL formats including youtu.be
    final idPattern = RegExp(r'(?:v=|\/|youtu\.be\/|embed\/|shorts\/)([0-9A-Za-z_-]{11})');
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

