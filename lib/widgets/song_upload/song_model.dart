class Song {
  final String name;
  final String url;
  final String id;

  Song({required this.name, required this.url, required this.id});

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      name: json['name'] ?? '',
      url: json["url"] ?? '',
      id: json["_id"],
    );
  }
}
