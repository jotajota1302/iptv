import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/domain/channel_dedupe.dart';
import 'package:iptv_player/src/domain/content_type.dart';
import 'package:iptv_player/src/domain/media_item.dart';

MediaItem ch(String id, String name, {bool fav = false}) => MediaItem(
    id: id,
    name: name,
    streamUrl: 'u/$id',
    type: ContentType.live,
    isFavorite: fav);

void main() {
  test('colapsa canales con el mismo nombre y conserva el primero', () {
    final out = dedupeChannels([
      ch('1', '24H'),
      ch('2', '24h'),
      ch('3', '24H '),
      ch('4', 'La 1'),
      ch('5', '24H'),
    ]);
    expect(out.map((e) => e.id), ['1', '4']);
  });

  test('si hay un duplicado favorito, se queda ese', () {
    final out = dedupeChannels([
      ch('1', '24H'),
      ch('2', '24H', fav: true),
    ]);
    expect(out.single.id, '2');
  });

  test('nombres distintos (calidades) no se tocan', () {
    final out = dedupeChannels([
      ch('1', 'La 1 FHD'),
      ch('2', 'La 1 HD'),
      ch('3', 'La 1'),
    ]);
    expect(out, hasLength(3));
  });

  test('normaliza espacios múltiples', () {
    final out = dedupeChannels([
      ch('1', 'Canal  24'),
      ch('2', 'canal 24'),
    ]);
    expect(out.single.id, '1');
  });
}
