import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mouzika/services/audio_player_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist.dart';

class MusicLibraryScreen extends StatefulWidget {
  const MusicLibraryScreen({Key? key}) : super(key: key);

  @override
  State<MusicLibraryScreen> createState() => _MusicLibraryScreenState();
}

class _MusicLibraryScreenState extends State<MusicLibraryScreen> {
  List<File> _mp3Files = [];
  List<Playlist> _playlists = [];

  @override
  void initState() {
    super.initState();
    _loadMusicFiles();
    _loadPlaylists();
  }

  Future<void> _loadMusicFiles() async {
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
      setState(() {
        _mp3Files = files;
      });
    } else {
      await musicDir.create(recursive: true);
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

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) =>
              _playlists.isEmpty
                  ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No playlists available.'),
                  )
                  : ListView(
                    shrinkWrap: true,
                    children:
                        _playlists.map((playlist) {
                          return ListTile(
                            title: Text(playlist.name),
                            onTap: () {
                              setState(() {
                                if (!playlist.songs.contains(filePath)) {
                                  playlist.songs.add(filePath);
                                }
                              });
                              _savePlaylists();
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Added to "${playlist.name}"'),
                                ),
                              );
                            },
                          );
                        }).toList(),
                  ),
    );
  }

  Widget _buildMusicItem(File file, int index, List<File> allFiles) {
    final fileName = file.path.split('/').last;

    return ListTile(
      leading: const Icon(Icons.audiotrack),
      title: Text(
        fileName,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        onSelected: (value) {
          if (value == 'add') {
            _addToPlaylist(file);
          }
        },
        itemBuilder:
            (context) => [
              const PopupMenuItem<String>(
                value: 'add',
                child: Text('Add to Playlist'),
              ),
            ],
      ),
      onTap: () async {
        await AudioPlayerManager().setPlaylist(allFiles, initialIndex: index);
        AudioPlayerManager().play();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _mp3Files.isEmpty
              ? const Center(
                child: Text(
                  'No downloaded music found.',
                  style: TextStyle(fontSize: 16),
                ),
              )
              : ListView.builder(
                itemCount: _mp3Files.length,
                itemBuilder:
                    (context, index) =>
                        _buildMusicItem(_mp3Files[index], index, _mp3Files),
              ),
    );
  }
}
