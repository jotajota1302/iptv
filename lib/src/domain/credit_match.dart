import '../data/tmdb_service.dart';
import 'content_type.dart';
import 'media_item.dart';

String _norm(String s) => cleanMediaTitle(s)
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9áéíóúüñ]+'), ' ')
    .trim();

/// Elige entre [candidates] (resultado de buscar el título del crédito en la
/// BD) el elemento del catálogo que corresponde a [credit].
///
/// Películas: igualdad de título normalizado, o un único candidato por
/// prefijo (el proveedor suele añadir año o etiquetas). Series: los items
/// son episodios ("Serie S01 E01"), así que vale el primero cuyo nombre
/// empiece por el título — sirve de puerta de entrada a la ficha de la serie.
MediaItem? pickCatalogMatch(List<MediaItem> candidates, TmdbCredit credit) {
  final want =
      credit.mediaType == 'movie' ? ContentType.movie : ContentType.series;
  final t = _norm(credit.title);
  if (t.isEmpty) return null;
  final typed = candidates.where((c) => c.type == want).toList();

  if (want == ContentType.series) {
    for (final c in typed) {
      final n = _norm(c.name);
      if (n == t || n.startsWith('$t ')) return c;
    }
    return null;
  }

  for (final c in typed) {
    if (_norm(c.name) == t) return c;
  }
  final byPrefix = typed.where((c) {
    final n = _norm(c.name);
    return n.startsWith('$t ') || t.startsWith('$n ');
  }).toList();
  return byPrefix.length == 1 ? byPrefix.first : null;
}
