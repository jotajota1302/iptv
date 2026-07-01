import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/domain/content_type.dart';
import 'package:iptv_player/src/domain/media_item.dart';

void main() {
  test('copyWith cambia solo isFavorite', () {
    const item = MediaItem(
      id: '1',
      name: 'Canal',
      streamUrl: 'http://x/1.ts',
      type: ContentType.live,
      groupTitle: 'Deportes',
    );
    final fav = item.copyWith(isFavorite: true);
    expect(fav.isFavorite, true);
    expect(fav.id, '1');
    expect(fav.name, 'Canal');
    expect(item.isFavorite, false);
  });
}
