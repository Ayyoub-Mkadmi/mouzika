import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mouzika/models/playlist.dart';
import 'package:mouzika/models/track.dart';
import 'package:mouzika/screens/playlist_details_screen.dart';

class PlaylistsSection extends StatelessWidget {
  final List<Playlist> playlists;
  final List<Track> tracks;
  final Function() onRefreshPlaylists;

  const PlaylistsSection({
    Key? key,
    required this.playlists,
    required this.tracks,
    required this.onRefreshPlaylists,
  }) : super(key: key);

  Widget _buildSectionTitle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color:
                  isDark
                      ? Colors.white
                      : Theme.of(
                        context,
                      ).primaryColor, // White in dark, purple in light
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Your Playlists',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistThumbnail(Playlist playlist, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Get first valid track in playlist for thumbnail
    if (playlist.songs.isNotEmpty) {
      for (final songPath in playlist.songs) {
        final track = tracks.firstWhere(
          (t) => t.mp3Path == songPath,
          orElse:
              () => Track(
                videoId: '',
                title: '',
                mp3Path: '',
                thumbPath: '',
                duration: '',
              ),
        );

        if (track.thumbPath.isNotEmpty) {
          final thumbFile = File(track.thumbPath);
          if (thumbFile.existsSync()) {
            return Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  thumbFile,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
            );
          }
        }
      }
    }

    // Fallback to default icon with gradient background
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isDark
                  ? [
                    Colors.grey[700]!,
                    Colors.grey[800]!,
                  ] // Grey gradient in dark mode
                  : [
                    Theme.of(context).primaryColor.withOpacity(0.7),
                    Theme.of(context).primaryColor,
                  ], // Purple gradient in light mode
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
                isDark
                    ? Colors.grey[700]!.withOpacity(0.3)
                    : Theme.of(context).primaryColor.withOpacity(
                      0.3,
                    ), // Adjusted shadow for dark mode
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.playlist_play, size: 50, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context),
        SizedBox(
          height: 200,
          child: AnimationLimiter(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: playlists.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final playlist = playlists[index];

                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 375),
                  child: SlideAnimation(
                    horizontalOffset: 50.0,
                    child: FadeInAnimation(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: InkWell(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => PlaylistDetailScreen(
                                      playlist: playlist,
                                      onPlaylistUpdated: (updated) {
                                        // Handle playlist update if needed
                                      },
                                    ),
                              ),
                            );
                            onRefreshPlaylists();
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPlaylistThumbnail(playlist, context),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: 120,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      playlist.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color:
                                            isDark
                                                ? Colors.white
                                                : Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      '${playlist.songs.length} song${playlist.songs.length != 1 ? 's' : ''}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color:
                                            isDark
                                                ? Colors.grey[400]
                                                : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
