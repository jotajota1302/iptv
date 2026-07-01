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
}
