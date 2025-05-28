class Playlist {
  final String name;
  List<String> songs; // list of file paths

  Playlist({required this.name, required this.songs});

  // Serialize to JSON
  Map<String, dynamic> toJson() => {'name': name, 'songs': songs};

  // Deserialize from JSON
  factory Playlist.fromJson(Map<String, dynamic> json) =>
      Playlist(name: json['name'], songs: List<String>.from(json['songs']));
}
