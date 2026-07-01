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
}
