import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mouzika/services/audio_player_manager.dart';
import 'package:rxdart/rxdart.dart';
import 'package:audio_service/audio_service.dart'; // Needed for MediaItem
import 'package:cached_network_image/cached_network_image.dart'; // For network images

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

// Helper class for seek bar data
class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;

  PositionData(this.position, this.bufferedPosition, this.duration);
}

class _NowPlayingScreenState extends State<NowPlayingScreen>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayerManager().audioPlayer;
  late Stream<PositionData> _positionDataStream;
  bool _isInitialized = false;
  bool _hasError = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Create a distinct stream for MediaItem changes
  Stream<MediaItem?> get _mediaItemStream => _audioPlayer.sequenceStateStream
      .map((state) => state?.currentSource?.tag as MediaItem?)
      .distinct(
        (prev, next) => prev?.id == next?.id && prev?.artUri == next?.artUri,
      ); // Only emit when ID or artUri changes

  @override
  void initState() {
    super.initState();
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

    // Trigger animation only when data is ready and MediaItem is available
    _mediaItemStream.firstWhere((item) => item != null).then((_) {
      if (mounted) _animationController.forward();
    });
  }

  Future<void> _initializePlayer() async {
    try {
      // Combine streams for seek bar
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
          ).distinct().asBroadcastStream(); // Make it broadcast and distinct

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _setupListeners() {
    _audioPlayer.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace st) {
        if (mounted) {
          setState(() {
            _hasError = true;
          });
        }
      },
    );

    // Listen for distinct MediaItem changes to reset animation if needed
    _mediaItemStream.listen((item) {
      if (item != null && mounted) {
        _animationController.reset();
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_hasError) {
      return _buildErrorState(isDark);
    }

    if (!_isInitialized) {
      return _buildLoadingState(isDark);
    }

    // Use StreamBuilder listening to the distinct MediaItem stream
    return StreamBuilder<MediaItem?>(
      stream: _mediaItemStream,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;

        // If no mediaItem, show empty state
        if (mediaItem == null) {
          return _buildEmptyState(isDark);
        }

        // Build the main UI using the mediaItem
        // This part only rebuilds when mediaItem changes
        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors:
                    isDark
                        ? [Colors.grey[900]!, Colors.grey[850]!, Colors.black]
                        : [Colors.grey[100]!, Colors.grey[50]!, Colors.white],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 12.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildHeader(isDark),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            const SizedBox(height: 16),
                            // Pass mediaItem to build song info
                            _buildSongInfo(mediaItem, isDark),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                    // Controls and Seekbar listen to their own streams
                    _buildPlayerControls(isDark),
                    const SizedBox(height: 16),
                    _buildSeekBar(isDark),
                    const SizedBox(height: 8),
                    _buildVolumeControl(isDark),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark) {
    // This can remain as is, doesn't depend on MediaItem directly
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
            _showCurrentPlaylist(isDark);
          },
        ),
      ],
    );
  }

  void _showCurrentPlaylist(bool isDark) {
    final sourceType = AudioPlayerManager().currentSourceType;
    if (sourceType != SourceType.localPlaylist) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Playlist view only available for local library playback.",
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    final currentPlaylistFiles = AudioPlayerManager().filePlaylist;
    final currentIndex = _audioPlayer.currentIndex ?? 0;

    if (currentPlaylistFiles.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[850] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // ... (rest of the playlist modal remains the same)
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
                itemCount: currentPlaylistFiles.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final file = currentPlaylistFiles[index];
                  final fileName = file.path.split('/').last;
                  final songName = fileName
                      .replaceAll(RegExp(r'\.\w+$'), '')
                      .replaceAll('_', ' ');

                  final isPlaying = index == currentIndex;

                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors:
                              isPlaying
                                  ? [
                                    Theme.of(
                                      context,
                                    ).primaryColor.withOpacity(0.7),
                                    Theme.of(context).primaryColor,
                                  ]
                                  : [
                                    isDark
                                        ? Colors.grey[700]!
                                        : Colors.grey[300]!,
                                    isDark
                                        ? Colors.grey[600]!
                                        : Colors.grey[400]!,
                                  ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isPlaying ? Icons.play_arrow : Icons.music_note,
                        color:
                            isPlaying
                                ? Colors.white
                                : isDark
                                ? Colors.white70
                                : Colors.black54,
                      ),
                    ),
                    title: Text(
                      songName,
                      style: GoogleFonts.poppins(
                        fontWeight:
                            isPlaying ? FontWeight.w600 : FontWeight.w400,
                        color:
                            isPlaying
                                ? Theme.of(context).primaryColor
                                : isDark
                                ? Colors.white
                                : Colors.black87,
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

  // This widget now only rebuilds when mediaItem changes
  Widget _buildSongInfo(MediaItem mediaItem, bool isDark) {
    bool isLocalArt = mediaItem.artUri?.scheme == 'file';
    File? localArtFile;
    if (isLocalArt && mediaItem.artUri != null) {
      try {
        localArtFile = File.fromUri(mediaItem.artUri!);
        isLocalArt = localArtFile.existsSync();
      } catch (_) {
        isLocalArt = false;
      }
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final artSize = screenWidth * 0.7 > 280 ? 280.0 : screenWidth * 0.7;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Column(
          children: [
            Container(
              width: artSize,
              height: artSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color:
                        isDark
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
                // Add ValueKey to Image widgets to help Flutter optimize rebuilds
                child:
                    isLocalArt && localArtFile != null
                        ? Image.file(
                          localArtFile,
                          key: ValueKey(mediaItem.artUri.toString()),
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => _buildFallbackArt(isDark),
                        )
                        : mediaItem.artUri != null
                        ? CachedNetworkImage(
                          imageUrl: mediaItem.artUri.toString(),
                          key: ValueKey(mediaItem.artUri.toString()),
                          fit: BoxFit.cover,
                          placeholder:
                              (context, url) =>
                                  _buildFallbackArt(isDark, isLoading: true),
                          errorWidget:
                              (context, url, error) =>
                                  _buildFallbackArt(isDark),
                        )
                        : _buildFallbackArt(isDark),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                mediaItem.title,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            if (mediaItem.artist != null && mediaItem.artist!.isNotEmpty)
              Text(
                mediaItem.artist!,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  // This widget listens to player state changes
  Widget _buildPlayerControls(bool isDark) {
    return StreamBuilder<PlayerState>(
      stream:
          _audioPlayer.playerStateStream.distinct(), // Use distinct here too
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final processingState =
            playerState?.processingState ?? ProcessingState.idle;
        final playing = playerState?.playing ?? false;
        final isBuffering =
            processingState == ProcessingState.buffering ||
            processingState == ProcessingState.loading;

        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 380;
        final iconSize = isSmallScreen ? 55.0 : 65.0;
        final sideIconSize = isSmallScreen ? 35.0 : 40.0;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Shuffle Button
            StreamBuilder<bool>(
              stream: _audioPlayer.shuffleModeEnabledStream.distinct(),
              builder: (context, snapshot) {
                final shuffleModeEnabled = snapshot.data ?? false;
                return IconButton(
                  iconSize: sideIconSize * 0.7,
                  icon: Icon(
                    shuffleModeEnabled ? Icons.shuffle_on : Icons.shuffle,
                    color:
                        shuffleModeEnabled
                            ? Theme.of(context).primaryColor
                            : (isDark ? Colors.white70 : Colors.black54),
                  ),
                  onPressed: () async {
                    final enable = !shuffleModeEnabled;
                    await _audioPlayer.setShuffleModeEnabled(enable);
                  },
                );
              },
            ),
            // Previous Button
            IconButton(
              iconSize: sideIconSize,
              icon: Icon(
                Icons.skip_previous_rounded,
                color: isDark ? Colors.white : Colors.black87,
              ),
              onPressed:
                  _audioPlayer.hasPrevious ? _audioPlayer.seekToPrevious : null,
            ),
            // Play/Pause Button
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.8),
                    Theme.of(context).primaryColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: iconSize * 0.6,
                icon:
                    isBuffering
                        ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        )
                        : Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                        ),
                onPressed: () {
                  if (playing) {
                    _audioPlayer.pause();
                  } else {
                    _audioPlayer.play();
                  }
                },
              ),
            ),
            // Next Button
            IconButton(
              iconSize: sideIconSize,
              icon: Icon(
                Icons.skip_next_rounded,
                color: isDark ? Colors.white : Colors.black87,
              ),
              onPressed: _audioPlayer.hasNext ? _audioPlayer.seekToNext : null,
            ),
            // Repeat Button
            StreamBuilder<LoopMode>(
              stream: _audioPlayer.loopModeStream.distinct(),
              builder: (context, snapshot) {
                final loopMode = snapshot.data ?? LoopMode.off;
                final icons = [Icons.repeat, Icons.repeat_one, Icons.repeat];
                const cycleModes = [LoopMode.off, LoopMode.one, LoopMode.all];
                final index = cycleModes.indexOf(loopMode);
                return IconButton(
                  iconSize: sideIconSize * 0.7,
                  icon: Icon(
                    icons[index],
                    color:
                        loopMode != LoopMode.off
                            ? Theme.of(context).primaryColor
                            : (isDark ? Colors.white70 : Colors.black54),
                  ),
                  onPressed: () {
                    _audioPlayer.setLoopMode(
                      cycleModes[(index + 1) % cycleModes.length],
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  // This widget listens to position changes
  Widget _buildSeekBar(bool isDark) {
    return StreamBuilder<PositionData>(
      stream: _positionDataStream, // Already distinct
      builder: (context, snapshot) {
        final positionData =
            snapshot.data ??
            PositionData(Duration.zero, Duration.zero, Duration.zero);
        final position = positionData.position;
        final duration = positionData.duration;

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3.0,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 7.0,
                ),
                overlayShape: const RoundSliderOverlayShape(
                  overlayRadius: 15.0,
                ),
                activeTrackColor: Theme.of(context).primaryColor,
                inactiveTrackColor:
                    isDark ? Colors.grey[700] : Colors.grey[300],
                thumbColor: Theme.of(context).primaryColor,
                overlayColor: Theme.of(context).primaryColor.withAlpha(50),
              ),
              child: Slider(
                min: 0.0,
                max: duration.inMilliseconds.toDouble().clamp(
                  0.0,
                  double.infinity,
                ),
                value: position.inMilliseconds.toDouble().clamp(
                  0.0,
                  duration.inMilliseconds.toDouble(),
                ),
                onChanged: (value) {
                  _audioPlayer.seek(Duration(milliseconds: value.toInt()));
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(position),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  Text(
                    _formatDuration(duration),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // This widget listens to volume changes
  Widget _buildVolumeControl(bool isDark) {
    return Row(
      children: [
        Icon(
          Icons.volume_down,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
              activeTrackColor: isDark ? Colors.grey[500] : Colors.grey[700],
              inactiveTrackColor: isDark ? Colors.grey[700] : Colors.grey[300],
              thumbColor: isDark ? Colors.grey[400] : Colors.grey[600],
              overlayColor:
                  isDark
                      ? Colors.grey[400]?.withAlpha(50)
                      : Colors.grey[600]?.withAlpha(50),
            ),
            child: StreamBuilder<double>(
              stream: _audioPlayer.volumeStream.distinct(), // Use distinct
              builder: (context, snapshot) {
                return Slider(
                  min: 0.0,
                  max: 1.0,
                  value: snapshot.data ?? 0.5,
                  onChanged: _audioPlayer.setVolume,
                );
              },
            ),
          ),
        ),
        Icon(
          Icons.volume_up,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? "${twoDigits(duration.inHours)}:$minutes:$seconds"
        : "$minutes:$seconds";
  }

  Widget _buildFallbackArt(bool isDark, {bool isLoading = false}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor.withOpacity(isDark ? 0.5 : 0.7),
            Theme.of(context).primaryColor.withOpacity(isDark ? 0.8 : 1.0),
          ],
        ),
      ),
      child: Center(
        child:
            isLoading
                ? CircularProgressIndicator(
                  color: Colors.white.withOpacity(0.7),
                )
                : Icon(
                  Icons.music_note,
                  size: 120,
                  color: Colors.white.withOpacity(0.5),
                ),
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            Text(
              'Playback Error',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'An error occurred during playback.',
              style: GoogleFonts.poppins(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Center(
        child: CircularProgressIndicator(color: Theme.of(context).primaryColor),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_off_outlined,
              size: 80,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              'Nothing Playing',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a song to start listening.',
              style: GoogleFonts.poppins(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
