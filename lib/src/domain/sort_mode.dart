import 'media_item.dart';

/// Modo de ordenación del contenido dentro de una categoría.
enum SortMode {
  nameAsc('Nombre A-Z'),
  nameDesc('Nombre Z-A'),
  recent('Recién añadido');

  final String label;
  const SortMode(this.label);
}

/// Devuelve una copia ordenada de [items] según [mode].
List<MediaItem> sortItems(List<MediaItem> items, SortMode mode) {
  final list = [...items];
  switch (mode) {
    case SortMode.nameAsc:
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case SortMode.nameDesc:
      list.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
    case SortMode.recent:
      list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
  }
  return list;
}
