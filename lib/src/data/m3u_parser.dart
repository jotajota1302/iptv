import '../domain/content_type.dart';
import '../domain/media_item.dart';

final _attrRegex = RegExp(r'([\w-]+)="(.*?)"');

List<MediaItem> parseM3u(String content) {
  final lines = content.split(RegExp(r'\r?\n'));
  final items = <MediaItem>[];
  String? name, tvgId, logo, group;
  var pendingInfo = false;

  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#EXTINF')) {
      final attrs = {for (final m in _attrRegex.allMatches(line)) m[1]!: m[2]!};
      tvgId = (attrs['tvg-id']?.isEmpty ?? true) ? null : attrs['tvg-id'];
      logo = (attrs['tvg-logo']?.isEmpty ?? true) ? null : attrs['tvg-logo'];
      group =
          (attrs['group-title']?.isEmpty ?? true) ? null : attrs['group-title'];
      final commaIdx = line.lastIndexOf(',');
      name = commaIdx >= 0 ? line.substring(commaIdx + 1).trim() : 'Sin nombre';
      pendingInfo = true;
    } else if (line.startsWith('#')) {
      continue;
    } else if (pendingInfo) {
      items.add(MediaItem(
        id: line.hashCode.toString(),
        name: name ?? 'Sin nombre',
        streamUrl: line,
        logoUrl: logo,
        tvgId: tvgId,
        groupTitle: group,
        type: ContentType.unknown,
      ));
      pendingInfo = false;
      name = tvgId = logo = group = null;
    }
  }
  return items;
}
