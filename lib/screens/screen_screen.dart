import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mouzika/backend/youtube_downloader.dart';
import 'package:mouzika/screens/music_library_screen.dart';
import '../models/video_result.dart';
import '../services/api_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:mouzika/services/downloader.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<VideoResult> _results = [];
  bool _isLoading = false;
  String? _error;
  bool _isDarkMode = false;

  Future<String> storeMp3(Uint8List bytes, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$filename.mp3';
    final file = File(path);
    await file.writeAsBytes(bytes);
    return path;
  }

  Future<bool> _downloadAndSaveMp3(String videoUrlOrId, String fileName) async {
    try {
      final bytes = await YouTubeMp3PlayerService.convertVideoToMp3(
        videoUrlOrId,
      );

      final dir = await getApplicationDocumentsDirectory();
      final mp3Dir = Directory('${dir.path}/mp3s');

      if (!await mp3Dir.exists()) {
        await mp3Dir.create(recursive: true);
      }

      final sanitizedTitle = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${mp3Dir.path}/$sanitizedTitle.mp3');
      await file.writeAsBytes(bytes);

      debugPrint('Saved MP3 to: ${file.path}');
      return true;
    } catch (e) {
      debugPrint('Failed to download: $e');
      return false;
    }
  }

  Future<void> _searchVideos(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await ApiService.searchVideos(query);
      setState(() {
        _results = results;
      });
    } catch (e) {
      setState(() {
        _error = "Failed to fetch results. Please try again.";
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(_isDarkMode ? 0.1 : 0.2),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _controller,
          onSubmitted: _searchVideos,
          decoration: InputDecoration(
            filled: true,
            fillColor: _isDarkMode ? Colors.grey[800] : Colors.white,
            hintText: 'Search YouTube videos...',
            hintStyle: TextStyle(
              color: _isDarkMode ? Colors.grey[300] : Colors.grey[500],
            ),
            suffixIcon: Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  Icons.search,
                  color: _isDarkMode ? Colors.white : Colors.white,
                ),
                onPressed: () => _searchVideos(_controller.text),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(30),
              borderSide: BorderSide.none,
            ),
          ),
          style: TextStyle(
            fontSize: 16,
            color: _isDarkMode ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildResultItem(VideoResult video) {
    return Card(
      color: _isDarkMode ? Colors.grey[800] : Colors.white,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Play online functionality
          print('Play online tapped for ${video.title}');
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  video.thumbnailUrl,
                  width: 120,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (context, error, stackTrace) => Container(
                        width: 120,
                        height: 80,
                        color:
                            _isDarkMode ? Colors.grey[700] : Colors.grey[200],
                        child: Icon(
                          Icons.broken_image,
                          color: _isDarkMode ? Colors.grey[400] : Colors.grey,
                        ),
                      ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      video.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        color: _isDarkMode ? Colors.white : Colors.black,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      video.duration,
                      style: TextStyle(
                        color:
                            _isDarkMode ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.download,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      onPressed: () async {
                        final ok = await Downloader.downloadAndStore(video);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                ? 'Saved "${video.title}" to your library'
                                : 'Download failed – try again',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.play_arrow, color: Colors.green),
                    ),
                    onPressed: () {
                      // Same play functionality as tapping anywhere on the card
                      print('Play online tapped for ${video.title}');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultList() {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: CircularProgressIndicator(
            color: Theme.of(context).primaryColor,
          ),
        ),
      );
    } else if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: _isDarkMode ? Colors.red[300] : Colors.red[400],
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(
                  color: _isDarkMode ? Colors.grey[300] : Colors.grey[700],
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search,
              color: _isDarkMode ? Colors.grey[300] : Colors.grey[400],
              size: 72,
            ),
            const SizedBox(height: 16),
            Text(
              "Search for YouTube videos",
              style: TextStyle(
                color: _isDarkMode ? Colors.white : Colors.grey[600],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Results will appear here",
              style: TextStyle(
                color: _isDarkMode ? Colors.grey[400] : Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: _results.length,
      itemBuilder: (context, index) => _buildResultItem(_results[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      home: Scaffold(
        body: Column(
          children: [
            _buildSearchBar(),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildResultList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
