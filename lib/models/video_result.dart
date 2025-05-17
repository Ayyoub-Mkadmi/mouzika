class VideoResult {
  final String videoId;
  final String title;
  final String thumbnailUrl;
  final String duration;

  VideoResult({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
    required this.duration,
  });

  factory VideoResult.fromJson(Map<String, dynamic> json) {
    return VideoResult(
      videoId: json['videoId'],
      title: json['title'],
      thumbnailUrl: json['thumbnail'],
      duration: json['duration'],
    );
  }
}
