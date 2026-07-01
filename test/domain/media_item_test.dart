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

  test('copyWith cambia isHidden e isDeleted de forma independiente', () {
    const item = MediaItem(id: '1', name: 'C', streamUrl: 'u');
    final hidden = item.copyWith(isHidden: true);
    expect(hidden.isHidden, true);
    expect(hidden.isDeleted, false);
    expect(hidden.isFavorite, false);
    final deleted = item.copyWith(isDeleted: true);
    expect(deleted.isDeleted, true);
    expect(deleted.isHidden, false);
  });
}
