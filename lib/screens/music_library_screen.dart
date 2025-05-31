import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mouzika/services/audio_player_manager.dart'; // Assuming correct path
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart'; // Import Hive
import '../models/playlist.dart'; // Assuming correct path
import '../models/track.dart'; // Import Track model

class MusicLibraryScreen extends StatefulWidget {
  const MusicLibraryScreen({Key? key}) : super(key: key);

  @override
  State<MusicLibraryScreen> createState() => _MusicLibraryScreenState();
}

class _MusicLibraryScreenState extends State<MusicLibraryScreen> with SingleTickerProviderStateMixin {
  List<File> _mp3Files = [];
  List<Playlist> _playlists = [];
  bool _isLoading = true;
  late AnimationController _animationController;
  late Box<Track> _trackBox; // Hive box for tracks
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _initializeAndLoad();
    _animationController.forward();
  }

  Future<void> _initializeAndLoad() async {
    await _openHiveBox();
    await _loadMusicFiles();
    await _loadPlaylists();
  }

  Future<void> _openHiveBox() async {
    // Ensure the box is open before trying to access it
    // Hive.initFlutter() should be called ONLY ONCE in main.dart
    if (!Hive.isBoxOpen('tracks')) {
      // Assuming TrackAdapter is registered in main.dart
      _trackBox = await Hive.openBox<Track>('tracks');
    } else {
      _trackBox = Hive.box<Track>('tracks');
    }
    // Also open recently played box if needed for consistency
    if (!Hive.isBoxOpen('recently_played')) {
       await Hive.openBox<String>('recently_played');
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    // Hive boxes are typically kept open for the app's lifetime
    super.dispose();
  }

  Future<void> _loadMusicFiles() async {
    setState(() {
      _isLoading = true;
    });
    
    final directory = await getApplicationDocumentsDirectory();
    final musicDir = Directory('${directory.path}/mp3s');

    if (await musicDir.exists()) {
      final files =
          musicDir
              .listSync()
              .where(
                (file) =>
                    file is File && file.path.toLowerCase().endsWith('.mp3'),
              )
              .cast<File>()
              .toList();
      // Sort files alphabetically by name
      files.sort((a, b) => a.path.split('/').last.compareTo(b.path.split('/').last));
      setState(() {
        _mp3Files = files;
        _isLoading = false;
      });
    } else {
      await musicDir.create(recursive: true);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('playlists') ?? [];
    setState(() {
      _playlists = data.map((e) => Playlist.fromJson(json.decode(e))).toList();
    });
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _playlists.map((p) => json.encode(p.toJson())).toList();
    await prefs.setStringList('playlists', data);
  }

  void _addToPlaylist(File file) {
    final filePath = file.path;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final track = _findTrackByPath(filePath);

    if (track == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: Track metadata not found.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? Colors.grey[850] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        if (_playlists.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.playlist_add,
                  size: 48,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(height: 16),
                Text(
                  'No playlists available',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a playlist first to add songs',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Consider navigating to playlist screen or showing create dialog
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'Create Playlist',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        }
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Add to Playlist',
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
                itemCount: _playlists.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final playlist = _playlists[index];
                  // Use track.key for checking if added
                  final alreadyAdded = playlist.songs.contains(track.key);
                  
                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 375),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: alreadyAdded
                                  ? [Colors.grey[400]!, Colors.grey[600]!]
                                  : [
                                      Theme.of(context).primaryColor.withOpacity(0.7),
                                      Theme.of(context).primaryColor,
                                    ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              alreadyAdded ? Icons.check : Icons.playlist_add,
                              color: Colors.white,
                            ),
                          ),
                          title: Text(
                            playlist.name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            '${playlist.songs.length} song${playlist.songs.length != 1 ? 's' : ''}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          enabled: !alreadyAdded,
                          onTap: alreadyAdded
                              ? null
                              : () {
                                  setState(() {
                                    // Add track.key instead of filePath
                                    playlist.songs.add(track.key);
                                  });
                                  _savePlaylists();
                                  Navigator.pop(context);
                                  
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Added "${track.title}" to "${playlist.name}"',
                                        style: GoogleFonts.poppins(),
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: Colors.green[700],
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16), // Add some padding at the bottom
          ],
        );
      },
    );
  }

  String _formatFileName(String fileName) {
    String name = fileName.replaceAll('.mp3', '');
    name = name.replaceAll('_', ' ');
    return name;
  }

  Track? _findTrackByPath(String mp3Path) {
    try {
      return _trackBox.values.firstWhere((t) => t.mp3Path == mp3Path);
    } catch (e) {
      print("Track not found in Hive for path: $mp3Path");
      return null;
    }
  }

  Future<bool?> _confirmDeleteSong(File file) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final track = _findTrackByPath(file.path);
    final trackTitle = track?.title ?? _formatFileName(file.path.split('/').last);

    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[850] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Delete Song',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$trackTitle"? This will remove the file permanently.',
          style: GoogleFonts.poppins(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // Return false on cancel
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.shade400,
                  Colors.red.shade700,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () async {
                  Navigator.pop(context, true); // Return true to confirm deletion
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    'Delete',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performDeleteSong(File file) async {
    final track = _findTrackByPath(file.path);
    final trackKey = track?.key;
    final thumbPath = track?.thumbPath;

    try {
      // 1. Delete MP3 file
      if (await file.exists()) {
        await file.delete();
        print("Deleted MP3: ${file.path}");
      }

      // 2. Delete Thumbnail file
      if (thumbPath != null && thumbPath.isNotEmpty) {
        final thumbFile = File(thumbPath);
        if (await thumbFile.exists()) {
          await thumbFile.delete();
          print("Deleted Thumbnail: $thumbPath");
        }
      }

      // 3. Remove from Hive Box
      if (trackKey != null && _trackBox.containsKey(trackKey)) {
        await _trackBox.delete(trackKey);
        print("Deleted track from Hive: key $trackKey");
      }

      // 4. Remove from Playlists
      bool playlistsUpdated = false;
      if (trackKey != null) {
        for (var playlist in _playlists) {
          if (playlist.songs.contains(trackKey)) {
            playlist.songs.remove(trackKey);
            playlistsUpdated = true;
          }
        }
        if (playlistsUpdated) {
          await _savePlaylists();
          print("Removed track key $trackKey from playlists");
        }
      }
      
      // 5. Remove from Recently Played (if implemented)
      final recentBox = Hive.box<String>('recently_played');
      if (trackKey != null && recentBox.values.contains(trackKey)){
         // Find the entry and delete it by its index/key in the recent box
         var entries = recentBox.toMap().entries.where((entry) => entry.value == trackKey);
         for (var entry in entries) {
            await recentBox.delete(entry.key);
         }
         print("Removed track key $trackKey from recently played");
      }

      // 6. Update UI State
      setState(() {
        _mp3Files.remove(file);
      });

      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${track?.title ?? 'Song'}" deleted successfully.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );

    } catch (e) {
      print("Error deleting song: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting song: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildMusicItem(File file, int index, List<File> allFiles) {
    final fileName = file.path.split('/').last;
    final formattedName = _formatFileName(fileName);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final track = _findTrackByPath(file.path);
    final thumbPath = track?.thumbPath ?? '';
    final hasThumb = thumbPath.isNotEmpty && File(thumbPath).existsSync();
    final itemKey = ValueKey<String>(file.path); // Unique key for Dismissible

    return AnimationConfiguration.staggeredList(
      position: index,
      duration: const Duration(milliseconds: 450),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          // Wrap with Dismissible for swipe-to-delete
          child: Dismissible(
            key: itemKey,
            direction: DismissDirection.endToStart, // Swipe left to delete
            confirmDismiss: (direction) async {
              return await _confirmDeleteSong(file);
            },
            onDismissed: (direction) {
              // Perform actual deletion after confirmation
              _performDeleteSong(file);
            },
            background: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade400, Colors.red.shade700],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Delete',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            // The actual music item content
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [Colors.grey[850]!, Colors.grey[800]!]
                      : [Colors.white, Colors.grey[50]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    // Corrected method call
                    await AudioPlayerManager().setPlaylist(allFiles, initialIndex: index);
                    AudioPlayerManager().play();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                spreadRadius: 1,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: hasThumb
                                ? Image.file(
                                    File(thumbPath),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => _buildFallbackIcon(isDark),
                                  )
                                : _buildFallbackIcon(isDark),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track?.title ?? formattedName, // Use Hive title if available
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.music_note,
                                    size: 14,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Local Music",
                                    style: GoogleFonts.poppins(
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _buildActionButton(
                          icon: Icons.playlist_add,
                          color: Theme.of(context).primaryColor,
                          onPressed: () => _addToPlaylist(file),
                        ),
                        const SizedBox(width: 8),
                        _buildActionButton(
                          icon: Icons.play_arrow_rounded,
                          color: Colors.green,
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            // Corrected method call
                            await AudioPlayerManager().setPlaylist(allFiles, initialIndex: index);
                            AudioPlayerManager().play();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildFallbackIcon(bool isDark) {
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
  
  Widget _buildActionButton({required IconData icon, required Color color, required VoidCallback onPressed}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? Colors.grey[700] : Colors.grey[200],
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.3),
            blurRadius: 3,
            offset: const Offset(0, 1),
          )
        ]
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeTransition(
      opacity: _animationController, // Use controller directly for fade
      child: Center(
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
                Icons.library_music_outlined,
                color: Theme.of(context).primaryColor.withOpacity(0.7),
                size: 60,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "Your Library is Empty",
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
                "Download songs from the search screen to add them here.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
     final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
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
            "Loading music library...",
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_mp3Files.isEmpty) {
      return _buildEmptyState();
    }

    return AnimationLimiter(
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: _mp3Files.length,
        itemBuilder: (context, index) {
          final file = _mp3Files[index];
          return _buildMusicItem(file, index, _mp3Files);
        },
      ),
    );
  }
}

