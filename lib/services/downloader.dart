import 'dart:io';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../backend/youtube_downloader.dart';
import '../models/video_result.dart';
import '../models/track.dart';

class Downloader {
  static Future<bool> downloadAndStore(VideoResult v) async {
    try {
      // ---------- network ----------
      final mp3 = YouTubeMp3PlayerService.convertVideoToMp3(v.videoId);
      final jpg = http.readBytes(Uri.parse(v.thumbnailUrl));
      final results = await Future.wait<Uint8List>([mp3, jpg]);
      final mp3Bytes = results[0], thumbBytes = results[1];

      // ---------- file-system ----------
      final docs  = await getApplicationDocumentsDirectory();
      final mp3Dir   = Directory('${docs.path}/mp3s');
      final imgDir   = Directory('${docs.path}/thumbnails');
      if (!await mp3Dir.exists())  await mp3Dir.create(recursive: true);
      if (!await imgDir.exists())  await imgDir.create(recursive: true);

      final safe     = v.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final mp3Path  = '${mp3Dir.path}/$safe.mp3';
      final imgPath  = '${imgDir.path}/$safe.jpg';
      await File(mp3Path).writeAsBytes(mp3Bytes);
      await File(imgPath).writeAsBytes(thumbBytes);

      // ---------- metadata ----------
      final box = Hive.box<Track>('tracks');
      box.put(
        v.videoId,
        Track(
          videoId  : v.videoId,
          title    : v.title,
          mp3Path  : mp3Path,
          thumbPath: imgPath,
          duration : v.duration,
        ),
      );
      return true;
    } catch (e) {
      // ignore duplicates or IO errors alike
      return false;
    }
  }
}
