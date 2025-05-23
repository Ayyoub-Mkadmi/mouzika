import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:mouzika/services/audio_handler.dart'; // adjust import path as needed

class MusicPlayerProvider with ChangeNotifier {
  final AudioHandler _audioHandler;
  List<MediaItem> _playlist = [];
  int _currentIndex = 0;

  MusicPlayerProvider(this._audioHandler);

  List<MediaItem> get playlist => _playlist;
  int get currentIndex => _currentIndex;

  MediaItem? get currentSong =>
      _playlist.isNotEmpty && _currentIndex < _playlist.length
          ? _playlist[_currentIndex]
          : null;

  Future<void> setPlaylist(List<File> files, {int startIndex = 0}) async {
    // Create MediaItems from files
    final mediaItems =
        files.map((file) {
          final title = file.path
              .split(Platform.pathSeparator)
              .last
              .replaceAll(RegExp(r'\..+$'), '');
          return MediaItem(
            id: file.path,
            title: title,
            album: "Mouzika",
            extras: {'filePath': file.path},
          );
        }).toList();

    _playlist = mediaItems;
    _currentIndex = startIndex;

    // Update audio handler queue and audio source
    await (_audioHandler as MyAudioHandler).setPlaylist(
      files,
      initialIndex: startIndex,
    );

    notifyListeners();
  }

  Future<void> setCurrentIndex(int index) async {
    if (index >= 0 && index < _playlist.length) {
      _currentIndex = index;
      await _audioHandler.skipToQueueItem(index);
      notifyListeners();
    }
  }

  Future<void> play() async {
    await _audioHandler.play();
  }

  Future<void> pause() async {
    await _audioHandler.pause();
  }

  Future<void> stop() async {
    await _audioHandler.stop();
  }

  Future<void> seek(Duration position) async {
    await _audioHandler.seek(position);
  }
}
