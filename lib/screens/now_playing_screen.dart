import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mouzika/services/audio_player_manager.dart';
import 'package:rxdart/rxdart.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({Key? key}) : super(key: key);

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  final AudioPlayer _audioPlayer = AudioPlayerManager().audioPlayer;
  late Stream<PositionData> _positionDataStream;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _setupListeners();
  }

  Future<void> _initializePlayer() async {
    try {
      // Wait for player to be ready
      await Future.delayed(const Duration(milliseconds: 50));

      setState(() {
        _positionDataStream =
            Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
              _audioPlayer.positionStream,
              _audioPlayer.bufferedPositionStream,
              _audioPlayer.durationStream,
              (position, bufferedPosition, duration) => PositionData(
                position,
                bufferedPosition,
                duration ?? Duration.zero,
              ),
            );
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
      });
    }
  }

  void _setupListeners() {
    _audioPlayer.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        setState(() {
          _hasError = true;
        });
      },
    );
  }

  @override
  void dispose() {
    // Don't dispose the audio player here as it's managed by AudioPlayerManager
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPlaylist = AudioPlayerManager().filePlaylist;
    final currentIndex = _audioPlayer.currentIndex ?? 0;

    if (_hasError) {
      return Scaffold(
        // appBar: AppBar(title: const Text('Now Playing')),
        body: const Center(child: Text("Error playing audio")),
      );
    }

    if (!_isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (currentPlaylist.isEmpty || currentIndex >= currentPlaylist.length) {
      return Scaffold(
        // appBar: AppBar(title: const Text('Now Playing')),
        body: const Center(child: Text("No song selected")),
      );
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ✅ Wrap song info in a StreamBuilder to update on track change
            StreamBuilder<int?>(
              stream: _audioPlayer.currentIndexStream,
              builder: (context, snapshot) {
                final currentIndex =
                    snapshot.data ?? _audioPlayer.currentIndex ?? 0;
                final currentPlaylist = AudioPlayerManager().filePlaylist;

                if (currentPlaylist.isEmpty ||
                    currentIndex >= currentPlaylist.length) {
                  return const Text("No song selected");
                }

                return _buildSongInfo(currentPlaylist[currentIndex]);
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

  Widget _buildSongInfo(File currentSong) {
    final fileName = currentSong.path.split('/').last;
    // Remove file extension for cleaner display
    final songName = fileName.replaceAll(RegExp(r'\.\w+$'), '');

    return Column(
      children: [
        const Icon(Icons.music_note, size: 64, color: Colors.blue),
        const SizedBox(height: 16),
        Text(
          songName,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildPlayerControls() {
    return StreamBuilder<PlayerState>(
      stream: _audioPlayer.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final processingState =
            playerState?.processingState ?? ProcessingState.idle;
        final playing = playerState?.playing ?? false;
        final isBuffering = processingState == ProcessingState.buffering;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 42,
              icon: const Icon(Icons.skip_previous),
              onPressed:
                  _audioPlayer.hasPrevious
                      ? () => _audioPlayer.seekToPrevious()
                      : null,
            ),
            if (isBuffering)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              )
            else
              IconButton(
                iconSize: 64,
                icon: Icon(playing ? Icons.pause_circle : Icons.play_circle),
                onPressed: () {
                  if (playing) {
                    _audioPlayer.pause();
                  } else {
                    _audioPlayer.play();
                  }
                },
              ),
            IconButton(
              iconSize: 42,
              icon: const Icon(Icons.skip_next),
              onPressed:
                  _audioPlayer.hasNext ? () => _audioPlayer.seekToNext() : null,
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
          onChanged: _audioPlayer.seek,
        );
      },
    );
  }
}

// PositionData and SeekBar classes remain the same as in your original code

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
        (widget.position.inMilliseconds.toDouble().clamp(
          0,
          widget.duration.inMilliseconds.toDouble(),
        ));

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
