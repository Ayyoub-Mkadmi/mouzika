import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart'; // Keep for MediaItem tag

class AudioPlayerManager {
  static final AudioPlayerManager _instance = AudioPlayerManager._internal();

  factory AudioPlayerManager() => _instance;

  final AudioPlayer _audioPlayer = AudioPlayer();
  // Keep track of the current source type (playlist or single)
  SourceType _currentSourceType = SourceType.none;
  ConcatenatingAudioSource? _playlistSource; // Make nullable
  List<File> _filePlaylist = [];

  AudioPlayer get audioPlayer => _audioPlayer;
  List<File> get filePlaylist => _filePlaylist;
  SourceType get currentSourceType => _currentSourceType;

  AudioPlayerManager._internal();

  // Method for setting a playlist of local files
  Future<void> setPlaylist(List<File> files, {int initialIndex = 0}) async {
    _filePlaylist = files;
    _currentSourceType = SourceType.localPlaylist;

    // Create MediaItems for each file
    final audioSources =
        files.map((file) {
          final fileName = file.path.split('/').last.replaceAll('.mp3', '');
          // Basic MediaItem - consider fetching real metadata if possible
          return AudioSource.uri(
            Uri.file(file.path),
            tag: MediaItem(
              id: file.path, // Use file path as unique ID
              album: 'Local Files',
              title: fileName,
              artist: 'Unknown Artist',
              // artUri: Uri.parse('https://example.com/default_cover.jpg'), // Placeholder art
            ),
          );
        }).toList();

    _playlistSource = ConcatenatingAudioSource(children: audioSources);

    await _audioPlayer.setAudioSource(
      _playlistSource!,
      initialIndex: initialIndex,
    );
  }

  // New method for setting a single AudioSource (e.g., for streaming)
  Future<void> setAudioSource(AudioSource source) async {
    // Clear local playlist state when setting a single source
    _filePlaylist = [];
    _playlistSource = null;
    _currentSourceType = SourceType.singleSource;

    // Set the single audio source
    // The source should already have its MediaItem tag set where it's created
    await _audioPlayer.setAudioSource(source);
  }

  void play() => _audioPlayer.play();
  void pause() => _audioPlayer.pause();

  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}

// Enum to track the type of source currently loaded
enum SourceType { none, localPlaylist, singleSource }
