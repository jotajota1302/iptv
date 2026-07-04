import 'dart:async';
import 'package:media_kit/media_kit.dart';
import '../domain/deinterlacer.dart';
import 'player_controller.dart';

class MediaKitPlayerController implements PlayerController {
  final Player player = Player();
  final _status = StreamController<PlayerStatus>.broadcast();
  final _subs = <StreamSubscription>[];

  MediaKitPlayerController() {
    _subs.add(player.stream.playing.listen((p) =>
        _status.add(p ? PlayerStatus.playing : PlayerStatus.paused)));
    _subs.add(player.stream.buffering.listen((b) {
      if (b) _status.add(PlayerStatus.buffering);
    }));
    _subs.add(player.stream.error.listen((_) => _status.add(PlayerStatus.error)));
  }

  @override
  Stream<PlayerStatus> get status => _status.stream;

  @override
  Future<void> open(String url) => player.open(Media(url));

  /// Fija el modo de decodificación por hardware de mpv. Para desentrelazar el
  /// directo con `bwdif` (filtro de CPU) los fotogramas tienen que estar en
  /// memoria de sistema: con `auto-copy` se decodifica por GPU pero se copian
  /// de vuelta a CPU, así el filtro actúa sin renunciar a la aceleración.
  /// DEBE fijarse ANTES de abrir el medio: cambiar `hwdec` tras abrir
  /// reinicializa el decodificador en Windows (y perdería el seek de reanudar).
  Future<void> setHwdec(String value) async {
    final p = player.platform;
    if (p is NativePlayer) {
      await p.setProperty('hwdec', value);
    }
  }

  /// Activa/desactiva el desentrelazado de mpv (filtro `bwdif`). Corrige el
  /// efecto "peine" en contenido entrelazado (TV 1080i/576i). Con hwdec de tipo
  /// *copy* (d3d11va-copy / auto-copy) los fotogramas vuelven a CPU y el filtro
  /// se aplica; con hwdec directo (d3d11va) el filtro no ve los fotogramas.
  Future<void> setDeinterlace(bool enabled, {List<String>? candidates}) async {
    final platform = player.platform;
    if (platform is NativePlayer) {
      await _applyDeintVf(platform, enabled, candidates);
    }
  }

  /// Fija el filtro de desentrelazado probando los [candidates] en orden y
  /// verificando con lectura de vuelta: se queda con el primero que mpv acepte.
  /// mpv rechaza una cadena inválida dejando `vf` vacío (sin lanzar excepción),
  /// por eso se comprueba que el `vf` resultante contenga el nombre del filtro
  /// pedido. Las listas de [deinterlacerCandidates] terminan siempre en `bwdif`,
  /// así que un método no soportado nunca deja la imagen sin filtro. Por defecto
  /// se usa `bwdif` (p. ej. la vista previa de canales, que no elige método).
  Future<void> _applyDeintVf(
      NativePlayer p, bool enabled, List<String>? candidates) async {
    if (!enabled) {
      await p.setProperty('vf', '');
      return;
    }
    final list = candidates ?? deinterlacerCandidates(Deinterlacer.bwdif);
    for (final f in list) {
      await p.setProperty('vf', f);
      try {
        final applied = await p.getProperty('vf');
        // El nombre del filtro es lo que va antes del primer '='.
        if (applied.contains(f.split('=').first)) return; // aceptado por mpv
      } catch (_) {}
    }
  }

  /// Ajusta filtros y búfer según el contenido. NO toca `hwdec` (lo fija
  /// `enableHardwareAcceleration` al crear el controlador): cambiarlo tras abrir
  /// reinicializa el decodificador en Windows y descartaría el seek de reanudar.
  /// - [deinterlace]: aplica el desentrelazado (TV entrelazada) o ninguno (VOD).
  /// - [deintCandidates]: cadenas `vf` a probar (ver [deinterlacerCandidates]);
  ///   por defecto `bwdif`.
  /// - [largeBuffer]: amplía el búfer del demuxer, útil para 4K de alto bitrate.
  Future<void> configure({
    required bool deinterlace,
    List<String>? deintCandidates,
    bool largeBuffer = false,
  }) async {
    final p = player.platform;
    if (p is! NativePlayer) return;
    await _applyDeintVf(p, deinterlace, deintCandidates);
    await p.setProperty(
        'demuxer-max-bytes', largeBuffer ? '64MiB' : '16MiB');
    // Búfer hacia atrás amplio en VOD: permite retroceder a lo ya visto sin
    // volver a descargar (el salto es instantáneo desde caché). En directo se
    // mantiene pequeño (no tiene sentido retroceder mucho).
    await p.setProperty(
        'demuxer-max-back-bytes', largeBuffer ? '128MiB' : '8MiB');
    if (largeBuffer) {
      // Saltos por la barra en streams por red: mantener la caché y permitir
      // buscar DENTRO de ella sin reabrir la conexión (evita que el seek se
      // "congele" al retroceder o avanzar a una zona ya descargada).
      await p.setProperty('cache', 'yes');
      await p.setProperty('demuxer-seekable-cache', 'yes');
    }
  }

  /// Aplica el chain de "calidad de imagen" (escaladores/deband del renderer
  /// GPU de mpv, vo=libmpv) a partir del mapa de propiedades ya resuelto
  /// (ver imageQualityProps). Best-effort: cada setProperty va en try/catch para
  /// que un valor no soportado nunca rompa la reproducción (cae a los defaults).
  Future<void> setVideoQuality(Map<String, String> props) async {
    final p = player.platform;
    if (p is! NativePlayer) return;
    for (final e in props.entries) {
      try {
        await p.setProperty(e.key, e.value);
      } catch (_) {}
    }
  }

  /// Propiedades técnicas del stream en curso, para "Información del stream".
  /// Best-effort: las que mpv no conozca salen como '—'.
  Future<Map<String, String>> streamInfo() async {
    final p = player.platform;
    if (p is! NativePlayer) return {};
    Future<String> get(String prop) async {
      try {
        final v = await p.getProperty(prop);
        return v.isEmpty ? '—' : v;
      } catch (_) {
        return '—';
      }
    }

    String fps(String v) {
      final d = double.tryParse(v);
      return d == null ? v : d.toStringAsFixed(d == d.roundToDouble() ? 0 : 2);
    }

    String mbps(String v) {
      final d = double.tryParse(v);
      return d == null ? v : '${(d / 1000000).toStringAsFixed(1)} Mbps';
    }

    return {
      'Resolución': '${await get('width')} × ${await get('height')}',
      'FPS': fps(await get('container-fps')),
      'Códec de vídeo': await get('video-format'),
      'Códec de audio': await get('audio-codec-name'),
      'Bitrate de vídeo': mbps(await get('video-bitrate')),
      'Decodificación': await get('hwdec-current'),
    };
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _status.close();
    // Detiene la reproducción y descarga el medio ANTES de liberar: en Windows
    // player.dispose() por sí solo puede dejar el audio sonando un instante.
    try {
      await player.stop();
    } catch (_) {}
    await player.dispose();
  }
}
