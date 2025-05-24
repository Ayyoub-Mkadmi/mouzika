import 'package:hive/hive.dart';

part 'track.g.dart';     // generated adapter

@HiveType(typeId: 0)
class Track extends HiveObject {
  @HiveField(0) String videoId;
  @HiveField(1) String title;
  @HiveField(2) String mp3Path;
  @HiveField(3) String thumbPath;
  @HiveField(4) String duration;

  Track({
    required this.videoId,
    required this.title,
    required this.mp3Path,
    required this.thumbPath,
    required this.duration,
  });
}

