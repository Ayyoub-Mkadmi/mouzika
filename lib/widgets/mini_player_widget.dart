import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mouzika/models/track.dart';
import 'package:mouzika/services/audio_player_manager.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';

class MiniPlayerWidget extends StatelessWidget {
  final VoidCallback? onTap;

  const MiniPlayerWidget({Key? key, this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final audioPlayer = AudioPlayerManager().audioPlayer;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final trackBox = Hive.box<Track>('tracks');

    return StreamBuilder<SequenceState?>(
      stream: audioPlayer.sequenceStateStream,
      builder: (context, sequenceSnapshot) {
        final sequenceState = sequenceSnapshot.data;
        final currentSource = sequenceState?.currentSource;
        Track? currentTrack;

        if (currentSource != null && currentSource.tag is String) {
          // Assuming tag is the mp3Path
          final mp3Path = currentSource.tag as String;
          currentTrack = trackBox.values.firstWhere(
            (t) => t.mp3Path == mp3Path,
            orElse: () {
              // Fallback if track not found in Hive (e.g., directly played file)
              final fileName = mp3Path.split('/').last;
              final songName = fileName.replaceAll(RegExp(r'\.\w+$'), '').replaceAll('_', ' ');
              return Track(
                videoId: '', // Or extract if possible
                title: songName,
                mp3Path: mp3Path,
                thumbPath: '',
                duration: '',
              );
            },
          );
        }

        if (currentTrack == null) {
          // Return an empty container or placeholder if no track is playing
          return const SizedBox.shrink(); 
        }

        final thumbFile = File(currentTrack.thumbPath);
        final hasThumb = currentTrack.thumbPath.isNotEmpty && thumbFile.existsSync();

        return GestureDetector(
          onTap: onTap,
          child: Container(
            height: 65, // Mini-player height
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
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
                  stream: audioPlayer.playerStateStream,
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
                          audioPlayer.pause();
                        } else {
                          audioPlayer.play();
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
