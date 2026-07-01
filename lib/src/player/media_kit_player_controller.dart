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

  /// Activa/desactiva el desentrelazado de mpv. Corrige el efecto "peine"
  /// (líneas paralelas) en contenido entrelazado como la TV en directo.
  ///
  /// Usa el filtro de vídeo `bwdif` (software), que requiere decodificación por
  /// software: con hwdec activo los fotogramas están en la GPU y el filtro no se
  /// aplica. Por eso [PlayerScreen] fuerza decodificación por software cuando el
  /// desentrelazado está activado.
  Future<void> setDeinterlace(bool enabled) async {
    final platform = player.platform;
    if (platform is NativePlayer) {
      // Requiere decodificación por software (hwdec='no'), configurada en
      // PlayerScreen. bwdif es un desentrelazador de alta calidad.
      await platform.setProperty('vf', enabled ? 'bwdif' : '');
    }
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
    await player.dispose();
  }
}
