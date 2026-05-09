class VideoResult {
  final String videoId;
  final String title;
  final String thumbnailUrl;
  final String duration;
  final String channelTitle;

  VideoResult({
    required this.videoId,
    required this.title,
    required this.thumbnailUrl,
    required this.duration,
    this.channelTitle = '',
  });

  factory VideoResult.fromJson(Map<String, dynamic> json) {
    return VideoResult(
      videoId: json['videoId'] ?? '',
      title: json['title'] ?? '',
      thumbnailUrl: json['thumbnail'] ?? '',
      duration: json['duration'] ?? '0:00',
      channelTitle: json['channelTitle'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'videoId': videoId,
    'title': title,
    'thumbnail': thumbnailUrl,
    'duration': duration,
    'channelTitle': channelTitle,
  };
}
