import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mouzika/models/track.dart';
import 'package:mouzika/services/audio_player_manager.dart';

class RecentlyPlayedSection extends StatelessWidget {
  final List<Track> tracks;
  final Function() onRefreshTracks;

  const RecentlyPlayedSection({
    Key? key,
    required this.tracks,
    required this.onRefreshTracks,
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
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Recently Played',
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

  Widget _buildThumbnailWidget(Track track, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (track.thumbPath.isNotEmpty) {
      final thumbFile = File(track.thumbPath);
      if (thumbFile.existsSync()) {
        return Hero(
          tag: 'track_${track.videoId}',
          child: Container(
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
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      }
    }
    
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        Icons.music_note,
        size: 40,
        color: isDark ? Colors.grey[300] : Colors.grey[600],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) return const SizedBox.shrink();
    
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
              itemCount: tracks.length,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final track = tracks[index];
                
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
                            final playlist = tracks
                                .where((t) => File(t.mp3Path).existsSync())
                                .map((t) => File(t.mp3Path))
                                .toList();
                            await AudioPlayerManager().setPlaylist(playlist, initialIndex: index);
                            AudioPlayerManager().play();
                            onRefreshTracks();
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildThumbnailWidget(track, context),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: 120,
                                child: Text(
                                  track.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
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
