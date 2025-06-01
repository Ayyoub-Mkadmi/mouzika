import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/video_result.dart';
import './action_button_widget.dart';

class SearchResultItem extends StatelessWidget {
  final VideoResult video;
  final int index;
  final Function(VideoResult) onDownload;
  final Function(VideoResult) onPlay;

  const SearchResultItem({
    super.key,
    required this.video,
    required this.index,
    required this.onDownload,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimationConfiguration.staggeredList(
      position: index,
      duration: const Duration(milliseconds: 450),
      child: SlideAnimation(
        verticalOffset: 50.0,
        child: FadeInAnimation(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    isDark
                        ? [Colors.grey[850]!, Colors.grey[800]!]
                        : [Colors.white, Colors.grey[50]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color:
                      isDark
                          ? Colors.black.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onPlay(video),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Hero(
                        tag: 'thumbnail_${video.videoId}',
                        child: Container(
                          width: 130,
                          height: 85,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                spreadRadius: 1,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  video.thumbnailUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) => Container(
                                        color:
                                            isDark
                                                ? Colors.grey[700]
                                                : Colors.grey[200],
                                        child: Icon(
                                          Icons.broken_image,
                                          color:
                                              isDark
                                                  ? Colors.grey[400]
                                                  : Colors.grey,
                                        ),
                                      ),
                                ),
                                Positioned(
                                  bottom: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      video.duration,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              video.title,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.music_note,
                                  size: 14,
                                  color:
                                      isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "YouTube Music",
                                  style: GoogleFonts.poppins(
                                    color:
                                        isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ActionButtonWidget(
                            icon: Icons.download_rounded,
                            color: Theme.of(context).primaryColor,
                            onPressed: () => onDownload(video),
                          ),
                          const SizedBox(height: 10),
                          ActionButtonWidget(
                            icon: Icons.play_arrow_rounded,
                            color: Colors.green,
                            onPressed: () => onPlay(video),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
