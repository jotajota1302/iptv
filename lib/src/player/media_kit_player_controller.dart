import 'dart:async';
import 'package:media_kit/media_kit.dart';
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

  /// Activa/desactiva el desentrelazado de mpv (filtro `bwdif`). Corrige el
  /// efecto "peine" en contenido entrelazado (TV 1080i/576i). Con hwdec de tipo
  /// *copy* (d3d11va-copy) los fotogramas vuelven a CPU y el filtro se aplica.
  Future<void> setDeinterlace(bool enabled) async {
    final platform = player.platform;
    if (platform is NativePlayer) {
      await platform.setProperty('vf', enabled ? 'bwdif' : '');
    }
  }

  /// Ajusta filtros y búfer según el contenido. NO toca `hwdec` (lo fija
  /// `enableHardwareAcceleration` al crear el controlador): cambiarlo tras abrir
  /// reinicializa el decodificador en Windows y descartaría el seek de reanudar.
  /// - [deinterlace]: aplica `bwdif` (TV entrelazada) o ninguno (VOD progresivo).
  /// - [largeBuffer]: amplía el búfer del demuxer, útil para 4K de alto bitrate.
  Future<void> configure({
    required bool deinterlace,
    bool largeBuffer = false,
  }) async {
    final p = player.platform;
    if (p is! NativePlayer) return;
    await p.setProperty('vf', deinterlace ? 'bwdif' : '');
    await p.setProperty(
        'demuxer-max-bytes', largeBuffer ? '64MiB' : '16MiB');
    await p.setProperty(
        'demuxer-max-back-bytes', largeBuffer ? '32MiB' : '8MiB');
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
