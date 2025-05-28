// lib/services/audio_handler.dart

import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

class MyAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  MyAudioHandler();

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

      final index = _player.currentIndex;
      if (index != null && index < queue.value.length) {
        mediaItem.add(queue.value[index]);
      }
    });

    _player.currentIndexStream.listen((index) {
      if (index != null && index < queue.value.length) {
        mediaItem.add(queue.value[index]);
      }
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

  AudioPlayer get audioPlayer => _player;
}

Future<AudioHandler> initAudioHandler() async {
  final handler = MyAudioHandler();
  await handler.init();
  return await AudioService.init(
    builder: () => handler,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.mouzika.channel.audio',
      androidNotificationChannelName: 'Mouzika Audio Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
}
