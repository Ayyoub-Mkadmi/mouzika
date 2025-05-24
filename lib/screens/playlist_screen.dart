import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mouzika/screens/playlist_details_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  List<Playlist> _playlists = [];

  @override
  void initState() {
    super.initState();
    _loadPlaylists();
  }

  Future<void> _loadPlaylists() async {
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

  void _createPlaylist() async {
    final nameController = TextEditingController();

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Create Playlist'),
            content: TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: 'Playlist name'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isNotEmpty) {
                    final newPlaylist = Playlist(name: name, songs: []);
                    setState(() {
                      _playlists.add(newPlaylist);
                    });
                    _savePlaylists();
                  }
                  Navigator.pop(context);
                },
                child: const Text('Create'),
              ),
            ],
          ),
    );
  }

  void _navigateToDetail(Playlist playlist, int index) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => PlaylistDetailScreen(
              playlist: playlist,
              onPlaylistUpdated: (updated) {
                setState(() {
                  _playlists[index] = updated;
                });
                _savePlaylists();
              },
            ),
      ),
    );
  }

  void _deletePlaylist(int index) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete Playlist'),
            content: const Text(
              'Are you sure you want to delete this playlist?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _playlists.removeAt(index);
                  });
                  _savePlaylists();
                  Navigator.pop(context);
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _createPlaylist),
        ],
      ),
      body:
          _playlists.isEmpty
              ? const Center(child: Text('No playlists found.'))
              : ListView.builder(
                itemCount: _playlists.length,
                itemBuilder: (context, index) {
                  final playlist = _playlists[index];
                  return ListTile(
                    leading: const Icon(Icons.playlist_play),
                    title: Text(playlist.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deletePlaylist(index),
                    ),
                    onTap: () => _navigateToDetail(playlist, index),
                  );
                },
              ),
    );
  }
}
