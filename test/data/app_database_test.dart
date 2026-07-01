import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/data/app_database.dart';
import 'package:iptv_player/src/domain/content_type.dart';
import 'package:iptv_player/src/domain/media_item.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('replace + itemsByType + favoritos + search', () async {
    await db.replaceItems([
      const MediaItem(
          id: 'a',
          name: 'La 1',
          streamUrl: 'u1',
          groupTitle: 'Nacionales',
          type: ContentType.live),
      const MediaItem(
          id: 'b',
          name: 'Cine',
          streamUrl: 'u2',
          groupTitle: 'Cine',
          type: ContentType.movie),
    ]);
    final live = await db.itemsByType(ContentType.live);
    expect(live.length, 1);
    expect(live.first.name, 'La 1');

    await db.setFavorite('a', true);
    expect((await db.favorites()).single.id, 'a');

    final found = await db.search('la');
    expect(found.single.id, 'a');

    final cats = await db.categoriesByType(ContentType.live);
    expect(cats.single.name, 'Nacionales');
  });

  test('ocultar y borrar excluyen de navegacion pero no de gestion', () async {
    await db.replaceItems([
      const MediaItem(
          id: 'a', name: 'A', streamUrl: 'u1', type: ContentType.live),
      const MediaItem(
          id: 'b', name: 'B', streamUrl: 'u2', type: ContentType.live),
      const MediaItem(
          id: 'c', name: 'C', streamUrl: 'u3', type: ContentType.live),
    ]);
    await db.setHidden('a', true);
    await db.setDeleted('b', true);

    final visible = await db.itemsByType(ContentType.live);
    expect(visible.map((e) => e.id), ['c']);

    final all = await db.manageableByType(ContentType.live);
    expect(all.length, 3);
    expect(all.firstWhere((e) => e.id == 'a').isHidden, true);
    expect(all.firstWhere((e) => e.id == 'b').isDeleted, true);

    await db.restore('a');
    await db.restore('b');
    final visible2 = await db.itemsByType(ContentType.live);
    expect(visible2.length, 3);
  });

  test('replaceItems preserva favorito/oculto/borrado por id', () async {
    await db.replaceItems([
      const MediaItem(
          id: 'a', name: 'A', streamUrl: 'u1', type: ContentType.live),
    ]);
    await db.setFavorite('a', true);
    await db.setHidden('a', true);

    // Recarga de la lista: el mismo id vuelve con flags "limpios".
    await db.replaceItems([
      const MediaItem(
          id: 'a', name: 'A nuevo', streamUrl: 'u1', type: ContentType.live),
      const MediaItem(
          id: 'z', name: 'Z', streamUrl: 'u9', type: ContentType.live),
    ]);
    final all = await db.manageableByType(ContentType.live);
    final a = all.firstWhere((e) => e.id == 'a');
    expect(a.isFavorite, true, reason: 'favorito preservado');
    expect(a.isHidden, true, reason: 'oculto preservado');
    expect(a.name, 'A nuevo', reason: 'datos actualizados');
  });
}
