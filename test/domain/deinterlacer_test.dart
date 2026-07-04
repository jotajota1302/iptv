import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/domain/deinterlacer.dart';

void main() {
  test('bwdif: empieza por el doble-campo y acaba en bwdif simple', () {
    final c = deinterlacerCandidates(Deinterlacer.bwdif);
    expect(c.first, 'bwdif=mode=send_field');
    expect(c.last, 'bwdif');
  });

  test('estdif: prueba estdif primero y cae a bwdif como red de seguridad', () {
    final c = deinterlacerCandidates(Deinterlacer.estdif);
    expect(c.first.startsWith('estdif'), isTrue,
        reason: 'el método elegido va primero');
    expect(c.any((f) => f.startsWith('estdif')), isTrue);
    expect(c.last, 'bwdif',
        reason: 'siempre termina en bwdif simple para no quedar sin filtro');
  });

  test('todos los métodos terminan siempre en bwdif simple', () {
    for (final d in Deinterlacer.values) {
      expect(deinterlacerCandidates(d).last, 'bwdif');
    }
  });

  test('cada método tiene etiqueta legible', () {
    for (final d in Deinterlacer.values) {
      expect(d.label, isNotEmpty);
    }
  });
}
