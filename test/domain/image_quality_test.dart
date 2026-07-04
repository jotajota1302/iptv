import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/domain/image_quality.dart';

void main() {
  group('resolveImageQuality', () {
    test('auto -> media en escritorio (no Android)', () {
      expect(resolveImageQuality(ImageQuality.auto, isAndroid: false),
          ImageQuality.media);
    });

    test('auto -> off en Android/FireTV', () {
      expect(resolveImageQuality(ImageQuality.auto, isAndroid: true),
          ImageQuality.off);
    });

    test('los niveles explícitos no cambian según plataforma', () {
      for (final p in [true, false]) {
        expect(resolveImageQuality(ImageQuality.alta, isAndroid: p),
            ImageQuality.alta);
        expect(resolveImageQuality(ImageQuality.media, isAndroid: p),
            ImageQuality.media);
        expect(resolveImageQuality(ImageQuality.off, isAndroid: p),
            ImageQuality.off);
      }
    });
  });

  group('imageQualityProps', () {
    test('off usa defaults (bilinear, sin deband)', () {
      final p = imageQualityProps(ImageQuality.off);
      expect(p['scale'], 'bilinear');
      expect(p['deband'], 'no');
    });

    test('media usa spline36 con deband', () {
      final p = imageQualityProps(ImageQuality.media);
      expect(p['scale'], 'spline36');
      expect(p['dscale'], 'mitchell');
      expect(p['deband'], 'yes');
    });

    test('alta usa ewa_lanczossharp', () {
      final p = imageQualityProps(ImageQuality.alta);
      expect(p['scale'], 'ewa_lanczossharp');
      expect(p['deband'], 'yes');
      expect(p['linear-downscaling'], 'yes');
    });

    test('todos los niveles fijan el mismo juego de claves', () {
      final keys = imageQualityProps(ImageQuality.off).keys.toSet();
      for (final q in [ImageQuality.media, ImageQuality.alta]) {
        expect(imageQualityProps(q).keys.toSet(), keys,
            reason: 'cambiar de nivel debe sobreescribir todas las claves');
      }
    });
  });
}
