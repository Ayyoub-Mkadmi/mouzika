import 'dart:io';
import 'package:flutter/material.dart';

class MusicPlayerProvider with ChangeNotifier {
  List<File> _playlist = [];
  int _currentIndex = 0;

  List<File> get playlist => _playlist;
  int get currentIndex => _currentIndex;

  void setPlaylist(List<File> playlist, {int startIndex = 0}) {
    _playlist = playlist;
    _currentIndex = startIndex;
    notifyListeners();
  }

  void setCurrentIndex(int index) {
    if (index >= 0 && index < _playlist.length) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  File? get currentSong =>
      _playlist.isNotEmpty ? _playlist[_currentIndex] : null;
}
