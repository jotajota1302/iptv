import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/domain/lang_match.dart';

void main() {
  test('casa códigos ISO de 2 y 3 letras', () {
    expect(langMatches('es', 'es'), isTrue);
    expect(langMatches('spa', 'es'), isTrue);
    expect(langMatches('eng', 'en'), isTrue);
    expect(langMatches('por', 'pt'), isTrue);
  });

  test('casa nombres largos', () {
    expect(langMatches('Spanish (Latin America)', 'es'), isTrue);
    expect(langMatches('English', 'en'), isTrue);
  });

  test('no casa idiomas distintos ni parecidos', () {
    expect(langMatches('est', 'es'), isFalse); // estonio ≠ español
    expect(langMatches('fr', 'es'), isFalse);
    expect(langMatches(null, 'es'), isFalse);
    expect(langMatches('', 'es'), isFalse);
  });

  test('pref vacío (automático) nunca casa', () {
    expect(langMatches('es', ''), isFalse);
  });
}
