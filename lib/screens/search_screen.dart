import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mouzika/models/playlist.dart';
import 'package:mouzika/models/track.dart';
import 'package:mouzika/models/video_result.dart';
import 'package:mouzika/services/api_service.dart';
import 'package:mouzika/services/audio_player_manager.dart';
import 'package:mouzika/services/downloader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;

import '../widgets/search_bar_widget.dart';
import '../widgets/search_result_item.dart';
import '../widgets/recently_played_section.dart';
import '../widgets/playlists_section.dart';
import '../widgets/search_state_widgets.dart';
// *** IMPORT THE API KEY SETTINGS SCREEN ***
import 'api_key_settings_screen.dart'; 

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  List<VideoResult> _results = [];
  bool _isLoading = false;
  String? _error;
  bool _isSearchMode = false;
  List<Track> _tracks = [];
  List<Track> _recentlyPlayedTracks = [];
  List<Playlist> _playlists = [];
  late Box<Track> trackBox;
  late Box<String> recentlyPlayedBox;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final YoutubeExplode _ytExplode = YoutubeExplode();
  bool _isFetchingStream = false;

  // *** Variables for hidden access gesture ***
  int _tapCount = 0;
  DateTime? _lastTapTime;
  final Duration _tapInterval = const Duration(milliseconds: 400); // Max interval between taps
  // *** End variables for hidden access gesture ***

  @override
  void initState() {
    super.initState();
    _initHive();
    _loadPlaylists();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  Future<void> _initHive() async {
    trackBox = Hive.box<Track>('tracks');
    if (!Hive.isBoxOpen('recently_played')) {
      recentlyPlayedBox = await Hive.openBox<String>('recently_played');
    } else {
      recentlyPlayedBox = Hive.box<String>('recently_played');
    }
    _loadTracks();
    _loadRecentlyPlayed();
  }

  Future<void> _loadTracks() async {
    if (!mounted) return;
    setState(() {
      _tracks =
          trackBox.values.where((track) {
            final file = File(track.mp3Path);
            return file.existsSync();
          }).toList();
    });
  }

  Future<void> _loadRecentlyPlayed() async {
    if (!mounted) return;
    final recentIds = recentlyPlayedBox.values.toList();
    final currentTracks = List<Track>.from(_tracks);
    if (recentIds.isEmpty) {
      setState(() {
        _recentlyPlayedTracks = currentTracks;
      });
      return;
    }
    final sortedTracks = <Track>[];
    final addedIds = <String>{};
    for (final id in recentIds.reversed) {
      final track = currentTracks.firstWhere(
        (t) => t.videoId == id,
        orElse: () => null as Track,
      );
      if (track != null && addedIds.add(track.videoId)) {
        sortedTracks.add(track);
      }
    }
    for (final track in currentTracks) {
      if (addedIds.add(track.videoId)) {
        sortedTracks.add(track);
      }
    }
    setState(() {
      _recentlyPlayedTracks = sortedTracks;
    });
  }

  Future<void> _loadPlaylists() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final playlistData = prefs.getStringList('playlists') ?? [];
    setState(() {
      _playlists =
          playlistData.map((e) => Playlist.fromJson(json.decode(e))).toList();
    });
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final playlistData =
        _playlists.map((p) => json.encode(p.toJson())).toList();
    await prefs.setStringList('playlists', playlistData);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    _ytExplode.close();
    super.dispose();
  }

  Future<void> _searchVideos(String query) async {
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isSearchMode = false;
        _results = [];
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _isSearchMode = true;
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await ApiService.searchVideos(query);
      if (!mounted) return;
      setState(() {
        _results = results;
      });
      _animationController.reset();
      _animationController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Failed to fetch results. Please try again.";
      });
    }
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  void _onTrackPlayed(Track track) {
    recentlyPlayedBox.add(track.videoId);
    if (recentlyPlayedBox.length > 50) {
      recentlyPlayedBox.deleteAt(0);
    }
    _loadRecentlyPlayed();
  }

  void _onDownloadVideo(VideoResult video) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Starting download for "${video.title}"...',
          style: GoogleFonts.poppins(),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    final ok = await Downloader.downloadAndStore(video);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Saved "${video.title}" to your library'
              : 'Download failed – try again',
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: ok ? Colors.green[700] : Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    _loadTracks();
    _loadRecentlyPlayed();
  }

  Future<void> _onPlayVideo(VideoResult video) async {
    if (_isFetchingStream) return;
    if (!mounted) return;
    setState(() {
      _isFetchingStream = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Preparing stream for "${video.title}"...',
          style: GoogleFonts.poppins(),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    try {
      final manifest = await _ytExplode.videos.streamsClient.getManifest(video.videoId);
      final audioStreamInfo = manifest.audioOnly.withHighestBitrate();
      final streamUrl = audioStreamInfo.url;
      final mediaItem = MediaItem(
        id: streamUrl.toString(),
        title: video.title,
        artUri: Uri.parse(video.thumbnailUrl),
        artist: "Unknown Artist",
        extras: {'videoId': video.videoId},
      );
      final audioSource = AudioSource.uri(streamUrl, tag: mediaItem);
      await AudioPlayerManager().setAudioSource(audioSource);
      await AudioPlayerManager().audioPlayer.seek(Duration.zero);
      AudioPlayerManager().play();
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
      }
    } catch (e) {
      print("Error fetching or playing stream: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to play stream: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingStream = false;
        });
      }
    }
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return SearchStateWidgets.buildLoadingState(context);
    } else if (_error != null) {
      return SearchStateWidgets.buildErrorState(
        context,
        _error!,
        () => _searchVideos(_controller.text),
      );
    } else if (_results.isEmpty) {
      return SearchStateWidgets.buildEmptyState(context, _fadeAnimation, () {
        if (!mounted) return;
        setState(() {
          _isSearchMode = false;
          _controller.clear();
        });
        FocusScope.of(context).unfocus();
      });
    }
    return Stack(
      children: [
        AnimationLimiter(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: _results.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder:
                (context, index) => SearchResultItem(
                  video: _results[index],
                  index: index,
                  onDownload: _onDownloadVideo,
                  onPlay: _onPlayVideo,
                ),
          ),
        ),
        if (_isFetchingStream)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildHomeContent() {
    final bool hasContent = _tracks.isNotEmpty || _playlists.isNotEmpty;
    if (!hasContent) {
      return SearchStateWidgets.buildWelcomeState(context, () {
        FocusScope.of(context).requestFocus(FocusNode());
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      });
    }
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RecentlyPlayedSection(
            tracks: _recentlyPlayedTracks,
            onRefreshTracks: () {
              _loadTracks();
              _loadRecentlyPlayed();
            },
          ),
          PlaylistsSection(
            playlists: _playlists,
            tracks: _tracks,
            onRefreshPlaylists: _loadPlaylists,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // *** Function to handle taps for hidden access ***
  void _handleTap() {
    final now = DateTime.now();
    if (_lastTapTime == null || now.difference(_lastTapTime!) > _tapInterval) {
      // If first tap or interval too long, reset count
      _tapCount = 1;
    } else {
      // Increment count if within interval
      _tapCount++;
    }
    _lastTapTime = now;

    if (_tapCount >= 4) {
      // Reset count and navigate
      _tapCount = 0;
      _lastTapTime = null; // Reset time as well
      print("Navigating to API Key Settings..."); // Debug print
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ApiKeySettingsScreen()),
      );
    }
    // Optional: print tap count for debugging
    // print("Tap count: $_tapCount");
  }
  // *** End function for hidden access ***

  @override
  Widget build(BuildContext context) {
    // *** Wrap the main Column with GestureDetector ***
    return GestureDetector(
      onTap: _handleTap, // Call the tap handler
      // Use HitTestBehavior.opaque to ensure taps on empty space are caught
      behavior: HitTestBehavior.opaque, 
      child: Column(
        children: [
          SearchBarWidget(
            controller: _controller,
            onSubmitted: _searchVideos,
            onChanged: (value) {
              if (value.isEmpty && _isSearchMode) {
                if (!mounted) return;
                setState(() {
                  _isSearchMode = false;
                  _results = [];
                });
              }
            },
            onSearchPressed: () => _searchVideos(_controller.text),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _isSearchMode ? _buildSearchResults() : _buildHomeContent(),
            ),
          ),
        ],
      ),
    );
    // *** End GestureDetector wrapper ***
  }
}

