// File: lib/services/audio_handler.dart

import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  MyAudioHandler();

  /// Explicit async initializer to be awaited after construction.
  Future<void> init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    _player.playbackEventStream.listen((event) {
      final playing = _player.playing;
      playbackState.add(
        playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            if (playing) MediaControl.pause else MediaControl.play,
            MediaControl.skipToNext,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
          },
          androidCompactActionIndices: const [0, 1, 2],
          processingState:
              const {
                ProcessingState.idle: AudioProcessingState.idle,
                ProcessingState.loading: AudioProcessingState.loading,
                ProcessingState.buffering: AudioProcessingState.buffering,
                ProcessingState.ready: AudioProcessingState.ready,
                ProcessingState.completed: AudioProcessingState.completed,
              }[_player.processingState]!,
          playing: playing,
          updatePosition: _player.position,
          bufferedPosition: _player.bufferedPosition,
          speed: _player.speed,
          queueIndex: _player.currentIndex,
        ),
      );
    });
  }

  Future<void> setPlaylist(List<File> files, {int initialIndex = 0}) async {
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

    queue.add(mediaItems);

    final source = ConcatenatingAudioSource(
      children:
          files.map((file) => AudioSource.uri(Uri.file(file.path))).toList(),
    );

    await _player.setAudioSource(source, initialIndex: initialIndex);
    mediaItem.add(mediaItems[initialIndex]);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> addQueueItem(MediaItem item) async {
    // Optional: implement to support dynamic queue
  }

  AudioPlayer get audioPlayer => _player;
}

Future<AudioHandler> initAudioHandler() async {
  print('Starting initAudioHandler...');
  final handler = MyAudioHandler();
  print('Created MyAudioHandler instance');
  await handler.init();
  print('Completed MyAudioHandler.init()');

  final audioHandlerInstance = await AudioService.init(
    builder: () => handler,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.mouzika.channel.audio',
      androidNotificationChannelName: 'Mouzika Audio Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );

  print('AudioService.init completed');
  return audioHandlerInstance;
}
