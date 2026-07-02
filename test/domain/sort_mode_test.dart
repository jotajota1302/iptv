import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/domain/content_type.dart';
import 'package:iptv_player/src/domain/media_item.dart';
import 'package:iptv_player/src/domain/sort_mode.dart';

MediaItem it(String name, {int added = 0, bool fav = false}) => MediaItem(
    id: name, name: name, streamUrl: 'u', type: ContentType.movie,
    addedAt: added, isFavorite: fav);

void main() {
  final items = [
    it('Beta', added: 100),
    it('alfa', added: 300),
    it('Gamma', added: 200),
  ];

  test('nameAsc ordena alfabéticamente ignorando mayúsculas', () {
    expect(sortItems(items, SortMode.nameAsc).map((e) => e.name),
        ['alfa', 'Beta', 'Gamma']);
  });

  test('nameDesc invierte el orden', () {
    expect(sortItems(items, SortMode.nameDesc).map((e) => e.name),
        ['Gamma', 'Beta', 'alfa']);
  });

  test('recent ordena por addedAt descendente', () {
    expect(sortItems(items, SortMode.recent).map((e) => e.name),
        ['alfa', 'Gamma', 'Beta']);
  });

  test('favFirst pone favoritos delante manteniendo el orden relativo', () {
    final list = [it('a'), it('b', fav: true), it('c'), it('d', fav: true)];
    expect(sortItems(list, SortMode.favFirst).map((e) => e.name),
        ['b', 'd', 'a', 'c']);
  });

  test('custom aplica el orden guardado; nuevos al final en su orden', () {
    final list = [it('a'), it('b'), it('c'), it('nuevo')];
    expect(
        sortItems(list, SortMode.custom, customOrder: ['c', 'a', 'b'])
            .map((e) => e.name),
        ['c', 'a', 'b', 'nuevo']);
  });

  test('custom sin orden guardado deja el orden del proveedor', () {
    expect(sortItems(items, SortMode.custom).map((e) => e.name),
        ['Beta', 'alfa', 'Gamma']);
    expect(
        sortItems(items, SortMode.custom, customOrder: const [])
            .map((e) => e.name),
        ['Beta', 'alfa', 'Gamma']);
  });
}
