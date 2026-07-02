import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iptv_player/src/data/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('buildBackup incluye prefs presentes y flags', () async {
    SharedPreferences.setMockInitialValues({
      'playlists': '[{"id":"1","name":"Mi lista","url":"http://x"}]',
      'parental_hide': true,
      'accent_color': 2,
      'otra_clave_ajena': 'no debe salir',
    });
    final prefs = await SharedPreferences.getInstance();
    final backup = buildBackup(prefs, {'id1': {'fav': true}});

    expect(backup['app'], 'iptv_player');
    expect(backup['version'], 1);
    final p = backup['prefs'] as Map;
    expect(p['playlists'], contains('Mi lista'));
    expect(p['parental_hide'], isTrue);
    expect(p['accent_color'], 2);
    expect(p.containsKey('otra_clave_ajena'), isFalse);
    expect((backup['flags'] as Map)['id1'], {'fav': true});
  });

  test('isValidBackup', () {
    expect(isValidBackup({'app': 'iptv_player', 'prefs': {}, 'flags': {}}),
        isTrue);
    expect(isValidBackup({'app': 'otro', 'prefs': {}, 'flags': {}}), isFalse);
    expect(isValidBackup({}), isFalse);
  });

  test('restorePrefs escribe bool/int/string y cuenta las claves', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final n = await restorePrefs(prefs, {
      'prefs': {
        'parental_hide': false,
        'accent_color': 3,
        'playlists': '[]',
        'clave_rara': [1, 2], // tipo inesperado: se ignora
      },
    });
    expect(n, 3);
    expect(prefs.getBool('parental_hide'), isFalse);
    expect(prefs.getInt('accent_color'), 3);
    expect(prefs.getString('playlists'), '[]');
  });
}
