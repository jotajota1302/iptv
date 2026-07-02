import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/data/update_service.dart';

void main() {
  group('compareVersions', () {
    test('ordena versiones semver', () {
      expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
      expect(compareVersions('1.10.0', '1.9.0'), greaterThan(0));
      expect(compareVersions('2', '1.9.9'), greaterThan(0));
      expect(compareVersions('1.0.0', '1.0.0'), 0);
    });

    test('ignora prefijo v y sufijo de build', () {
      expect(compareVersions('v1.2.0', '1.2.0'), 0);
      expect(compareVersions('1.0.0+1', '1.0.0'), 0);
      expect(isNewerVersion('1.0.0', 'v1.0.1'), isTrue);
      expect(isNewerVersion('1.0.1', 'v1.0.1'), isFalse);
    });
  });

  group('pickLatestAppRelease', () {
    test('devuelve el primer release de app válido', () {
      final info = pickLatestAppRelease([
        {'tag_name': 'v1.2.0', 'html_url': 'https://x/rel/v1.2.0', 'body': 'Notas'},
        {'tag_name': 'v1.1.0', 'html_url': 'https://x/rel/v1.1.0'},
      ]);
      expect(info!.version, 'v1.2.0');
      expect(info.url, 'https://x/rel/v1.2.0');
      expect(info.notes, 'Notas');
    });

    test('salta borradores, prereleases y tags de herramientas', () {
      final info = pickLatestAppRelease([
        {'tag_name': 'v9.0.0', 'html_url': 'https://x/d', 'draft': true},
        {'tag_name': 'v8.0.0', 'html_url': 'https://x/p', 'prerelease': true},
        {'tag_name': 'libmpv-lgpl-20260702', 'html_url': 'https://x/l'},
        {'tag_name': 'v1.1.0', 'html_url': 'https://x/ok'},
      ]);
      expect(info!.version, 'v1.1.0');
    });

    test('lista vacía o sin releases de app → null', () {
      expect(pickLatestAppRelease([]), isNull);
      expect(
          pickLatestAppRelease([
            {'tag_name': 'libmpv-lgpl-20260702', 'html_url': 'https://x/l'},
          ]),
          isNull);
    });
  });

  test('UpdateService con feed vacío no comprueba nada', () async {
    final svc = UpdateService(feedUrl: '');
    expect(await svc.check('1.0.0'), isNull);
  });
}
