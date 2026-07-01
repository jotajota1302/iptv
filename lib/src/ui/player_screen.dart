import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../app/providers.dart';
import '../domain/media_item.dart';
import '../player/media_kit_player_controller.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final MediaItem item;

  /// Si es true (VOD), reanuda desde la posición guardada y va guardando el
  /// progreso. En directo (false) no aplica.
  final bool resume;
  const PlayerScreen({super.key, required this.item, this.resume = false});
  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final MediaKitPlayerController _ctrl = MediaKitPlayerController();
  late final VideoController _video;
  final List<StreamSubscription> _subs = [];
  bool _seeked = false;
  int _lastSaved = 0;
  int _positionSeconds = 0;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    final hwAccel = ref.read(hardwareAccelProvider);
    final deinterlace = ref.read(deinterlaceProvider);
    _video = VideoController(
      _ctrl.player,
      configuration:
          VideoControllerConfiguration(enableHardwareAcceleration: hwAccel),
    );
    if (widget.resume) _setupResume();
    _ctrl.open(widget.item.streamUrl);
    // Requiere la libmpv completa (con bwdif). Ver tool/patch_libmpv.sh.
    _ctrl.setDeinterlace(deinterlace);
  }

  /// Configura la lógica de reanudar: al conocer la duración salta a la
  /// posición guardada (si es válida) y guarda el progreso cada ~10s.
  void _setupResume() {
    final saved = widget.item.positionSeconds;
    final player = _ctrl.player;
    _subs.add(player.stream.duration.listen((d) {
      _duration = d;
      _maybeSeek(saved);
    }));
    _subs.add(player.stream.position.listen((pos) {
      _positionSeconds = pos.inSeconds;
      _maybeSeek(saved);
      // Guarda cada 10s de avance, evitando escrituras excesivas.
      if ((_positionSeconds - _lastSaved).abs() >= 10) {
        _lastSaved = _positionSeconds;
        _save();
      }
    }));
  }

  /// Salta a [saved] una sola vez, cuando ya se conoce la duración y la
  /// posición guardada está entre 5s y (duración - 30s).
  void _maybeSeek(int saved) {
    if (_seeked || _duration.inSeconds <= 0) return;
    if (saved > 5 && saved < _duration.inSeconds - 30) {
      _seeked = true;
      _ctrl.player.seek(Duration(seconds: saved));
    } else {
      _seeked = true; // no hay nada que reanudar
    }
  }

  void _save() {
    if (!widget.resume) return;
    ref
        .read(playlistRepositoryProvider)
        .saveProgress(widget.item.id, _positionSeconds);
  }

  @override
  void dispose() {
    _save();
    for (final s in _subs) {
      s.cancel();
    }
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item.name)),
      backgroundColor: Colors.black,
      body: Center(
        child: Video(controller: _video, fit: BoxFit.contain),
      ),
    );
  }
}
