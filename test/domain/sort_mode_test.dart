import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/domain/content_type.dart';
import 'package:iptv_player/src/domain/media_item.dart';
import 'package:iptv_player/src/domain/sort_mode.dart';

MediaItem it(String name, {int added = 0}) => MediaItem(
    id: name, name: name, streamUrl: 'u', type: ContentType.movie,
    addedAt: added);

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
}
