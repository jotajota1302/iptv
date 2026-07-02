import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/data/vod_info_service.dart';

void main() {
  group('normalizeBackdrop', () {
    test('URL completa se respeta', () {
      expect(normalizeBackdrop('https://img.x/y.jpg'), 'https://img.x/y.jpg');
    });

    test('ruta relativa TMDB → URL completa', () {
      expect(normalizeBackdrop('/abc.jpg'),
          'https://image.tmdb.org/t/p/w1280/abc.jpg');
    });

    test('basura o vacío → null', () {
      expect(normalizeBackdrop(''), isNull);
      expect(normalizeBackdrop('   '), isNull);
      expect(normalizeBackdrop('no-es-url'), isNull);
      expect(normalizeBackdrop(null), isNull);
    });
  });

  test('parseVodInfo aplica la normalización al backdrop', () {
    final info = parseVodInfo({
      'info': {'backdrop_path': '/pelicula.jpg'},
    })!;
    expect(info.backdrop, 'https://image.tmdb.org/t/p/w1280/pelicula.jpg');
  });
}
