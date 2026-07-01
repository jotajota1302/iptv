import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/domain/adult_filter.dart';

void main() {
  test('detecta categorías de adultos', () {
    expect(isAdult('Canales XXX'), isTrue);
    expect(isAdult('ADULTOS +18'), isTrue);
    expect(isAdult('Porn HD'), isTrue);
    expect(isAdult('Para adultos'), isTrue);
  });

  test('no marca contenido normal (evita falsos positivos)', () {
    expect(isAdult('La Sexta'), isFalse);
    expect(isAdult('Deportes'), isFalse);
    expect(isAdult('Cine Acción'), isFalse);
    expect(isAdult(null), isFalse);
  });
}
