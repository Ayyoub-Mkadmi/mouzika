import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Import Hive
import 'package:mouzika/models/track.dart'; // Import Track model
import 'package:mouzika/screens/song_picker_screen.dart';
import 'package:mouzika/services/audio_player_manager.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart'; // Import Provider
import '../providers/theme_provider.dart'; // Import ThemeProvider
import '../models/playlist.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final Playlist playlist;
  final Function(Playlist) onPlaylistUpdated;

  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
    required this.onPlaylistUpdated,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen>
    with SingleTickerProviderStateMixin {
  late Playlist _playlist;
  bool _isLoading = true; // Start loading to filter playlist initially
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Box<Track> _trackBox; // Hive box for tracks

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist; // Initial assignment
    _trackBox = Hive.box<Track>('tracks'); // Open track box
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    // Call async initialization
    _initializeAndFilterPlaylist();
  }

  Future<void> _initializeAndFilterPlaylist() async {
    await _filterPlaylistSongs(); // Filter songs based on file existence
    if (mounted) {
      setState(() {
        _isLoading = false; // Stop loading after filtering
      });
      _animationController.forward(); // Start animation after loading
    }
  }

  // New function to filter playlist songs based on file existence
  Future<void> _filterPlaylistSongs() async {
    final originalPaths = List<String>.from(_playlist.songs);
    final validSongPaths = <String>[];
    bool changed = false;

    for (final path in originalPaths) {
      final file = File(path);
      if (await file.exists()) {
        validSongPaths.add(path);
      } else {
        changed = true; // Mark that a change occurred
      }
    }

    // If any songs were removed because the file didn't exist
    if (changed && mounted) {
      setState(() {
        _playlist.songs = validSongPaths;
      });
      widget.onPlaylistUpdated(_playlist); // Persist the filtered list
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // FIXED: Updated function to only remove song from playlist, not delete from library
  Future<void> _removeSong(int index) async {
    if (index < 0 || index >= _playlist.songs.length) return; // Bounds check

    // Only remove the song from the playlist's songs list
    if (mounted) {
      setState(() {
        _playlist.songs.removeAt(index);
      });
      widget.onPlaylistUpdated(_playlist); // Notify parent of playlist update
    }

    // Show confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Song removed from playlist',
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange[700],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: Colors.white,
            onPressed: () {
              // This would require storing the removed song path and index
              // For simplicity, we'll just notify the user that they need to add it again
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Please use "Add Songs" to add the song back',
                    style: GoogleFonts.poppins(),
                  ),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  Future<void> _addSongs() async {
    // No need to set _isLoading here, handled by Navigator push
    final selected = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (_) => const SongPickerScreen()),
    );

    if (selected != null && selected.isNotEmpty) {
      bool addedNew = false;
      setState(() {
        for (var path in selected) {
          if (!_playlist.songs.contains(path)) {
            _playlist.songs.add(path);
            addedNew = true;
          }
        }
      });
      if (addedNew) {
        widget.onPlaylistUpdated(_playlist);
      }

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${selected.length} song${selected.length > 1 ? 's' : ''} to playlist',
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green[700],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _playSong(int index) {
    if (index < 0 || index >= _playlist.songs.length) return; // Bounds check
    HapticFeedback.lightImpact();
    // Filter list again just before playing to ensure files exist
    final playableFiles =
        _playlist.songs
            .map((path) => File(path))
            .where((file) => file.existsSync())
            .toList();

    // Find the new index in the filtered list
    final currentPath = _playlist.songs[index];
    final playableIndex = playableFiles.indexWhere(
      (file) => file.path == currentPath,
    );

    if (playableIndex != -1) {
      AudioPlayerManager().setPlaylist(
        playableFiles,
        initialIndex: playableIndex,
      );
      AudioPlayerManager().play();
    } else {
      // Handle case where the selected song file was deleted just before playing
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Song file not found.', style: GoogleFonts.poppins()),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange[700],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      // Optionally refresh the list here
      _filterPlaylistSongs();
    }
  }

  void _playAll() {
    if (_playlist.songs.isEmpty) return;
    HapticFeedback.mediumImpact();
    // Filter list again just before playing to ensure files exist
    final playableFiles =
        _playlist.songs
            .map((path) => File(path))
            .where((file) => file.existsSync())
            .toList();

    if (playableFiles.isNotEmpty) {
      AudioPlayerManager().setPlaylist(playableFiles, initialIndex: 0);
      AudioPlayerManager().play();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No playable songs found in playlist.',
            style: GoogleFonts.poppins(),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange[700],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      // Optionally refresh the list here
      _filterPlaylistSongs();
    }
  }

  String _formatFileName(String fileName) {
    // Remove .mp3 extension
    String name = fileName.replaceAll('.mp3', '');

    // Replace underscores with spaces
    name = name.replaceAll('_', ' ');

    return name;
  }

  Widget _buildEmptyState(BuildContext context) {
    // Pass context
    final isDark =
        Provider.of<ThemeProvider>(context).isDarkMode; // Use ThemeProvider
    final primaryColor = Theme.of(context).primaryColor;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color:
                    isDark
                        ? Colors.grey[800]!.withOpacity(0.3)
                        : Colors.grey[200]!.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.music_off,
                color: primaryColor.withOpacity(0.7), // Use primaryColor
                size: 60,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "No Songs Yet",
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
                "Add songs to your playlist to start listening",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _addSongs,
              icon: const Icon(Icons.add),
              label: Text(
                "Add Songs",
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
                backgroundColor: primaryColor, // Use primaryColor
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

  Widget _buildLoadingState(BuildContext context) {
    // Pass context
    final isDark =
        Provider.of<ThemeProvider>(context).isDarkMode; // Use ThemeProvider
    final primaryColor = Theme.of(context).primaryColor;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  isDark
                      ? Colors.grey[800]!.withOpacity(0.3)
                      : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: CircularProgressIndicator(
              color: primaryColor, // Use primaryColor
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Loading playlist...", // Updated text
            style: GoogleFonts.poppins(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackIcon(BuildContext context) {
    // Pass context
    final isDark =
        Provider.of<ThemeProvider>(context).isDarkMode; // Use ThemeProvider

    return Container(
      color: isDark ? Colors.grey[800] : Colors.grey[300],
      child: Center(
        child: Icon(
          Icons.music_note,
          color: isDark ? Colors.grey[600] : Colors.grey[400],
          size: 30,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get theme info from Provider
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final primaryColor = Theme.of(context).primaryColor;
    final scaffoldBackgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor, // Use theme background
      appBar: AppBar(
        backgroundColor: scaffoldBackgroundColor, // Use theme background
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _playlist.name,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87, // Adjust title color
          ),
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black87, // Adjust icon color
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.add,
              color: isDark ? Colors.white : primaryColor,
            ), // Use primaryColor in light mode
            onPressed: _addSongs,
            tooltip: 'Add Songs',
          ),
        ],
      ),
      floatingActionButton:
          _playlist.songs.isNotEmpty
              ? FloatingActionButton(
                onPressed: _playAll,
                backgroundColor: primaryColor, // Use primaryColor
                child: const Icon(Icons.play_arrow, color: Colors.white),
              )
              : null,
      body:
          _isLoading
              ? _buildLoadingState(context)
              : _playlist.songs.isEmpty
              ? _buildEmptyState(context)
              : AnimationLimiter(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: _playlist.songs.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) {
                    if (index >= _playlist.songs.length) {
                      return const SizedBox.shrink(); // Safety check
                    }
                    final path = _playlist.songs[index];
                    final fileName = p.basename(path);
                    final formattedName = _formatFileName(fileName);

                    // Try to find thumbnail path by replacing mp3 with jpg in the path
                    final String potentialThumbPath = path
                        .replaceAll('/mp3s/', '/thumbnails/')
                        .replaceAll('.mp3', '.jpg');
                    final bool hasThumb = File(potentialThumbPath).existsSync();

                    return AnimationConfiguration.staggeredList(
                      position: index,
                      duration: const Duration(milliseconds: 450),
                      child: SlideAnimation(
                        verticalOffset: 50.0,
                        child: FadeInAnimation(
                          child: Dismissible(
                            key: ValueKey(path), // Unique key for each item
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20.0),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            confirmDismiss: (direction) async {
                              // Show confirmation dialog
                              return await showDialog<bool>(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Text(
                                      'Remove from Playlist',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    content: Text(
                                      'Do you want to remove this song from the playlist?\n\nThe song will remain in your library.',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    actions: <Widget>[
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: Text(
                                          'CANCEL',
                                          style: GoogleFonts.poppins(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: Text(
                                          'REMOVE',
                                          style: GoogleFonts.poppins(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                            onDismissed: (direction) {
                              _removeSong(index);
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isDark
                                      ? [
                                          Colors.grey[850]!,
                                          Colors.grey[800]!,
                                        ]
                                      : [
                                          Colors.white,
                                          Colors.grey[50]!,
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: hasThumb
                                        ? Image.file(
                                            File(potentialThumbPath),
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    _buildFallbackIcon(context),
                                          )
                                        : _buildFallbackIcon(context),
                                  ),
                                ),
                                title: Text(
                                  formattedName,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w500,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: IconButton(
                                  icon: Icon(
                                    Icons.play_circle_fill,
                                    color: primaryColor,
                                    size: 36,
                                  ),
                                  onPressed: () => _playSong(index),
                                ),
                                onTap: () => _playSong(index),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
