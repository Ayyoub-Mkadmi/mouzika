import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mouzika/backend/youtube_downloader.dart';
import 'package:mouzika/models/playlist.dart';
import 'package:mouzika/models/track.dart';
import 'package:mouzika/models/video_result.dart';
import 'package:mouzika/services/api_service.dart';
import 'package:mouzika/services/audio_player_manager.dart';
import 'package:mouzika/services/downloader.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/search_bar_widget.dart';
import '../widgets/search_result_item.dart';
import '../widgets/recently_played_section.dart';
import '../widgets/playlists_section.dart';
import '../widgets/search_state_widgets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
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
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
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
    setState(() {
      _tracks = trackBox.values.where((track) {
        final file = File(track.mp3Path);
        return file.existsSync();
      }).toList();
    });
  }

  Future<void> _loadRecentlyPlayed() async {
    // Get recently played track IDs from Hive
    final recentIds = recentlyPlayedBox.values.toList();
    
    if (recentIds.isEmpty) {
      setState(() {
        _recentlyPlayedTracks = _tracks;
      });
      return;
    }
    
    // Sort tracks based on recently played order
    final sortedTracks = <Track>[];
    
    // First add tracks in the order they were played
    for (final id in recentIds.reversed) {
      final track = _tracks.firstWhere(
        (t) => t.videoId == id,
        orElse: () => null as Track,
      );
      
      if (track != null && !sortedTracks.contains(track)) {
        sortedTracks.add(track);
      }
    }
    
    // Then add any remaining tracks
    for (final track in _tracks) {
      if (!sortedTracks.contains(track)) {
        sortedTracks.add(track);
      }
    }
    
    setState(() {
      _recentlyPlayedTracks = sortedTracks;
    });
  }

  Future<void> _loadPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final playlistData = prefs.getStringList('playlists') ?? [];

    setState(() {
      _playlists = playlistData
          .map((e) => Playlist.fromJson(json.decode(e)))
          .toList();
    });
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final playlistData = _playlists.map((p) => json.encode(p.toJson())).toList();
    await prefs.setStringList('playlists', playlistData);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _searchVideos(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearchMode = false;
        _results = [];
      });
      return;
    }

    setState(() {
      _isSearchMode = true;
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await ApiService.searchVideos(query);
      setState(() {
        _results = results;
      });
      _animationController.reset();
      _animationController.forward();
    } catch (e) {
      setState(() {
        _error = "Failed to fetch results. Please try again.";
      });
    }

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
    final ok = await Downloader.downloadAndStore(video);
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Saved "${video.title}" to your library' : 'Download failed – try again',
          style: GoogleFonts.poppins(),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
    
    // Refresh tracks after download
    _loadTracks();
    _loadRecentlyPlayed();
  }

  void _onPlayVideo(VideoResult video) {
    // Play online functionality
    print('Play online tapped for ${video.title}');
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return SearchStateWidgets.buildLoadingState(context);
    } else if (_error != null) {
      return SearchStateWidgets.buildErrorState(
        context, 
        _error!, 
        () => _searchVideos(_controller.text)
      );
    } else if (_results.isEmpty) {
      return SearchStateWidgets.buildEmptyState(
        context, 
        _fadeAnimation, 
        () {
          setState(() {
            _isSearchMode = false;
            _controller.clear();
          });
          FocusScope.of(context).unfocus();
        }
      );
    }

    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        itemCount: _results.length,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) => SearchResultItem(
          video: _results[index],
          index: index,
          onDownload: _onDownloadVideo,
          onPlay: _onPlayVideo,
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    final bool hasContent = _tracks.isNotEmpty || _playlists.isNotEmpty;
    
    if (!hasContent) {
      return SearchStateWidgets.buildWelcomeState(
        context,
        () {
          FocusScope.of(context).requestFocus(FocusNode());
          _controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controller.text.length,
          );
        }
      );
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
