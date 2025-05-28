// song_picker_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class SongPickerScreen extends StatefulWidget {
  const SongPickerScreen({super.key});

  @override
  State<SongPickerScreen> createState() => _SongPickerScreenState();
}

class _SongPickerScreenState extends State<SongPickerScreen> {
  List<File> _songs = [];
  Set<String> _selectedPaths = {};

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    final directory = await getApplicationDocumentsDirectory();
    final musicDir = Directory('${directory.path}/mp3s');

    if (await musicDir.exists()) {
      final files =
          musicDir
              .listSync()
              .where((file) => file is File && file.path.endsWith('.mp3'))
              .cast<File>()
              .toList();
      setState(() {
        _songs = files;
      });
    }
  }

  void _toggleSelection(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  void _submitSelection() {
    Navigator.pop(context, _selectedPaths.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Songs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _submitSelection,
          ),
        ],
      ),
      body:
          _songs.isEmpty
              ? const Center(child: Text('No songs found.'))
              : ListView.builder(
                itemCount: _songs.length,
                itemBuilder: (context, index) {
                  final file = _songs[index];
                  final fileName = file.path.split('/').last;
                  final selected = _selectedPaths.contains(file.path);

                  return ListTile(
                    leading: Icon(
                      selected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: selected ? Colors.green : null,
                    ),
                    title: Text(fileName, overflow: TextOverflow.ellipsis),
                    onTap: () => _toggleSelection(file.path),
                  );
                },
              ),
    );
  }
}
