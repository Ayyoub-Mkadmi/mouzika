import 'package:flutter/material.dart';
import '../models/video_result.dart';
import '../services/api_service.dart';

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

  void _toggleDarkMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
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
                  IconButton(
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
                    onPressed: () {
                      // Download functionality
                      print('Download tapped for ${video.title}');
                    },
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
      debugShowCheckedModeBanner: false, // This removes the debug banner
      theme:
          _isDarkMode
              ? ThemeData.dark().copyWith(
                primaryColor: Colors.deepPurple,
                primaryColorDark: Colors.deepPurple[800],
                cardColor: Colors.grey[850],
                hintColor: Colors.grey[400],
                scaffoldBackgroundColor: Colors.grey[900],
              )
              : ThemeData.light().copyWith(
                primaryColor: Colors.blue,
                primaryColorDark: Colors.blue[800],
                cardColor: Colors.white,
                hintColor: Colors.grey[600],
                scaffoldBackgroundColor: Colors.grey[100],
              ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text(
            "♥__La9liwa__♥",
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          elevation: 0,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColorDark,
                ],
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isDarkMode ? Icons.light_mode : Icons.dark_mode,
                color: Colors.white,
              ),
              onPressed: _toggleDarkMode,
            ),
          ],
        ),
        body: Column(
          children: [
            _buildSearchBar(),
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
