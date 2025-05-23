import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:mouzika/services/audio_player_manager.dart';
import 'package:rxdart/rxdart.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({Key? key}) : super(key: key);

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  final audioHandler = AudioPlayerManager().audioHandler;
  late Stream<PositionData> _positionDataStream;

  @override
  void initState() {
    super.initState();
    _positionDataStream =
        Rx.combineLatest3<Duration, Duration, MediaItem?, PositionData>(
          audioHandler.playbackState.map((s) => s.position),
          audioHandler.playbackState.map((s) => s.bufferedPosition),
          audioHandler.mediaItem,
          (position, bufferedPosition, mediaItem) => PositionData(
            position,
            bufferedPosition,
            mediaItem?.duration ?? Duration.zero,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final currentPlaylist = AudioPlayerManager().filePlaylist;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            StreamBuilder<MediaItem?>(
              stream: audioHandler.mediaItem,
              builder: (context, snapshot) {
                final mediaItem = snapshot.data;
                if (mediaItem == null) return const Text("No song selected");
                return _buildSongInfo(mediaItem);
              },
            ),
            const SizedBox(height: 40),
            _buildPlayerControls(),
            const SizedBox(height: 24),
            _buildSeekBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSongInfo(MediaItem mediaItem) {
    return Column(
      children: [
        const Icon(Icons.music_note, size: 64, color: Colors.blue),
        const SizedBox(height: 16),
        Text(
          mediaItem.title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildPlayerControls() {
    return StreamBuilder<PlaybackState>(
      stream: audioHandler.playbackState,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final playing = state?.playing ?? false;
        final processingState =
            state?.processingState ?? AudioProcessingState.idle;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 42,
              icon: const Icon(Icons.skip_previous),
              onPressed: audioHandler.skipToPrevious,
            ),
            if (processingState == AudioProcessingState.buffering ||
                processingState == AudioProcessingState.loading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              )
            else
              IconButton(
                iconSize: 64,
                icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
                onPressed: playing ? audioHandler.pause : audioHandler.play,
              ),
            IconButton(
              iconSize: 42,
              icon: const Icon(Icons.skip_next),
              onPressed: audioHandler.skipToNext,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSeekBar() {
    return StreamBuilder<PositionData>(
      stream: _positionDataStream,
      builder: (context, snapshot) {
        final positionData =
            snapshot.data ??
            PositionData(Duration.zero, Duration.zero, Duration.zero);

        return SeekBar(
          duration: positionData.duration,
          position: positionData.position,
          bufferedPosition: positionData.bufferedPosition,
          onChanged: audioHandler.seek,
        );
      },
    );
  }
}

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;

  PositionData(this.position, this.bufferedPosition, this.duration);
}

class SeekBar extends StatefulWidget {
  final Duration duration;
  final Duration position;
  final Duration bufferedPosition;
  final ValueChanged<Duration>? onChanged;

  const SeekBar({
    Key? key,
    required this.duration,
    required this.position,
    required this.bufferedPosition,
    this.onChanged,
  }) : super(key: key);

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final sliderValue =
        _dragValue ??
        widget.position.inMilliseconds.toDouble().clamp(
          0,
          widget.duration.inMilliseconds.toDouble(),
        );

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: Theme.of(context).primaryColor,
            inactiveTrackColor: Colors.grey[300],
            thumbColor: Theme.of(context).primaryColor,
            overlayColor: Theme.of(context).primaryColor.withAlpha(32),
          ),
          child: Slider(
            min: 0,
            max: widget.duration.inMilliseconds.toDouble(),
            value: sliderValue,
            onChanged: (value) {
              setState(() {
                _dragValue = value;
              });
              widget.onChanged?.call(Duration(milliseconds: value.round()));
            },
            onChangeEnd: (_) => _dragValue = null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(widget.position)),
              Text(_formatDuration(widget.duration)),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return hours > 0
        ? '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}'
        : '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }
}
