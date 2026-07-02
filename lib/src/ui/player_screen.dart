import 'dart:async';
import 'dart:io' show exit;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../app/providers.dart';
import '../data/epg_service.dart';
import '../domain/content_type.dart';
import '../domain/media_item.dart';
import '../player/media_kit_player_controller.dart';

class PlayerScreen extends ConsumerStatefulWidget {
  final MediaItem item;

  /// Si es true (VOD), reanuda desde la posición guardada y va guardando el
  /// progreso. En directo (false) no aplica.
  final bool resume;

  /// Cola de reproducción (p. ej. episodios de una temporada) para auto‑pasar
  /// al siguiente al terminar. Null = sin cola.
  final List<MediaItem>? queue;
  final int queueIndex;

  /// True cuando esta pantalla ES una ventana de visor independiente (proceso
  /// lanzado con `--play`): el botón de salir cierra el proceso entero.
  final bool viewerWindow;

  const PlayerScreen({
    super.key,
    required this.item,
    this.resume = false,
    this.queue,
    this.queueIndex = 0,
    this.viewerWindow = false,
  });
  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  late final MediaKitPlayerController _ctrl = MediaKitPlayerController();
  late final VideoController _video;
  final List<StreamSubscription> _subs = [];
  bool _seeked = false;
  bool _advanced = false;
  bool _savedLoaded = false;
  int _savedPosition = 0;
  int _lastSaved = 0;
  int _positionSeconds = 0;
  Duration _duration = Duration.zero;

  // Pistas disponibles (audio/subtítulos) para poder elegirlas.
  List<AudioTrack> _audioTracks = [];
  List<SubtitleTrack> _subtitleTracks = [];

  // OSD (nombre del canal + programa actual) al entrar en un canal.
  bool _osdVisible = false;
  Timer? _osdTimer;

  // Temporizador de apagado: pausa la reproducción al vencer.
  Timer? _sleepTimer;
  int _sleepMinutes = 0;

  bool get _isLive => widget.item.type == ContentType.live;

  @override
  void initState() {
    super.initState();
    final hwAccel = ref.read(hardwareAccelProvider);
    final isVod = widget.item.type == ContentType.movie ||
        widget.item.type == ContentType.series;
    if (_isLive) _showOsd();
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
    // Auto‑pasar al siguiente episodio al terminar (si hay cola).
    if (_hasNext) {
      _subs.add(_ctrl.player.stream.completed.listen((done) {
        if (done) _playNext();
      }));
    }
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

  // --- Atajos de teclado (escritorio) ---
  double? _mutedVolume;

  void _seekBy(int seconds) {
    final target = (_positionSeconds + seconds).clamp(0, _duration.inSeconds);
    _ctrl.player.seek(Duration(seconds: target));
  }

  void _bumpVolume(double delta) {
    _mutedVolume = null;
    final v = (_ctrl.player.state.volume + delta).clamp(0.0, 100.0);
    _ctrl.player.setVolume(v);
  }

  void _toggleMute() {
    final p = _ctrl.player;
    if (_mutedVolume == null) {
      _mutedVolume = p.state.volume;
      p.setVolume(0);
    } else {
      p.setVolume(_mutedVolume!);
      _mutedVolume = null;
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.keyK) {
      _ctrl.player.playOrPause();
    } else if (k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.keyJ) {
      _seekBy(-10);
    } else if (k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.keyL) {
      _seekBy(10);
    } else if (k == LogicalKeyboardKey.arrowUp) {
      _bumpVolume(5);
    } else if (k == LogicalKeyboardKey.arrowDown) {
      _bumpVolume(-5);
    } else if (k == LogicalKeyboardKey.keyM) {
      _toggleMute();
    } else if (k == LogicalKeyboardKey.keyN && _hasNext) {
      _playNext();
    } else if (k == LogicalKeyboardKey.pageDown && _hasNext) {
      _playAt(widget.queueIndex + 1);
    } else if (k == LogicalKeyboardKey.pageUp && _hasPrev) {
      _playAt(widget.queueIndex - 1);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  bool get _hasNext =>
      widget.queue != null && widget.queueIndex + 1 < widget.queue!.length;

  bool get _hasPrev => widget.queue != null && widget.queueIndex > 0;

  /// Salta al elemento [index] de la cola (zapping de canal o cambio de
  /// episodio) reemplazando la pantalla para reutilizar toda la lógica.
  void _playAt(int index) {
    if (_advanced) return;
    final q = widget.queue;
    if (q == null || index < 0 || index >= q.length) return;
    _advanced = true;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => PlayerScreen(
        item: q[index],
        resume: widget.resume,
        queue: q,
        queueIndex: index,
        viewerWindow: widget.viewerWindow,
      ),
    ));
  }

  /// Pasa al siguiente elemento de la cola. En VOD marca el actual como visto.
  void _playNext() {
    if (_advanced || !_hasNext) return;
    if (widget.resume && _duration.inSeconds > 0) {
      ref.read(playlistRepositoryProvider).saveProgress(
          widget.item.id, _duration.inSeconds,
          duration: _duration.inSeconds);
    }
    _playAt(widget.queueIndex + 1);
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

  /// Muestra el OSD (canal + programa actual) y lo oculta a los 5 segundos.
  void _showOsd() {
    _osdVisible = true;
    _osdTimer?.cancel();
    _osdTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _osdVisible = false);
    });
  }

  /// Contenido del OSD: nombre del canal y, si hay EPG, el programa en
  /// emisión con su franja y avance.
  Widget _osd() {
    EpgEntry? current;
    if (_isLive) {
      final entries =
          ref.watch(previewEpgProvider(widget.item.streamUrl)).value ??
              const <EpgEntry>[];
      final now = DateTime.now();
      for (final e in entries) {
        if (!now.isBefore(e.start) && now.isBefore(e.end)) {
          current = e;
          break;
        }
      }
    }
    String hhmm(DateTime d) =>
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final now = DateTime.now();
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (current != null) ...[
            const SizedBox(height: 4),
            Text(
                '${hhmm(current.start)}–${hhmm(current.end)}  ${current.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 13, color: Colors.white70)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (now.difference(current.start).inSeconds /
                        current.end
                            .difference(current.start)
                            .inSeconds
                            .clamp(1, 1 << 31))
                    .clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: Colors.white24,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Programa (o cancela, con 0) el temporizador de apagado.
  void _setSleep(int minutes) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    setState(() => _sleepMinutes = minutes);
    if (minutes <= 0) return;
    _sleepTimer = Timer(Duration(minutes: minutes), () {
      if (!mounted) return;
      _ctrl.player.pause();
      setState(() => _sleepMinutes = 0);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Reproducción pausada por el temporizador')));
    });
  }

  Widget _sleepButton() {
    final active = _sleepMinutes > 0;
    return PopupMenuButton<int>(
      icon: Icon(active ? Icons.bedtime : Icons.bedtime_outlined,
          color: active ? Theme.of(context).colorScheme.primary : null),
      tooltip: active
          ? 'Temporizador: $_sleepMinutes min'
          : 'Temporizador de apagado',
      initialValue: _sleepMinutes,
      onSelected: _setSleep,
      itemBuilder: (_) => [
        const CheckedPopupMenuItem(value: 0, child: Text('Desactivado')),
        for (final m in const [15, 30, 60, 90])
          CheckedPopupMenuItem(value: m, child: Text('$m minutos')),
      ],
    );
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _osdTimer?.cancel();
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
    if (_isLive && _hasPrev) {
      actions.add(IconButton(
        icon: const Icon(Icons.skip_previous),
        tooltip: 'Canal anterior (Re Pág)',
        onPressed: () => _playAt(widget.queueIndex - 1),
      ));
    }
    if (_hasNext) {
      actions.add(IconButton(
        icon: const Icon(Icons.skip_next),
        tooltip: _isLive ? 'Canal siguiente (Av Pág)' : 'Siguiente episodio',
        onPressed: _playNext,
      ));
    }
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

  Widget _helpButton(BuildContext context) => IconButton(
        icon: const Icon(Icons.keyboard_outlined),
        tooltip: 'Atajos de teclado',
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Atajos de teclado'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Espacio / K — Reproducir · Pausa'),
                Text('← / → (J / L) — Retroceder · Avanzar 10 s'),
                Text('↑ / ↓ — Subir · Bajar volumen'),
                Text('M — Silenciar'),
                Text('N — Siguiente episodio'),
                Text('Re Pág / Av Pág — Canal · Episodio anterior / siguiente'),
              ],
            ),
            actions: [
              FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendido')),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          leading: widget.viewerWindow
              ? IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cerrar ventana',
                  onPressed: () => exit(0),
                )
              : null,
          title: Text(widget.item.name),
          actions: [..._trackActions(), _sleepButton(), _helpButton(context)]),
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          children: [
            Center(
              child: Video(controller: _video, fit: BoxFit.contain),
            ),
            // OSD de canal (nombre + programa actual), se desvanece solo.
            if (_isLive)
              Positioned(
                left: 16,
                bottom: 16,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _osdVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 350),
                    child: _osd(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
