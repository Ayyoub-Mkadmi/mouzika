import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mouzika/services/audio_player_manager.dart';
import 'package:rxdart/rxdart.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/track.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({Key? key}) : super(key: key);

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayerManager().audioPlayer;
  late Stream<PositionData> _positionDataStream;
  bool _isInitialized = false;
  bool _hasError = false;
  late Box<Track> trackBox;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  @override
  void initState() {
    super.initState();
    trackBox = Hive.box<Track>('tracks');
    _initializePlayer();
    _setupListeners();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );
    
    _animationController.forward();
  }

  Future<void> _initializePlayer() async {
    try {
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
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentPlaylist = AudioPlayerManager().filePlaylist;
    final currentIndex = _audioPlayer.currentIndex ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_hasError) {
      return _buildErrorState(isDark);
    }

    if (!_isInitialized) {
      return _buildLoadingState(isDark);
    }

    if (currentPlaylist.isEmpty || currentIndex >= currentPlaylist.length) {
      return _buildEmptyState(isDark);
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [Colors.grey[900]!, Colors.grey[850]!, Colors.black]
                : [Colors.grey[100]!, Colors.grey[50]!, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildHeader(isDark),
                  const SizedBox(height: 32),
                  StreamBuilder<int?>(
                    stream: _audioPlayer.currentIndexStream,
                    builder: (context, snapshot) {
                      final currentIndex = snapshot.data ?? _audioPlayer.currentIndex ?? 0;
                      final currentPlaylist = AudioPlayerManager().filePlaylist;

                      if (currentPlaylist.isEmpty || currentIndex >= currentPlaylist.length) {
                        return Text(
                          "No song selected",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        );
                      }

                      return _buildSongInfo(currentPlaylist[currentIndex], isDark);
                    },
                  ),
                  const SizedBox(height: 32),
                  _buildPlayerControls(isDark),
                  const SizedBox(height: 24),
                  _buildSeekBar(isDark),
                  const SizedBox(height: 16),
                  _buildVolumeControl(isDark),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Now Playing",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        IconButton(
          icon: Icon(
            Icons.playlist_play,
            color: isDark ? Colors.white70 : Colors.black54,
            size: 28,
          ),
          onPressed: () {
            // Show playlist
            _showCurrentPlaylist(isDark);
          },
        ),
      ],
    );
  }

  void _showCurrentPlaylist(bool isDark) {
    final currentPlaylist = AudioPlayerManager().filePlaylist;
    final currentIndex = _audioPlayer.currentIndex ?? 0;
    
    if (currentPlaylist.isEmpty) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[850] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Current Playlist',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: currentPlaylist.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final file = currentPlaylist[index];
                  final fileName = file.path.split('/').last;
                  final songName = fileName.replaceAll(RegExp(r'\.\w+$'), '').replaceAll('_', ' ');
                  
                  final isPlaying = index == currentIndex;
                  
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isPlaying
                            ? [Theme.of(context).primaryColor.withOpacity(0.7), Theme.of(context).primaryColor]
                            : [isDark ? Colors.grey[700]! : Colors.grey[300]!, isDark ? Colors.grey[600]! : Colors.grey[400]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isPlaying ? Icons.play_arrow : Icons.music_note,
                        color: isPlaying ? Colors.white : isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    title: Text(
                      songName,
                      style: GoogleFonts.poppins(
                        fontWeight: isPlaying ? FontWeight.w600 : FontWeight.w400,
                        color: isPlaying 
                          ? Theme.of(context).primaryColor 
                          : isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      _audioPlayer.seek(Duration.zero, index: index);
                      if (!_audioPlayer.playing) {
                        _audioPlayer.play();
                      }
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSongInfo(File currentSong, bool isDark) {
    final fileName = currentSong.path.split('/').last;
    final songName = fileName.replaceAll(RegExp(r'\.\w+$'), '').replaceAll('_', ' ');

    final track = trackBox.values.firstWhere(
      (t) => t.mp3Path == currentSong.path,
      orElse: () => Track(
        videoId: '',
        title: songName,
        mp3Path: currentSong.path,
        thumbPath: '',
        duration: '',
      ),
    );

    final thumbFile = File(track.thumbPath);
    final hasThumb = track.thumbPath.isNotEmpty && thumbFile.existsSync();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Column(
          children: [
            Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: isDark 
                      ? Colors.black.withOpacity(0.4)
                      : Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: hasThumb
                  ? Image.file(
                      thumbFile,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Theme.of(context).primaryColor.withOpacity(0.7),
                            Theme.of(context).primaryColor,
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        size: 120,
                        color: Colors.white54,
                      ),
                    ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              track.title,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            StreamBuilder<PlayerState>(
              stream: _audioPlayer.playerStateStream,
              builder: (context, snapshot) {
                final playerState = snapshot.data;
                final processingState = playerState?.processingState ?? ProcessingState.idle;
                
                String statusText = "Ready to play";
                if (processingState == ProcessingState.buffering) {
                  statusText = "Buffering...";
                } else if (processingState == ProcessingState.loading) {
                  statusText = "Loading...";
                } else if (playerState?.playing ?? false) {
                  statusText = "Playing";
                } else if (processingState == ProcessingState.completed) {
                  statusText = "Completed";
                } else if (processingState == ProcessingState.ready) {
                  statusText = playerState?.playing ?? false ? "Playing" : "Paused";
                }
                
                return Text(
                  statusText,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerControls(bool isDark) {
    return StreamBuilder<PlayerState>(
      stream: _audioPlayer.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final processingState = playerState?.processingState ?? ProcessingState.idle;
        final playing = playerState?.playing ?? false;
        final isBuffering = processingState == ProcessingState.buffering;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildControlButton(
              icon: Icons.shuffle,
              size: 28,
              color: _audioPlayer.shuffleModeEnabled 
                ? Theme.of(context).primaryColor 
                : isDark ? Colors.white60 : Colors.black45,
              onPressed: () {
                _audioPlayer.setShuffleModeEnabled(!_audioPlayer.shuffleModeEnabled);
                HapticFeedback.lightImpact();
              },
            ),
            const SizedBox(width: 16),
            _buildControlButton(
              icon: Icons.skip_previous,
              size: 36,
              color: _audioPlayer.hasPrevious 
                ? isDark ? Colors.white : Colors.black87
                : isDark ? Colors.white30 : Colors.black26,
              onPressed: _audioPlayer.hasPrevious
                ? () {
                    _audioPlayer.seekToPrevious();
                    HapticFeedback.mediumImpact();
                  }
                : null,
            ),
            const SizedBox(width: 16),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.8),
                    Theme.of(context).primaryColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(40),
                  onTap: isBuffering
                    ? null
                    : () {
                        if (playing) {
                          _audioPlayer.pause();
                        } else {
                          _audioPlayer.play();
                        }
                        HapticFeedback.mediumImpact();
                      },
                  child: isBuffering
                    ? const Center(
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ),
                      )
                    : Icon(
                        playing ? Icons.pause : Icons.play_arrow,
                        size: 48,
                        color: Colors.white,
                      ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            _buildControlButton(
              icon: Icons.skip_next,
              size: 36,
              color: _audioPlayer.hasNext 
                ? isDark ? Colors.white : Colors.black87
                : isDark ? Colors.white30 : Colors.black26,
              onPressed: _audioPlayer.hasNext
                ? () {
                    _audioPlayer.seekToNext();
                    HapticFeedback.mediumImpact();
                  }
                : null,
            ),
            const SizedBox(width: 16),
            _buildControlButton(
              icon: Icons.repeat,
              size: 28,
              color: _audioPlayer.loopMode != LoopMode.off
                ? Theme.of(context).primaryColor
                : isDark ? Colors.white60 : Colors.black45,
              onPressed: () {
                _audioPlayer.setLoopMode(
                  _audioPlayer.loopMode == LoopMode.off
                    ? LoopMode.all
                    : _audioPlayer.loopMode == LoopMode.all
                      ? LoopMode.one
                      : LoopMode.off
                );
                HapticFeedback.lightImpact();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required double size,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: size, color: color),
      onPressed: onPressed,
      splashRadius: 24,
    );
  }

  Widget _buildSeekBar(bool isDark) {
    return StreamBuilder<PositionData>(
      stream: _positionDataStream,
      builder: (context, snapshot) {
        final positionData = snapshot.data ??
            PositionData(Duration.zero, Duration.zero, Duration.zero);

        return SeekBar(
          duration: positionData.duration,
          position: positionData.position,
          bufferedPosition: positionData.bufferedPosition,
          onChanged: _audioPlayer.seek,
          isDark: isDark,
          primaryColor: Theme.of(context).primaryColor,
        );
      },
    );
  }

  Widget _buildVolumeControl(bool isDark) {
    return StreamBuilder<double>(
      stream: _audioPlayer.volumeStream,
      builder: (context, snapshot) {
        final volume = snapshot.data ?? _audioPlayer.volume;
        
        return Row(
          children: [
            Icon(
              volume <= 0 
                ? Icons.volume_off
                : volume < 0.5 
                  ? Icons.volume_down 
                  : Icons.volume_up,
              color: isDark ? Colors.white70 : Colors.black54,
              size: 24,
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: Theme.of(context).primaryColor,
                  inactiveTrackColor: isDark ? Colors.grey[700] : Colors.grey[300],
                  thumbColor: Theme.of(context).primaryColor,
                  overlayColor: Theme.of(context).primaryColor.withAlpha(32),
                ),
                child: Slider(
                  min: 0.0,
                  max: 1.0,
                  value: volume,
                  onChanged: (value) {
                    _audioPlayer.setVolume(value);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.red[900]!.withOpacity(0.2)
                    : Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: isDark ? Colors.red[300] : Colors.red[400],
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Playback Error",
              style: GoogleFonts.poppins(
                color: isDark ? Colors.white : Colors.grey[800],
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "There was an error playing this audio file. Please try again.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _hasError = false;
                  _isInitialized = false;
                });
                _initializePlayer();
              },
              icon: const Icon(Icons.refresh),
              label: Text(
                "Try Again",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.grey[800]!.withOpacity(0.3)
                    : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Loading player...",
              style: GoogleFonts.poppins(
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.grey[800]!.withOpacity(0.3)
                    : Colors.grey[200]!.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.music_off,
                color: Theme.of(context).primaryColor.withOpacity(0.7),
                size: 60,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "No Music Playing",
              style: GoogleFonts.poppins(
                color: isDark ? Colors.white : Colors.grey[800],
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Select a song from your library or playlists to start listening",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to library or search
              },
              icon: const Icon(Icons.library_music),
              label: Text(
                "Browse Library",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      ),
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
  final bool isDark;
  final Color primaryColor;

  const SeekBar({
    Key? key,
    required this.duration,
    required this.position,
    required this.bufferedPosition,
    required this.isDark,
    required this.primaryColor,
    this.onChanged,
  }) : super(key: key);

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final sliderValue = _dragValue ?? (widget.position.inMilliseconds.toDouble().clamp(
      0,
      widget.duration.inMilliseconds.toDouble() == 0 ? 1 : widget.duration.inMilliseconds.toDouble(),
    ));

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: widget.primaryColor,
            inactiveTrackColor: widget.isDark ? Colors.grey[700] : Colors.grey[300],
            thumbColor: widget.primaryColor,
            overlayColor: widget.primaryColor.withAlpha(32),
          ),
          child: Slider(
            min: 0,
            max: widget.duration.inMilliseconds.toDouble() == 0 ? 1 : widget.duration.inMilliseconds.toDouble(),
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
              Text(
                _formatDuration(widget.position),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              Text(
                _formatDuration(widget.duration),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
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
