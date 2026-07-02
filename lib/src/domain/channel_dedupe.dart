import 'media_item.dart';

String _key(String name) =>
    name.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

/// Colapsa canales duplicados (mismo nombre ignorando mayúsculas y espacios),
/// típicos de listas Xtream con feeds de respaldo repetidos. Conserva el
/// favorito si lo hay entre los duplicados; si no, el primero según el orden
/// recibido. Nombres distintos (p. ej. calidades "FHD"/"HD") no se tocan.
List<MediaItem> dedupeChannels(List<MediaItem> items) {
  final indexByKey = <String, int>{};
  final out = <MediaItem>[];
  for (final it in items) {
    final k = _key(it.name);
    final idx = indexByKey[k];
    if (idx == null) {
      indexByKey[k] = out.length;
      out.add(it);
    } else if (it.isFavorite && !out[idx].isFavorite) {
      out[idx] = it;
    }
  }
  return out;
}
