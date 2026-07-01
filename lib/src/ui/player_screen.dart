import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../app/providers.dart';
import '../domain/content_type.dart';
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
  bool _savedLoaded = false;
  int _savedPosition = 0;
  int _lastSaved = 0;
  int _positionSeconds = 0;
  Duration _duration = Duration.zero;

  // Pistas disponibles (audio/subtítulos) para poder elegirlas.
  List<AudioTrack> _audioTracks = [];
  List<SubtitleTrack> _subtitleTracks = [];

  @override
  void initState() {
    super.initState();
    final hwAccel = ref.read(hardwareAccelProvider);
    final isVod = widget.item.type == ContentType.movie ||
        widget.item.type == ContentType.series;
    // VOD es progresivo (no entrelazado): sin bwdif y con búfer amplio para 4K.
    // TV en directo respeta el ajuste de desentrelazado.
    final deinterlace = isVod ? false : ref.read(deinterlaceProvider);
    _video = VideoController(
      _ctrl.player,
      configuration:
          VideoControllerConfiguration(enableHardwareAcceleration: hwAccel),
    );
    _subs.add(_ctrl.player.stream.tracks.listen((t) {
      if (!mounted) return;
      setState(() {
        _audioTracks = t.audio;
        _subtitleTracks = t.subtitle;
      });
    }));
    if (widget.resume) _setupResume();
    _ctrl.open(widget.item.streamUrl);
    // Config por tipo. bwdif requiere la libmpv completa (ver tool/patch_libmpv.sh).
    _ctrl.configure(deinterlace: deinterlace, largeBuffer: isVod);
  }

  /// Configura la lógica de reanudar: lee la posición guardada de la BD (fuente
  /// de verdad; el dato del grid puede estar obsoleto), y al conocer la duración
  /// salta a esa posición. Guarda el progreso cada ~10s.
  void _setupResume() {
    _savedPosition = widget.item.positionSeconds; // provisional hasta leer BD
    ref
        .read(playlistRepositoryProvider)
        .progress(widget.item.id)
        .then((s) {
      if (s > 0) _savedPosition = s;
      _savedLoaded = true;
      _maybeSeek();
    }).catchError((_) {
      _savedLoaded = true;
      _maybeSeek();
    });

    final player = _ctrl.player;
    _subs.add(player.stream.duration.listen((d) {
      _duration = d;
      _maybeSeek();
    }));
    _subs.add(player.stream.position.listen((pos) {
      _positionSeconds = pos.inSeconds;
      _maybeSeek();
      // Guarda cada 10s de avance, pero solo tras resolver el salto de reanudar
      // (evita sobrescribir la posición guardada con la del arranque en 0).
      if (_seeked && (_positionSeconds - _lastSaved).abs() >= 10) {
        _lastSaved = _positionSeconds;
        _save();
      }
    }));
  }

  /// Salta a la posición guardada una sola vez, cuando ya se ha leído de la BD,
  /// se conoce la duración y la posición está entre 5s y (duración - 30s).
  void _maybeSeek() {
    if (_seeked || !_savedLoaded || _duration.inSeconds <= 0) return;
    _seeked = true;
    final saved = _savedPosition;
    if (saved > 5 && saved < _duration.inSeconds - 30) {
      _ctrl.player.seek(Duration(seconds: saved));
    }
  }

  void _save() {
    if (!widget.resume) return;
    ref.read(playlistRepositoryProvider).saveProgress(
          widget.item.id,
          _positionSeconds,
          duration: _duration.inSeconds,
        );
  }

  String _audioLabel(AudioTrack t) {
    if (t.id == 'auto') return 'Automático';
    if (t.id == 'no') return 'Ninguno';
    final parts = [t.title, t.language].where((e) => e != null && e.isNotEmpty);
    return parts.isEmpty ? 'Pista ${t.id}' : parts.join(' · ');
  }

  String _subLabel(SubtitleTrack t) {
    if (t.id == 'no') return 'Desactivados';
    if (t.id == 'auto') return 'Automático';
    final parts = [t.title, t.language].where((e) => e != null && e.isNotEmpty);
    return parts.isEmpty ? 'Sub ${t.id}' : parts.join(' · ');
  }

  @override
  void dispose() {
    // 1) Cortar el audio LO PRIMERO, pase lo que pase con el resto.
    final ctrl = _ctrl;
    ctrl.player.setVolume(0);
    ctrl.player.pause();
    // 2) Guardar progreso sin bloquear (si falla, no impide el corte de audio).
    try {
      _save();
    } catch (_) {}
    // 3) Cancelar suscripciones y liberar el reproductor.
    for (final s in _subs) {
      s.cancel();
    }
    ctrl.dispose();
    super.dispose();
  }

  List<Widget> _trackActions() {
    final actions = <Widget>[];
    // Selección de audio (solo si hay más de una pista real).
    final audios = _audioTracks.where((t) => t.id != 'auto').toList();
    if (audios.length > 1) {
      actions.add(PopupMenuButton<AudioTrack>(
        icon: const Icon(Icons.multitrack_audio),
        tooltip: 'Audio',
        onSelected: (t) => _ctrl.player.setAudioTrack(t),
        itemBuilder: (_) => [
          for (final t in _audioTracks.where((t) => t.id != 'no'))
            PopupMenuItem(value: t, child: Text(_audioLabel(t))),
        ],
      ));
    }
    // Selección de subtítulos (siempre que exista alguno).
    final subs = _subtitleTracks.where((t) => t.id != 'auto').toList();
    final hasRealSubs = subs.any((t) => t.id != 'no');
    if (hasRealSubs) {
      actions.add(PopupMenuButton<SubtitleTrack>(
        icon: const Icon(Icons.subtitles),
        tooltip: 'Subtítulos',
        onSelected: (t) => _ctrl.player.setSubtitleTrack(t),
        itemBuilder: (_) => [
          PopupMenuItem(
              value: SubtitleTrack.no(), child: Text(_subLabel(SubtitleTrack.no()))),
          for (final t in subs.where((t) => t.id != 'no'))
            PopupMenuItem(value: t, child: Text(_subLabel(t))),
        ],
      ));
    }
    return actions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item.name), actions: _trackActions()),
      backgroundColor: Colors.black,
      body: Center(
        child: Video(controller: _video, fit: BoxFit.contain),
      ),
    );
  }
}
