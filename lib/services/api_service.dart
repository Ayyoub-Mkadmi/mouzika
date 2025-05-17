import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/video_result.dart';

class ApiService {
  static Future<List<VideoResult>> searchVideos(String query) async {
    final uri = Uri.parse('http://<YOUR_BACKEND_IP>:8000/search?q=$query');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('API error');
    }

    final List data = json.decode(response.body)['results'];
    return data.map((e) => VideoResult.fromJson(e)).toList();
  }
}
