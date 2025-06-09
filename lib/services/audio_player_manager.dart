import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart'; // Keep for MediaItem tag
import 'package:hive/hive.dart'; // Import Hive for Track lookup
import '../models/track.dart'; // Import Track model

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

    // Ensure the tracks box is open
    final trackBox = Hive.isBoxOpen('tracks') 
        ? Hive.box<Track>('tracks') 
        : await Hive.openBox<Track>('tracks');

    // Create MediaItems for each file
    final audioSources = files.map((file) {
      final fileName = file.path.split('/').last.replaceAll('.mp3', '');
      
      // Look up the track in Hive to get the thumbnail path
      Track? track;
      try {
        // Find the track with matching mp3Path - don't use orElse with null
        for (var t in trackBox.values) {
          if (t.mp3Path == file.path) {
            track = t;
            break;
          }
        }
      } catch (_) {
        // Handle any potential errors in lookup
      }

      // Create MediaItem with artwork if available
      return AudioSource.uri(
        Uri.file(file.path),
        tag: MediaItem(
          id: file.path, // Use file path as unique ID
          album: 'Local Files',
          title: fileName,
          artist: 'Unknown Artist',
          // Set artUri if we have a valid thumbnail path
          artUri: track != null && track.thumbPath.isNotEmpty && File(track.thumbPath).existsSync()
              ? Uri.file(track.thumbPath)
              : null,
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
