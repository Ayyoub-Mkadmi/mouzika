import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mouzika/models/track.dart';
import 'package:mouzika/services/audio_player_manager.dart';
import 'package:hive/hive.dart';
import 'package:audio_service/audio_service.dart';

class MiniPlayerWidget extends StatefulWidget {
  final VoidCallback? onTap;

  const MiniPlayerWidget({Key? key, this.onTap}) : super(key: key);

  @override
  State<MiniPlayerWidget> createState() => _MiniPlayerWidgetState();
}

class _MiniPlayerWidgetState extends State<MiniPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayerManager().audioPlayer;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final trackBox = Hive.box<Track>('tracks');

    return StreamBuilder<SequenceState?>(
      stream: _audioPlayer.sequenceStateStream,
      builder: (context, sequenceSnapshot) {
        final sequenceState = sequenceSnapshot.data;
        final currentSource = sequenceState?.currentSource;
        Track? currentTrack;
        String? mp3Path;

        if (currentSource?.tag != null) {
          if (currentSource!.tag is MediaItem) {
            mp3Path = (currentSource.tag as MediaItem).id;
          } else if (currentSource.tag is String) {
            mp3Path = currentSource.tag as String;
          }
        }

        if (mp3Path != null) {
          currentTrack = trackBox.values.firstWhere(
            (t) => t.mp3Path == mp3Path,
            orElse: () {
              final fileName = mp3Path!.split('/').last;
              final songName = fileName.replaceAll(RegExp(r'\.\w+$'), '').replaceAll('_', ' ');
              return Track(
                videoId: '',
                title: songName,
                mp3Path: mp3Path!,
                thumbPath: '',
                duration: '',
              );
            },
          );
        }

        if (currentTrack == null) {
          return const SizedBox.shrink();
        }

        final thumbFile = File(currentTrack.thumbPath);
        final hasThumb = currentTrack.thumbPath.isNotEmpty && thumbFile.existsSync();

        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            height: 65,
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.0),
                  child: hasThumb
                      ? Image.file(
                          thumbFile,
                          width: 45,
                          height: 45,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 45,
                          height: 45,
                          color: primaryColor.withOpacity(0.3),
                          child: Icon(
                            Icons.music_note,
                            color: primaryColor,
                            size: 24,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                // Title
                Expanded(
                  child: Text(
                    currentTrack.title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                // Play/Pause Button
                StreamBuilder<PlayerState>(
                  stream: _audioPlayer.playerStateStream,
                  builder: (context, playerStateSnapshot) {
                    final playerState = playerStateSnapshot.data;
                    final processingState =
                        playerState?.processingState ?? ProcessingState.idle;
                    final playing = playerState?.playing ?? false;
                    final isBuffering = processingState == ProcessingState.buffering;

                    return IconButton(
                      iconSize: 32,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: isBuffering
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: primaryColor,
                              ),
                            )
                          : Icon(
                              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: primaryColor,
                            ),
                      onPressed: () {
                        if (playing) {
                          _audioPlayer.pause();
                        } else {
                          _audioPlayer.play();
                        }
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

