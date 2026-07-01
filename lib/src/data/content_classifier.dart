import '../domain/content_type.dart';
import '../domain/media_item.dart';

MediaItem classifyItem(MediaItem item) {
  final url = item.streamUrl.toLowerCase();
  final group = (item.groupTitle ?? '').toLowerCase();
  ContentType type;
  if (url.contains('/series/')) {
    type = ContentType.series;
  } else if (url.contains('/movie/') ||
      url.endsWith('.mkv') ||
      url.endsWith('.mp4') ||
      url.endsWith('.avi')) {
    type = ContentType.movie;
  } else if (url.contains('/live/') ||
      url.endsWith('.ts') ||
      url.endsWith('.m3u8')) {
    type = ContentType.live;
  } else if (group.contains('serie')) {
    type = ContentType.series;
  } else if (group.contains('cine') ||
      group.contains('pelicula') ||
      group.contains('vod') ||
      group.contains('movie')) {
    type = ContentType.movie;
  } else {
    type = ContentType.live;
  }
  return MediaItem(
    id: item.id,
    name: item.name,
    streamUrl: item.streamUrl,
    logoUrl: item.logoUrl,
    tvgId: item.tvgId,
    groupTitle: item.groupTitle,
    type: type,
    isFavorite: item.isFavorite,
  );
}

List<MediaItem> classifyAll(List<MediaItem> items) =>
    items.map(classifyItem).toList();
