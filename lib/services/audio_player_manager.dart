// audio_player_manager.dart
import 'dart:io';
import 'package:just_audio/just_audio.dart';

class AudioPlayerManager {
  static final AudioPlayerManager _instance = AudioPlayerManager._internal();

  factory AudioPlayerManager() => _instance;

  final AudioPlayer _audioPlayer = AudioPlayer();
  late ConcatenatingAudioSource _playlistSource;
  List<File> _filePlaylist = [];

  AudioPlayer get audioPlayer => _audioPlayer;
  List<File> get filePlaylist => _filePlaylist;

  AudioPlayerManager._internal();

  Future<void> setPlaylist(List<File> files, {int initialIndex = 0}) async {
    _filePlaylist = files;
    _playlistSource = ConcatenatingAudioSource(
      children:
          files.map((file) => AudioSource.uri(Uri.file(file.path))).toList(),
    );
    await _audioPlayer.setAudioSource(
      _playlistSource,
      initialIndex: initialIndex,
    );
  }

  void play() => _audioPlayer.play();
  void pause() => _audioPlayer.pause();

  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}
