import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/domain/content_type.dart';
import 'package:iptv_player/src/domain/media_item.dart';
import 'package:iptv_player/src/data/content_classifier.dart';

MediaItem item(String url, {String? group}) =>
    MediaItem(id: url, name: 'x', streamUrl: url, groupTitle: group);

void main() {
  test('clasifica por segmento de URL', () {
    expect(classifyItem(item('http://h/live/u/p/1.ts')).type, ContentType.live);
    expect(
        classifyItem(item('http://h/movie/u/p/2.mkv')).type, ContentType.movie);
    expect(classifyItem(item('http://h/series/u/p/3.mp4')).type,
        ContentType.series);
  });

  test('.ts sin segmento es live', () {
    expect(classifyItem(item('http://h/u/p/1001.ts')).type, ContentType.live);
  });

  test('fallback por group-title', () {
    expect(classifyItem(item('http://h/x', group: 'Cine Accion')).type,
        ContentType.movie);
    expect(classifyItem(item('http://h/x', group: 'Series VIP')).type,
        ContentType.series);
  });
}
