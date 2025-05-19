// music_library_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mouzika/services/audio_player_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'now_playing_screen.dart';

class MusicLibraryScreen extends StatefulWidget {
  const MusicLibraryScreen({Key? key}) : super(key: key);

  @override
  State<MusicLibraryScreen> createState() => _MusicLibraryScreenState();
}

class _MusicLibraryScreenState extends State<MusicLibraryScreen> {
  List<File> _mp3Files = [];

  @override
  void initState() {
    super.initState();
    _loadMusicFiles();
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

  Widget _buildMusicItem(File file, int index, List<File> allFiles) {
    final fileName = file.path.split('/').last;

    return ListTile(
      leading: Icon(Icons.audiotrack, color: Colors.grey[700]),
      title: Text(
        fileName,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      onTap: () async {
        // Set the playlist with all files and the tapped index
        await AudioPlayerManager().setPlaylist(allFiles, initialIndex: index);

        // Start playing the selected song
        AudioPlayerManager().play();

        // Navigate to NowPlayingScreen
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => NowPlayingScreen()),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: const Text('My Downloads'), centerTitle: true),
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
