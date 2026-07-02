import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/app/brand.dart';
import 'package:iptv_player/src/domain/xtream_login.dart';

void main() {
  group('parseHexColor', () {
    test('RGB de 6 dígitos añade alfa FF', () {
      expect(parseHexColor('00A5FF'), const Color(0xFF00A5FF));
      expect(parseHexColor('#00A5FF'), const Color(0xFF00A5FF));
    });

    test('ARGB de 8 dígitos se respeta', () {
      expect(parseHexColor('CC112233'), const Color(0xCC112233));
    });

    test('inválido → null', () {
      expect(parseHexColor(''), isNull);
      expect(parseHexColor('rojo'), isNull);
      expect(parseHexColor('12345'), isNull);
    });
  });

  group('buildXtreamListUrl', () {
    test('construye get.php con credenciales codificadas', () {
      final url =
          buildXtreamListUrl('http://portal.acme.tv:8080', 'u 1', 'p&2');
      expect(url,
          'http://portal.acme.tv:8080/get.php?username=u+1&password=p%262&type=m3u_plus&output=ts');
    });

    test('añade esquema y quita barras finales', () {
      final url = buildXtreamListUrl('portal.acme.tv:8080///', 'u', 'p');
      expect(url, startsWith('http://portal.acme.tv:8080/get.php'));
    });
  });

  test('sin defines, la marca es la propia', () {
    expect(Brand.name, 'IPTV Player');
    expect(Brand.isWhiteLabel, isFalse);
    expect(Brand.accent, isNull);
  });
}
