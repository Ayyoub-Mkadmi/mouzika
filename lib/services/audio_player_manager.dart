// File: lib/services/audio_player_manager.dart
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:mouzika/services/audio_handler.dart';

class AudioPlayerManager {
  static final AudioPlayerManager _instance = AudioPlayerManager._internal();

  factory AudioPlayerManager() => _instance;

  late final MyAudioHandler _audioHandler;
  List<File> _filePlaylist = [];

  AudioHandler get audioHandler => _audioHandler;
  List<File> get filePlaylist => _filePlaylist;

  AudioPlayerManager._internal() {
    _audioHandler = MyAudioHandler();
  }

  Future<void> setPlaylist(List<File> files, {int initialIndex = 0}) async {
    _filePlaylist = files;
    await _audioHandler.setPlaylist(files, initialIndex: initialIndex);
  }

  void play() => _audioHandler.play();
  void pause() => _audioHandler.pause();
  void next() => _audioHandler.skipToNext();
  void previous() => _audioHandler.skipToPrevious();
}
