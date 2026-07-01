import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:iptv_player/src/data/app_database.dart';
import 'package:iptv_player/src/data/m3u_source.dart';
import 'package:iptv_player/src/data/playlist_repository.dart';
import 'package:iptv_player/src/domain/content_type.dart';

class _MockSource extends Mock implements M3uSource {}

const _m3u = '''
#EXTM3U
#EXTINF:-1 group-title="Nacionales",La 1
http://h/live/u/p/1.ts
#EXTINF:-1 group-title="Cine",Peli
http://h/movie/u/p/2.mkv
''';

void main() {
  test('loadFromUrl parsea, clasifica y cachea', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final source = _MockSource();
    when(() => source.fetchFromUrl(any())).thenAnswer((_) async => _m3u);
    final repo = PlaylistRepository(source, db);

    final count = await repo.loadFromUrl('http://x');
    expect(count, 2);

    final cats = await repo.liveCategories();
    expect(cats.single.name, 'Nacionales');
    final live = await repo.liveByCategory('Nacionales');
    expect(live.single.type, ContentType.live);
    await db.close();
  });

  test('hideItem oculta de navegacion pero sigue en gestion', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final source = _MockSource();
    when(() => source.fetchFromUrl(any())).thenAnswer((_) async => _m3u);
    final repo = PlaylistRepository(source, db);
    await repo.loadFromUrl('http://x');

    final canal = (await repo.liveByCategory('Nacionales')).single;
    await repo.hideItem(canal);

    expect(await repo.liveByCategory('Nacionales'), isEmpty);
    final gestion = await repo.manageLiveByCategory('Nacionales');
    expect(gestion.single.isHidden, true);

    await repo.restoreItem(canal);
    expect((await repo.liveByCategory('Nacionales')).length, 1);
    await db.close();
  });

  test('hideCategory oculta toda la categoria y restoreCategory la recupera',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final source = _MockSource();
    when(() => source.fetchFromUrl(any())).thenAnswer((_) async => _m3u);
    final repo = PlaylistRepository(source, db);
    await repo.loadFromUrl('http://x');
    // _m3u tiene 1 canal live en "Nacionales".
    expect((await repo.liveByCategory('Nacionales')).length, 1);

    await repo.hideCategory('Nacionales');
    expect(await repo.liveByCategory('Nacionales'), isEmpty);
    // La categoria desaparece de la navegacion.
    expect(await repo.liveCategories(), isEmpty);

    await repo.restoreCategory('Nacionales');
    expect((await repo.liveByCategory('Nacionales')).length, 1);
    await db.close();
  });
}
