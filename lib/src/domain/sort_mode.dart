import 'media_item.dart';
import 'series_group.dart';

/// Modo de ordenación del contenido dentro de una categoría.
///
/// Nota: el índice de cada valor se persiste en prefs (canales y VOD), así que
/// los valores nuevos se añaden AL FINAL para no cambiar el orden guardado de
/// los usuarios existentes.
enum SortMode {
  nameAsc('Nombre A-Z'),
  nameDesc('Nombre Z-A'),
  recent('Recién añadido'),
  favFirst('Favoritos primero'),
  custom('Personalizado'),
  yearDesc('Año — nuevas primero'),
  yearAsc('Año — antiguas primero'),
  newest('Novedades');

  final String label;
  const SortMode(this.label);
}

/// Compara dos años poniendo el desconocido (0) siempre al final, sea cual sea
/// el sentido. Con ambos conocidos, [desc] elige de mayor a menor.
int _compareYear(int a, int b, {required bool desc}) {
  if (a == 0 && b == 0) return 0;
  if (a == 0) return 1; // a (sin año) va después
  if (b == 0) return -1; // b (sin año) va después
  return desc ? b.compareTo(a) : a.compareTo(b);
}

/// Devuelve una copia ordenada de [items] según [mode]. Para
/// [SortMode.custom], [customOrder] es la lista de ids guardada al arrastrar;
/// los canales que no estén en ella (nuevos) van al final en su orden
/// original. Sin orden guardado, se deja el orden del proveedor.
List<MediaItem> sortItems(List<MediaItem> items, SortMode mode,
    {List<String>? customOrder}) {
  final list = [...items];
  switch (mode) {
    case SortMode.nameAsc:
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case SortMode.nameDesc:
      list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    case SortMode.yearDesc:
      list.sort((a, b) => _compareYear(a.releaseYear, b.releaseYear, desc: true));
    case SortMode.yearAsc:
      list.sort(
          (a, b) => _compareYear(a.releaseYear, b.releaseYear, desc: false));
    case SortMode.newest:
      // Novedades: lo recién añadido a la lista primero; a igualdad (p. ej. la
      // primera importación, donde todo comparte fecha) desempata por año desc.
      list.sort((a, b) {
        final byAdded = b.addedAt.compareTo(a.addedAt);
        return byAdded != 0
            ? byAdded
            : _compareYear(a.releaseYear, b.releaseYear, desc: true);
      });
    case SortMode.recent:
      list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    case SortMode.favFirst:
      return [
        ...list.where((i) => i.isFavorite),
        ...list.where((i) => !i.isFavorite),
      ];
    case SortMode.custom:
      if (customOrder == null || customOrder.isEmpty) return list;
      final pos = {
        for (var i = 0; i < customOrder.length; i++) customOrder[i]: i,
      };
      final indexed = list.asMap().entries.toList();
      indexed.sort((a, b) {
        final pa = pos[a.value.id] ?? customOrder.length + a.key;
        final pb = pos[b.value.id] ?? customOrder.length + b.key;
        return pa.compareTo(pb);
      });
      return [for (final e in indexed) e.value];
  }
  return list;
}

/// Ordena series agrupadas. Solo aplica los modos de VOD (nombre y año); para
/// cualquier otro modo cae en Nombre A-Z. El año desconocido va al final.
List<SeriesGroup> sortSeriesGroups(List<SeriesGroup> groups, SortMode mode) {
  final list = [...groups];
  switch (mode) {
    case SortMode.nameDesc:
      list.sort(
          (a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
    case SortMode.yearDesc:
      list.sort((a, b) => _compareYear(a.year, b.year, desc: true));
    case SortMode.yearAsc:
      list.sort((a, b) => _compareYear(a.year, b.year, desc: false));
    case SortMode.newest:
      list.sort((a, b) {
        final byAdded = b.addedAt.compareTo(a.addedAt);
        return byAdded != 0
            ? byAdded
            : _compareYear(a.year, b.year, desc: true);
      });
    default:
      list.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }
  return list;
}
