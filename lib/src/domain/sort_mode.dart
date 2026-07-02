import 'media_item.dart';

/// Modo de ordenación del contenido dentro de una categoría.
enum SortMode {
  nameAsc('Nombre A-Z'),
  nameDesc('Nombre Z-A'),
  recent('Recién añadido'),
  favFirst('Favoritos primero'),
  custom('Personalizado');

  final String label;
  const SortMode(this.label);
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
