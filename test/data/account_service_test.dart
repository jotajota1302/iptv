import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/data/account_service.dart';

void main() {
  group('buildAccountUrl', () {
    test('deriva player_api.php de la URL de la lista', () {
      final url = buildAccountUrl(
          'https://host.tv:8443/get.php?username=u1&password=p1&type=m3u_plus');
      expect(url!.path, '/player_api.php');
      expect(url.queryParameters['username'], 'u1');
      expect(url.queryParameters['password'], 'p1');
      expect(url.queryParameters.containsKey('action'), isFalse);
    });
  });

  group('deriveListUrlFromStream', () {
    test('reconstruye la URL get.php desde una URL de stream', () {
      final url = deriveListUrlFromStream(
          'https://host.tv:8443/live/u1/p1/157.ts');
      expect(url, contains('https://host.tv:8443/get.php'));
      expect(url, contains('username=u1'));
      expect(url, contains('password=p1'));
    });
  });

  group('parseAccountInfo', () {
    test('extrae estado, caducidad y conexiones', () {
      final info = parseAccountInfo({
        'user_info': {
          'status': 'Active',
          'exp_date': '1793000000',
          'active_cons': '1',
          'max_connections': '2',
          'is_trial': '0',
        },
      });
      expect(info, isNotNull);
      expect(info!.isActive, isTrue);
      expect(info.activeConnections, 1);
      expect(info.maxConnections, 2);
      expect(info.isTrial, isFalse);
      expect(info.expiry, isNotNull);
    });

    test('null si no hay user_info', () {
      expect(parseAccountInfo({}), isNull);
    });
  });
}
