/// Una lista IPTV guardada por el usuario (nombre + URL).
class SavedPlaylist {
  final String id;
  final String name;
  final String url;

  const SavedPlaylist({required this.id, required this.name, required this.url});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'url': url};

  factory SavedPlaylist.fromJson(Map<String, dynamic> j) => SavedPlaylist(
        id: j['id'] as String,
        name: j['name'] as String,
        url: j['url'] as String,
      );
}
