import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mouzika/services/audio_player_manager.dart';
import 'package:audio_service/audio_service.dart'; // Needed for MediaItem
import 'package:cached_network_image/cached_network_image.dart'; // For network images
import 'package:rxdart/rxdart.dart'; // Import rxdart

class MiniPlayerWidget extends StatefulWidget {
  final VoidCallback? onTap;

  const MiniPlayerWidget({super.key, this.onTap});

  @override
  State<MiniPlayerWidget> createState() => _MiniPlayerWidgetState();
}

class _MiniPlayerWidgetState extends State<MiniPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayerManager().audioPlayer;

  // Create a distinct stream for MediaItem changes
  Stream<MediaItem?> get _mediaItemStream =>
      _audioPlayer.sequenceStateStream
          .map((state) => state?.currentSource?.tag as MediaItem?)
          .distinct(); // Only emit when MediaItem changes

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    // Outer StreamBuilder listens only to MediaItem changes
    return StreamBuilder<MediaItem?>(
      stream: _mediaItemStream,
      builder: (context, mediaItemSnapshot) {
        final mediaItem = mediaItemSnapshot.data;

        // If there's no media item (nothing loaded), show nothing
        if (mediaItem == null) {
          return const SizedBox.shrink();
        }

        // Determine if the art URI is local file or network
        bool isLocalArt = mediaItem.artUri?.scheme == 'file';
        File? localArtFile;
        if (isLocalArt && mediaItem.artUri != null) {
          try {
            localArtFile = File.fromUri(mediaItem.artUri!);
            isLocalArt =
                localArtFile.existsSync(); // Check if file actually exists
          } catch (_) {
            isLocalArt = false; // Handle potential URI parsing errors
          }
        }

        // This part rebuilds only when MediaItem changes
        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            height: 65,
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                  width: 0.5,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Thumbnail (only rebuilds when mediaItem changes)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.0),
                  child: SizedBox(
                    width: 45,
                    height: 45,
                    child:
                        isLocalArt && localArtFile != null
                            ? Image.file(
                              localArtFile,
                              key: ValueKey(
                                mediaItem.artUri.toString(),
                              ), // Key to prevent unnecessary rebuilds
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stackTrace) =>
                                      _buildFallbackArt(primaryColor),
                            )
                            : mediaItem.artUri != null
                            ? CachedNetworkImage(
                              imageUrl: mediaItem.artUri.toString(),
                              key: ValueKey(
                                mediaItem.artUri.toString(),
                              ), // Key to prevent unnecessary rebuilds
                              fit: BoxFit.cover,
                              placeholder:
                                  (context, url) => _buildFallbackArt(
                                    primaryColor.withOpacity(0.5),
                                  ),
                              errorWidget:
                                  (context, url, error) =>
                                      _buildFallbackArt(primaryColor),
                            )
                            : _buildFallbackArt(primaryColor),
                  ),
                ),
                const SizedBox(width: 12),
                // Title (only rebuilds when mediaItem changes)
                Expanded(
                  child: Text(
                    mediaItem.title,
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
                // Play/Pause Button (listens to player state changes)
                StreamBuilder<PlayerState>(
                  stream: _audioPlayer.playerStateStream,
                  builder: (context, playerStateSnapshot) {
                    final playerState = playerStateSnapshot.data;
                    final processingState =
                        playerState?.processingState ?? ProcessingState.idle;
                    final playing = playerState?.playing ?? false;
                    final isBuffering =
                        processingState == ProcessingState.buffering ||
                        processingState == ProcessingState.loading;

                    // Don't show button if idle or error
                    if (processingState == ProcessingState.idle) {
                      return const SizedBox(width: 40); // Placeholder size
                    }

                    return IconButton(
                      iconSize: 32,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon:
                          isBuffering
                              ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: primaryColor,
                                ),
                              )
                              : Icon(
                                playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
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

  // Helper widget for fallback artwork
  Widget _buildFallbackArt(Color color) {
    return Container(
      width: 45,
      height: 45,
      color: color.withOpacity(0.3),
      child: Icon(Icons.music_note, color: color, size: 24),
    );
  }
}
