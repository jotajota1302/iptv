import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/domain/content_type.dart';
import 'package:iptv_player/src/domain/media_item.dart';
import 'package:iptv_player/src/domain/series_group.dart';
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

  group('orden por año', () {
    final byYear = [
      it('Vieja (2001)'),
      it('Sin año'),
      it('Nueva (2020)'),
      it('Media (2010)'),
    ];

    test('yearDesc ordena de más nueva a más vieja, sin año al final', () {
      expect(sortItems(byYear, SortMode.yearDesc).map((e) => e.name),
          ['Nueva (2020)', 'Media (2010)', 'Vieja (2001)', 'Sin año']);
    });

    test('yearAsc ordena de más vieja a más nueva, sin año al final', () {
      expect(sortItems(byYear, SortMode.yearAsc).map((e) => e.name),
          ['Vieja (2001)', 'Media (2010)', 'Nueva (2020)', 'Sin año']);
    });
  });

  group('novedades (newest)', () {
    test('ordena por addedAt desc y desempata por año desc', () {
      final list = [
        it('Añadida antes (2000)', added: 500),
        it('Añadida después vieja (2005)', added: 100),
        it('Añadida después nueva (2024)', added: 100),
      ];
      expect(sortItems(list, SortMode.newest).map((e) => e.name), [
        'Añadida antes (2000)',
        'Añadida después nueva (2024)',
        'Añadida después vieja (2005)',
      ]);
    });

    test('con mismo addedAt, la que no tiene año va al final', () {
      final list = [
        it('Sin año', added: 100),
        it('Con año (2015)', added: 100),
      ];
      expect(sortItems(list, SortMode.newest).map((e) => e.name),
          ['Con año (2015)', 'Sin año']);
    });
  });

  group('sortSeriesGroups', () {
    SeriesGroup grp(String title, {int year = 0, int added = 0}) => SeriesGroup(
          title: title,
          seasons: {
            1: [
              Episode(
                item: MediaItem(
                    id: title,
                    name: year == 0 ? title : '$title ($year) S01E01',
                    streamUrl: 'u',
                    addedAt: added),
                season: 1,
                episode: 1,
              ),
            ],
          },
        );

    final groups = [
      grp('Beta', year: 2005),
      grp('alfa'),
      grp('Gamma', year: 2020),
    ];

    test('nameAsc ignora mayúsculas', () {
      expect(sortSeriesGroups(groups, SortMode.nameAsc).map((e) => e.title),
          ['alfa', 'Beta', 'Gamma']);
    });

    test('nameDesc invierte', () {
      expect(sortSeriesGroups(groups, SortMode.nameDesc).map((e) => e.title),
          ['Gamma', 'Beta', 'alfa']);
    });

    test('yearDesc: más nueva primero, sin año al final', () {
      expect(sortSeriesGroups(groups, SortMode.yearDesc).map((e) => e.title),
          ['Gamma', 'Beta', 'alfa']);
    });

    test('yearAsc: más vieja primero, sin año al final', () {
      expect(sortSeriesGroups(groups, SortMode.yearAsc).map((e) => e.title),
          ['Beta', 'Gamma', 'alfa']);
    });

    test('newest: por addedAt desc y desempate por año desc', () {
      final list = [
        grp('Antes', year: 2000, added: 500),
        grp('Después vieja', year: 2005, added: 100),
        grp('Después nueva', year: 2024, added: 100),
      ];
      expect(sortSeriesGroups(list, SortMode.newest).map((e) => e.title),
          ['Antes', 'Después nueva', 'Después vieja']);
    });
  });
}
