import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/data/epg_service.dart';

void main() {
  group('buildShortEpgUrl', () {
    test('deriva credenciales de la lista y stream_id del stream', () {
      final url = buildShortEpgUrl(
        'https://host.tv:8443/get.php?username=u1&password=p1&type=m3u_plus',
        'https://host.tv:8443/u1/p1/12345.ts',
      );
      expect(url, isNotNull);
      expect(url!.host, 'host.tv');
      expect(url.port, 8443);
      expect(url.path, '/player_api.php');
      expect(url.queryParameters['username'], 'u1');
      expect(url.queryParameters['password'], 'p1');
      expect(url.queryParameters['action'], 'get_short_epg');
      expect(url.queryParameters['stream_id'], '12345');
    });

    test('null si faltan credenciales', () {
      final url = buildShortEpgUrl(
        'https://host.tv/get.php?type=m3u_plus',
        'https://host.tv/u1/p1/12345.ts',
      );
      expect(url, isNull);
    });
  });

  group('parseShortEpg', () {
    test('decodifica titulos base64 y ordena por inicio', () {
      final json = {
        'epg_listings': [
          {
            'title': base64.encode(utf8.encode('Segundo')),
            'start_timestamp': 2000,
            'stop_timestamp': 3000,
          },
          {
            'title': base64.encode(utf8.encode('Primero')),
            'start_timestamp': 1000,
            'stop_timestamp': 2000,
          },
        ],
      };
      final entries = parseShortEpg(json);
      expect(entries.length, 2);
      expect(entries.first.title, 'Primero');
      expect(entries[1].title, 'Segundo');
      expect(entries.first.start.isBefore(entries[1].start), isTrue);
    });

    test('lista vacia si no hay epg_listings', () {
      expect(parseShortEpg({}), isEmpty);
    });
  });
}
