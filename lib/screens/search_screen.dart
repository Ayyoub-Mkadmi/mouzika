import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
// import 'package:mouzika/backend/youtube_downloader.dart'; // Not used for streaming
import 'package:mouzika/models/playlist.dart'; // Keep this import as is
import 'package:mouzika/models/track.dart';
import 'package:mouzika/models/video_result.dart';
import 'package:mouzika/services/api_service.dart';
import 'package:mouzika/services/audio_player_manager.dart';
import 'package:mouzika/services/downloader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart'; // Import just_audio for AudioSource
import 'package:just_audio_background/just_audio_background.dart'; // Import for MediaItem
// Hide the conflicting Playlist class from youtube_explode_dart
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;

import '../widgets/search_bar_widget.dart';
import '../widgets/search_result_item.dart';
import '../widgets/recently_played_section.dart';
import '../widgets/playlists_section.dart';
import '../widgets/search_state_widgets.dart';

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
  List<Playlist> _playlists = []; // This refers to your model's Playlist
  late Box<Track> trackBox;
  late Box<String> recentlyPlayedBox;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final YoutubeExplode _ytExplode =
      YoutubeExplode(); // Instance of YoutubeExplode
  bool _isFetchingStream = false; // State for stream fetching indicator

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

    // Initialize recently played box if it doesn't exist
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
    // Get recently played track IDs from Hive
    final recentIds = recentlyPlayedBox.values.toList();

    // Create a temporary list to avoid modifying _tracks directly while iterating
    final currentTracks = List<Track>.from(_tracks);

    if (recentIds.isEmpty) {
      setState(() {
        _recentlyPlayedTracks = currentTracks;
      });
      return;
    }

    // Sort tracks based on recently played order
    final sortedTracks = <Track>[];
    final addedIds = <String>{}; // Keep track of added IDs to avoid duplicates

    // First add tracks in the order they were played
    for (final id in recentIds.reversed) {
      final track = currentTracks.firstWhere(
        (t) => t.videoId == id,
        orElse: () => null as Track, // Handle case where track might be deleted
      );

      if (track != null && addedIds.add(track.videoId)) {
        sortedTracks.add(track);
      }
    }

    // Then add any remaining tracks that weren't in recentIds
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
    _ytExplode.close(); // Close the YoutubeExplode instance
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
    // Add to recently played in Hive
    recentlyPlayedBox.add(track.videoId);

    // Keep only the last 50 entries to avoid excessive growth
    if (recentlyPlayedBox.length > 50) {
      recentlyPlayedBox.deleteAt(0);
    }

    // Refresh the recently played list
    _loadRecentlyPlayed();
  }

  void _onDownloadVideo(VideoResult video) async {
    // Show immediate feedback that download started
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

    ScaffoldMessenger.of(
      context,
    ).removeCurrentSnackBar(); // Remove the 'starting' snackbar
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

    // Refresh tracks after download attempt
    _loadTracks();
    _loadRecentlyPlayed();
  }

  // Updated function to play video stream online
  Future<void> _onPlayVideo(VideoResult video) async {
    if (_isFetchingStream) return; // Prevent multiple taps

    if (!mounted) return;
    setState(() {
      _isFetchingStream = true;
    });

    // Show immediate feedback
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
      final manifest = await _ytExplode.videos.streamsClient.getManifest(
        video.videoId,
      );
      // Get the best quality audio-only stream
      final audioStreamInfo = manifest.audioOnly.withHighestBitrate();
      final streamUrl = audioStreamInfo.url;

      // Create MediaItem for background playback
      final mediaItem = MediaItem(
        id: streamUrl.toString(), // Use stream URL as ID for this source
        title: video.title,
        artUri: Uri.parse(video.thumbnailUrl),
        artist:
            "Unknown Artist", // You might get artist info from elsewhere if available
        extras: {
          'videoId': video.videoId, // Store videoId for potential future use
        },
      );

      // Create AudioSource
      final audioSource = AudioSource.uri(streamUrl, tag: mediaItem);

      // Use the new setAudioSource method
      await AudioPlayerManager().setAudioSource(audioSource);

      // *** Explicitly seek to beginning after setting source ***
      await AudioPlayerManager().audioPlayer.seek(Duration.zero);

      // Now play
      AudioPlayerManager().play();

      // Optionally, add to recently played (even if streamed)
      // recentlyPlayedBox.add(video.videoId);
      // _loadRecentlyPlayed();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).removeCurrentSnackBar(); // Remove preparing message
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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
                  onPlay: _onPlayVideo, // Pass the updated function
                ),
          ),
        ),
        // Loading indicator for stream fetching
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
            playlists: _playlists, // Use your model's Playlist here
            tracks: _tracks,
            onRefreshPlaylists: _loadPlaylists,
          ),
          const SizedBox(height: 100), // Bottom padding
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
}
