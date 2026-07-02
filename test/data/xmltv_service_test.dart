import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/data/xmltv_service.dart';

const _sample = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="La1.es">
    <display-name>La 1</display-name>
  </channel>
  <channel id="24h.es">
    <display-name>24 Horas</display-name>
  </channel>
  <programme start="20260702120000 +0200" stop="20260702130000 +0200" channel="La1.es">
    <title lang="es">Telediario 1</title>
    <desc>Informativo de mediodía.</desc>
  </programme>
  <programme start="20260702130000 +0200" stop="20260702143000 +0200" channel="La1.es">
    <title>Sesión de tarde</title>
  </programme>
  <programme start="20260702120000 +0200" stop="20260702140000 +0200" channel="24h.es">
    <title>Noticias 24H</title>
  </programme>
</tv>
''';

void main() {
  group('buildXmltvUrl', () {
    test('deriva xmltv.php de la URL de la lista (get.php)', () {
      final url = buildXmltvUrl(
          'http://host.tv:8080/get.php?username=u1&password=p1&type=m3u_plus');
      expect(url, isNotNull);
      expect(url!.path, '/xmltv.php');
      expect(url.queryParameters['username'], 'u1');
      expect(url.queryParameters['password'], 'p1');
    });

    test('null sin credenciales', () {
      expect(buildXmltvUrl('http://host.tv/get.php'), isNull);
    });
  });

  group('parseXmltvTime', () {
    test('convierte con desfase horario', () {
      final d = parseXmltvTime('20260702120000 +0200')!;
      expect(d.toUtc(), DateTime.utc(2026, 7, 2, 10, 0));
    });

    test('acepta UTC sin sufijo', () {
      final d = parseXmltvTime('20260702120000')!;
      expect(d.toUtc(), DateTime.utc(2026, 7, 2, 12, 0));
    });

    test('null si el formato no encaja', () {
      expect(parseXmltvTime('ayer'), isNull);
    });
  });

  group('parseXmltv', () {
    final guide = parseXmltv(_sample);

    test('agrupa programas por canal ordenados por inicio', () {
      final la1 = guide.byChannel['La1.es']!;
      expect(la1, hasLength(2));
      expect(la1.first.title, 'Telediario 1');
      expect(la1.first.description, contains('mediodía'));
      expect(la1.last.title, 'Sesión de tarde');
    });

    test('forChannel busca por tvg-id y por nombre', () {
      expect(guide.forChannel('La1.es', 'lo que sea'), hasLength(2));
      // Sin tvg-id: casa por display-name normalizado.
      expect(guide.forChannel(null, '24 horas'), hasLength(1));
      expect(guide.forChannel('', 'NoExiste'), isEmpty);
    });
  });
}
