import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/domain/trailer_url.dart';

void main() {
  test('id de YouTube → URL de watch', () {
    expect(trailerUrl('dQw4w9WgXcQ'),
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
  });

  test('URL completa se respeta', () {
    expect(trailerUrl('https://youtu.be/x'), 'https://youtu.be/x');
  });

  test('vacío o null → null', () {
    expect(trailerUrl(''), isNull);
    expect(trailerUrl('  '), isNull);
    expect(trailerUrl(null), isNull);
  });
}
