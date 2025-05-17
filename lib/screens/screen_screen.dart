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

  Future<void> _searchVideos(String query) async {
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
      child: TextField(
        controller: _controller,
        onSubmitted: _searchVideos,
        decoration: InputDecoration(
          hintText: 'Search YouTube videos',
          suffixIcon: IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _searchVideos(_controller.text),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildResultList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      return Center(child: Text(_error!));
    } else if (_results.isEmpty) {
      return const Center(child: Text("No results yet."));
    }

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final video = _results[index];
        return ListTile(
          leading: Image.network(
            video.thumbnailUrl,
            width: 100,
            fit: BoxFit.cover,
          ),
          title: Text(video.title),
          subtitle: Text(video.duration),
          onTap: () {
            // To be handled in download screen (Phase 3)
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("YouTube MP3 Search")),
      body: Column(
        children: [_buildSearchBar(), Expanded(child: _buildResultList())],
      ),
    );
  }
}
