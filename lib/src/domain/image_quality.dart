/// Nivel de "calidad de imagen": qué escaladores/filtros del renderer GPU de
/// mpv (vo=gpu/libmpv) se aplican al VOD. media_kit renderiza con vo=libmpv, que
/// implementa este render-chain, así que estas propiedades surten efecto vía
/// NativePlayer.setProperty. Ver docs/superpowers/specs/2026-07-04-calidad-imagen-gpu-design.md
enum ImageQuality {
  auto('Automática'),
  alta('Alta'),
  media('Media'),
  off('Desactivada');

  final String label;
  const ImageQuality(this.label);
}

/// Resuelve [ImageQuality.auto] a un nivel concreto según la plataforma:
/// Windows/escritorio → [ImageQuality.media]; Android/FireTV → [ImageQuality.off]
/// (hardware flojo, evitar tirones). El resto de niveles se devuelven tal cual.
ImageQuality resolveImageQuality(ImageQuality q, {required bool isAndroid}) {
  if (q != ImageQuality.auto) return q;
  return isAndroid ? ImageQuality.off : ImageQuality.media;
}

/// Propiedades del render-chain de mpv para un nivel (ya resuelto, no `auto`).
/// TODOS los niveles fijan el MISMO juego de claves para que cambiar de nivel
/// sobreescriba por completo el anterior (sin restos). `off` = defaults de mpv.
Map<String, String> imageQualityProps(ImageQuality q) {
  switch (q) {
    case ImageQuality.alta:
      return const {
        'scale': 'ewa_lanczossharp',
        'cscale': 'ewa_lanczossharp',
        'dscale': 'mitchell',
        'deband': 'yes',
        'sigmoid-upscaling': 'yes',
        'correct-downscaling': 'yes',
        'linear-downscaling': 'yes',
      };
    case ImageQuality.media:
      return const {
        'scale': 'spline36',
        'cscale': 'spline36',
        'dscale': 'mitchell',
        'deband': 'yes',
        'sigmoid-upscaling': 'yes',
        'correct-downscaling': 'yes',
        'linear-downscaling': 'no',
      };
    case ImageQuality.off:
    case ImageQuality.auto:
      return const {
        'scale': 'bilinear',
        'cscale': 'bilinear',
        'dscale': 'bilinear',
        'deband': 'no',
        'sigmoid-upscaling': 'no',
        'correct-downscaling': 'no',
        'linear-downscaling': 'no',
      };
  }
}
