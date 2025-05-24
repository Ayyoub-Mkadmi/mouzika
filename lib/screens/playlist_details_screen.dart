import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mouzika/screens/song_picker_screen.dart';
import 'package:mouzika/services/audio_player_manager.dart';
import 'package:path/path.dart' as p;
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

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  late Playlist _playlist;

  @override
  void initState() {
    super.initState();
    _playlist = widget.playlist;
  }

  void _removeSong(int index) {
    setState(() {
      _playlist.songs.removeAt(index);
    });
    widget.onPlaylistUpdated(_playlist);
  }

  Future<void> _addSongs() async {
    final selected = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (_) => const SongPickerScreen()),
    );

    if (selected != null && selected.isNotEmpty) {
      setState(() {
        _playlist.songs.addAll(
          selected.where((path) => !_playlist.songs.contains(path)),
        );
      });
      widget.onPlaylistUpdated(_playlist);
    }
  }

  void _playSong(int index) {
    final files = _playlist.songs.map((path) => File(path)).toList();
    AudioPlayerManager().setPlaylist(files, initialIndex: index);
    AudioPlayerManager().play();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addSongs,
            tooltip: 'Add Songs',
          ),
        ],
      ),
      body:
          _playlist.songs.isEmpty
              ? const Center(child: Text('No songs in this playlist.'))
              : ListView.builder(
                itemCount: _playlist.songs.length,
                itemBuilder: (context, index) {
                  final path = _playlist.songs[index];
                  final fileName = p.basename(path);

                  return ListTile(
                    leading: const Icon(Icons.music_note),
                    title: Text(fileName, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _removeSong(index),
                    ),
                    onTap: () => _playSong(index),
                  );
                },
              ),
    );
  }
}
