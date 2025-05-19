import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class MusicLibraryScreen extends StatefulWidget {
  const MusicLibraryScreen({Key? key}) : super(key: key);

  @override
  State<MusicLibraryScreen> createState() => _MusicLibraryScreenState();
}

class _MusicLibraryScreenState extends State<MusicLibraryScreen> {
  List<File> _mp3Files = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  File? _currentlyPlaying;

  @override
  void initState() {
    super.initState();
    _loadMusicFiles();
  }

  Future<void> _loadMusicFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final musicDir = Directory('${directory.path}/mp3s');
    print('Looking in: ${musicDir.path}');

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

      print('Found files: ${files.map((f) => f.path).toList()}');

      setState(() {
        _mp3Files = files;
      });
    } else {
      await musicDir.create(recursive: true);
    }
  }

  Future<void> _playFile(File file) async {
    try {
      await _audioPlayer.setFilePath(file.path);
      _audioPlayer.play();
      setState(() => _currentlyPlaying = file);
    } catch (e) {
      debugPrint('Error playing file: $e');
    }
  }

  Widget _buildMusicItem(File file) {
    final fileName = file.path.split('/').last;
    final isPlaying = _currentlyPlaying?.path == file.path;

    return ListTile(
      leading: Icon(
        isPlaying ? Icons.music_note : Icons.audiotrack,
        color: isPlaying ? Colors.green : Colors.grey[700],
      ),
      title: Text(
        fileName,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      trailing: IconButton(
        icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
        onPressed: () {
          if (isPlaying) {
            _audioPlayer.pause();
            setState(() => _currentlyPlaying = null);
          } else {
            _playFile(file);
          }
        },
      ),
      onTap: () => _playFile(file),
    );
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Downloads'), centerTitle: true),
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
                    (context, index) => _buildMusicItem(_mp3Files[index]),
              ),
    );
  }
}
