import 'dart:async';
import 'dart:convert';
import 'dart:io' show exit, Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../app/desktop_window.dart';
import '../app/providers.dart';
import '../data/epg_service.dart';
import '../domain/content_type.dart';
import '../domain/deinterlacer.dart';
import '../domain/image_quality.dart';
import '../domain/lang_match.dart';
import '../domain/media_item.dart';
import '../player/media_kit_player_controller.dart';

/// Modos de relación de aspecto / zoom del vídeo.
enum FitMode {
  auto('Auto'),
  ratio169('16:9'),
  ratio43('4:3'),
  stretch('Estirar'),
  crop('Recortar');

  const FitMode(this.label);
  final String label;
}

class PlayerScreen extends ConsumerStatefulWidget {
  final MediaItem item;

  /// Si es true (VOD), reanuda desde la posición guardada y va guardando el
  /// progreso. En directo (false) no aplica.
  final bool resume;

  /// Si es true, ignora la posición guardada y empieza desde el principio (pero
  /// sigue guardando el progreso). Lo decide el diálogo "Continuar / Desde el
  /// principio" al abrir un VOD con progreso.
  final bool startFromBeginning;

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
    this.startFromBeginning = false,
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

  // Estado de los controles propios (barra inferior).
  bool _playing = false;
  bool _buffering = false;
  bool _dragging = false;
  double _dragValue = 0;
  // Tras un seek manual se ignoran las posiciones viejas que el stream aún
  // emite; sin esto la barra "vuelve atrás" un instante al soltar.
  DateTime _ignoreStreamUntil = DateTime.fromMillisecondsSinceEpoch(0);

  // Reconexión automática en directo: si el stream cae (EOF), se reabre el
  // mismo canal en vez de pararse o saltar al siguiente.
  bool _reconnecting = false;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  static const _maxReconnectAttempts = 8;
  // Vigía de "congelado": un directo que se cae normalmente NO emite EOF, solo
  // se queda en buffering para siempre. Si el buffer no se resuelve en este
  // tiempo, se da el canal por caído y se reabre (ver [_watchLiveStall]).
  Timer? _stallTimer;
  static const _liveStallTimeout = Duration(seconds: 10);

  // Pistas disponibles (audio/subtítulos) para poder elegirlas.
  List<AudioTrack> _audioTracks = [];
  List<SubtitleTrack> _subtitleTracks = [];
  Track? _currentTracks;

  // OSD (nombre del canal + programa actual) al entrar en un canal.
  bool _osdVisible = false;
  Timer? _osdTimer;

  // Temporizador de apagado: pausa la reproducción al vencer.
  Timer? _sleepTimer;
  int _sleepMinutes = 0;

  // Aspecto/zoom y velocidad de reproducción.
  FitMode _fit = FitMode.auto;
  double _rate = 1.0;

  // UI inmersiva: la barra se oculta sola durante la reproducción.
  bool _uiVisible = true;
  Timer? _uiTimer;
  bool _fullscreen = false;

  // Zapping tecleando el número de canal.
  String _numBuf = '';
  Timer? _numTimer;

  // Selección automática de pista por idioma preferido (una vez por apertura).
  bool _langsApplied = false;

  bool get _isLive => widget.item.type == ContentType.live;

  @override
  void initState() {
    super.initState();
    final hwAccel = ref.read(hardwareAccelProvider);
    final isVod = widget.item.type == ContentType.movie ||
        widget.item.type == ContentType.series;
    if (_isLive) _showOsd();
    // Recordar el último canal visto (para "arrancar en el último canal").
    if (_isLive && !widget.viewerWindow) {
      ref.read(sharedPrefsProvider).setString(
          'last_channel',
          jsonEncode({
            'name': widget.item.name,
            'url': widget.item.streamUrl,
            'group': widget.item.groupTitle,
          }));
    }
    _scheduleUiHide();
    // VOD es progresivo (no entrelazado): sin bwdif y con búfer amplio para 4K.
    // TV en directo respeta el ajuste de desentrelazado.
    final deinterlace = isVod ? false : ref.read(deinterlaceProvider);
    final deintCandidates =
        deinterlacerCandidates(ref.read(deinterlacerProvider));
    _video = VideoController(
      _ctrl.player,
      configuration:
          VideoControllerConfiguration(enableHardwareAcceleration: hwAccel),
    );
    _subs.add(_ctrl.player.stream.playing.listen((p) {
      if (!mounted) return;
      setState(() => _playing = p);
      // Reproducción en marcha: reconexión superada, se resetea el contador.
      if (p && (_reconnecting || _reconnectAttempts > 0)) {
        setState(() {
          _reconnecting = false;
          _reconnectAttempts = 0;
        });
      }
      // En pausa la barra queda visible; al reproducir se oculta sola.
      if (!p) {
        _uiTimer?.cancel();
        if (!_uiVisible) setState(() => _uiVisible = true);
      } else {
        _scheduleUiHide();
      }
    }));
    // Posición y duración para la barra de progreso propia. Una fuente única
    // (este listener) para la UI, el clamp de los saltos y el guardado.
    _subs.add(_ctrl.player.stream.duration.listen((d) {
      final changed = d.inSeconds != _duration.inSeconds;
      _duration = d;
      if (widget.resume) _maybeSeek();
      if (changed && mounted) setState(() {});
    }));
    _subs.add(_ctrl.player.stream.position.listen((pos) {
      if (DateTime.now().isBefore(_ignoreStreamUntil)) return;
      final s = pos.inSeconds;
      final changed = s != _positionSeconds;
      _positionSeconds = s;
      if (widget.resume) {
        _maybeSeek();
        // Guarda cada 10s de avance, pero solo tras resolver el salto de
        // reanudar (evita pisar la posición guardada con el arranque en 0).
        if (_seeked && (s - _lastSaved).abs() >= 10) {
          _lastSaved = s;
          _save();
        }
      }
      // setState solo al cambiar el segundo y sin arrastre en curso.
      if (changed && !_dragging && mounted) setState(() {});
    }));
    _subs.add(_ctrl.player.stream.buffering.listen((b) {
      if (mounted && b != _buffering) setState(() => _buffering = b);
      if (_isLive) _watchLiveStall(b);
    }));
    _subs.add(_ctrl.player.stream.track.listen((t) {
      if (mounted) setState(() => _currentTracks = t);
    }));
    _subs.add(_ctrl.player.stream.tracks.listen((t) {
      if (!mounted) return;
      setState(() {
        _audioTracks = t.audio;
        _subtitleTracks = t.subtitle;
      });
      _applyPreferredTracks(t);
    }));
    // Al terminar el stream: en directo se reconecta el MISMO canal (un directo
    // no "acaba", es que se ha caído); en VOD con cola pasa al siguiente.
    _subs.add(_ctrl.player.stream.completed.listen((done) {
      if (!done || !mounted || _advanced) return;
      if (_isLive) {
        debugPrint('[live] EOF (completed) → reconectando');
        _tryReconnect();
      } else if (_hasNext) {
        _playNext();
      }
    }));
    // Reanudar desde lo guardado, salvo que se pida empezar desde el principio
    // (en ese caso marcamos _seeked para que no salte, pero seguimos guardando).
    if (widget.resume && !widget.startFromBeginning) {
      _setupResume();
    } else if (widget.startFromBeginning) {
      _seeked = true;
    }
    // Directo entrelazado + aceleración por hardware: `auto-copy` devuelve los
    // fotogramas a CPU para que `bwdif` desentrelace SIN renunciar a la GPU
    // (se fija ANTES de abrir para no reinicializar el decodificador). En VOD
    // no se toca el hwdec (es progresivo y así se preserva el seek de reanudar);
    // con aceleración apagada, hwdec ya es software y bwdif funciona igual.
    if (_isLive && deinterlace && hwAccel) {
      _ctrl.setHwdec('auto-copy');
    }
    _ctrl.open(widget.item.streamUrl);
    // Config por tipo. bwdif requiere la libmpv completa (ver tool/patch_libmpv.sh).
    _ctrl.configure(
        deinterlace: deinterlace,
        deintCandidates: deintCandidates,
        largeBuffer: isVod);
    // Calidad de imagen (escaladores/deband GPU) solo para VOD; "auto" se
    // resuelve por plataforma. Best-effort dentro del controlador.
    if (isVod) {
      final q = resolveImageQuality(ref.read(imageQualityProvider),
          isAndroid: Platform.isAndroid);
      _ctrl.setVideoQuality(imageQualityProps(q));
    }
  }

  /// Configura la lógica de reanudar: lee la posición guardada de la BD (fuente
  /// de verdad; el dato del grid puede estar obsoleto). El salto se resuelve
  /// desde los listeners de posición/duración de initState.
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

  // --- UI inmersiva y pantalla completa ---

  /// Muestra la barra y reprograma su ocultado automático.
  void _pokeUi() {
    if (!_uiVisible) setState(() => _uiVisible = true);
    _scheduleUiHide();
  }

  void _scheduleUiHide() {
    _uiTimer?.cancel();
    _uiTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || !_ctrl.player.state.playing) return;
      setState(() => _uiVisible = false);
    });
  }

  void _toggleFullscreen() {
    _fullscreen = !_fullscreen;
    setWindowFullScreen(_fullscreen);
    setState(() {});
  }

  // --- Pistas preferidas por idioma ---

  /// Al conocer las pistas, elige el audio/subtítulos del idioma preferido
  /// (una sola vez por apertura, para no pisar la elección manual).
  void _applyPreferredTracks(Tracks t) {
    if (_langsApplied) return;
    final audios =
        t.audio.where((a) => a.id != 'auto' && a.id != 'no').toList();
    final subs =
        t.subtitle.where((s) => s.id != 'auto' && s.id != 'no').toList();
    if (audios.isEmpty && subs.isEmpty) return;
    _langsApplied = true;
    final aPref = ref.read(preferredAudioLangProvider);
    if (aPref.isNotEmpty) {
      for (final a in audios) {
        if (langMatches(a.language, aPref) || langMatches(a.title, aPref)) {
          _ctrl.player.setAudioTrack(a);
          break;
        }
      }
    }
    final sPref = ref.read(preferredSubLangProvider);
    if (sPref == 'off') {
      if (subs.isNotEmpty) _ctrl.player.setSubtitleTrack(SubtitleTrack.no());
    } else if (sPref.isNotEmpty) {
      for (final s in subs) {
        if (langMatches(s.language, sPref) || langMatches(s.title, sPref)) {
          _ctrl.player.setSubtitleTrack(s);
          break;
        }
      }
    }
  }

  // --- Zapping tecleando el número de canal ---

  void _numKey(int d) {
    if (widget.queue == null || _numBuf.length >= 4) return;
    setState(() => _numBuf += '$d');
    _numTimer?.cancel();
    _numTimer = Timer(const Duration(milliseconds: 1600), _commitNum);
  }

  void _commitNum() {
    final n = int.tryParse(_numBuf);
    if (mounted) setState(() => _numBuf = '');
    final q = widget.queue;
    if (n == null || q == null) return;
    if (n >= 1 && n <= q.length && n - 1 != widget.queueIndex) _playAt(n - 1);
  }

  // --- Atajos de teclado (escritorio) ---
  double? _mutedVolume;

  static final _digitKeys = <LogicalKeyboardKey, int>{
    LogicalKeyboardKey.digit0: 0,
    LogicalKeyboardKey.digit1: 1,
    LogicalKeyboardKey.digit2: 2,
    LogicalKeyboardKey.digit3: 3,
    LogicalKeyboardKey.digit4: 4,
    LogicalKeyboardKey.digit5: 5,
    LogicalKeyboardKey.digit6: 6,
    LogicalKeyboardKey.digit7: 7,
    LogicalKeyboardKey.digit8: 8,
    LogicalKeyboardKey.digit9: 9,
    LogicalKeyboardKey.numpad0: 0,
    LogicalKeyboardKey.numpad1: 1,
    LogicalKeyboardKey.numpad2: 2,
    LogicalKeyboardKey.numpad3: 3,
    LogicalKeyboardKey.numpad4: 4,
    LogicalKeyboardKey.numpad5: 5,
    LogicalKeyboardKey.numpad6: 6,
    LogicalKeyboardKey.numpad7: 7,
    LogicalKeyboardKey.numpad8: 8,
    LogicalKeyboardKey.numpad9: 9,
  };

  void _seekBy(int seconds) {
    if (_duration.inSeconds <= 0) return;
    _seekTo((_positionSeconds + seconds).clamp(0, _duration.inSeconds));
  }

  /// Salto manual: actualiza la UI al instante e ignora brevemente las
  /// posiciones antiguas que el stream sigue emitiendo tras el seek.
  void _seekTo(int seconds) {
    _positionSeconds = seconds;
    _ignoreStreamUntil =
        DateTime.now().add(const Duration(milliseconds: 700));
    _ctrl.player.seek(Duration(seconds: seconds));
    if (mounted) setState(() {});
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
      _onPlayPause();
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
    } else if (k == LogicalKeyboardKey.keyF) {
      _toggleFullscreen();
    } else if (k == LogicalKeyboardKey.escape && _fullscreen) {
      _toggleFullscreen();
    } else if (k == LogicalKeyboardKey.keyA) {
      final next =
          FitMode.values[(_fit.index + 1) % FitMode.values.length];
      setState(() => _fit = next);
      _pokeUi();
    } else if (_digitKeys.containsKey(k) && widget.queue != null) {
      _numKey(_digitKeys[k]!);
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

  /// Vigía de directo: un stream en vivo que se congela normalmente NO emite
  /// EOF (`completed`), solo se queda en buffering indefinidamente. Si el buffer
  /// sigue sin resolverse pasado [_liveStallTimeout], se da el canal por caído y
  /// se reabre. Cada transición de buffering rearma el temporizador; al volver a
  /// fluir (buffering=false) se cancela.
  void _watchLiveStall(bool buffering) {
    _stallTimer?.cancel();
    if (!buffering || _advanced) return;
    _stallTimer = Timer(_liveStallTimeout, () {
      if (!mounted || !_isLive || _advanced) return;
      // Se relee el estado real del reproductor por si ya se resolvió.
      if (_ctrl.player.state.buffering) {
        debugPrint('[live] congelado >${_liveStallTimeout.inSeconds}s '
            '→ reconectando (intento ${_reconnectAttempts + 1})');
        _tryReconnect();
      }
    });
  }

  /// Reabre el canal en directo tras un corte, con un tope de reintentos. El
  /// contador se resetea solo cuando vuelve a reproducir (listener de playing).
  void _tryReconnect() {
    if (_advanced || !mounted) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (_reconnecting) setState(() => _reconnecting = false);
      return; // se rinde: el usuario puede reintentar con ▶
    }
    _reconnectAttempts++;
    setState(() => _reconnecting = true);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted && !_advanced) _ctrl.open(widget.item.streamUrl);
    });
  }

  /// Play/pausa del botón. En directo, si el stream está parado (se cayó), lo
  /// reabre en vez de intentar reanudar algo que ya no existe.
  void _onPlayPause() {
    debugPrint('[player] play/pausa (live=$_isLive, reproduciendo=$_playing)');
    if (_isLive && !_playing) {
      _reconnectAttempts = 0;
      setState(() => _reconnecting = false);
      _reconnectTimer?.cancel();
      _ctrl.open(widget.item.streamUrl);
    } else {
      _ctrl.player.playOrPause();
    }
  }

  /// Etiquetas únicas para el menú: las pistas con el mismo título/idioma
  /// (muy común en streams IPTV) se numeran para no ver entradas repetidas.
  List<(T, String)> _numbered<T>(List<T> tracks, String Function(T) label) {
    final total = <String, int>{};
    for (final t in tracks) {
      total.update(label(t), (v) => v + 1, ifAbsent: () => 1);
    }
    final seen = <String, int>{};
    return [
      for (final t in tracks)
        (
          t,
          total[label(t)]! > 1
              ? '${label(t)} (${seen.update(label(t), (v) => v + 1, ifAbsent: () => 1)})'
              : label(t)
        ),
    ];
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
    _uiTimer?.cancel();
    _numTimer?.cancel();
    _reconnectTimer?.cancel();
    _stallTimer?.cancel();
    if (_fullscreen) setWindowFullScreen(false);
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
      final currentAudio = _currentTracks?.audio.id;
      actions.add(PopupMenuButton<AudioTrack>(
        icon: const Icon(Icons.multitrack_audio),
        tooltip: 'Audio',
        onSelected: (t) => _ctrl.player.setAudioTrack(t),
        itemBuilder: (_) => [
          for (final (t, label) in _numbered(
              _audioTracks.where((t) => t.id != 'no').toList(), _audioLabel))
            CheckedPopupMenuItem(
                value: t, checked: t.id == currentAudio, child: Text(label)),
        ],
      ));
    }
    // Selección de subtítulos (siempre que exista alguno).
    final subs = _subtitleTracks.where((t) => t.id != 'auto').toList();
    final hasRealSubs = subs.any((t) => t.id != 'no');
    if (hasRealSubs) {
      final currentSub = _currentTracks?.subtitle.id ?? 'no';
      actions.add(PopupMenuButton<SubtitleTrack>(
        icon: const Icon(Icons.subtitles),
        tooltip: 'Subtítulos',
        onSelected: (t) => _ctrl.player.setSubtitleTrack(t),
        itemBuilder: (_) => [
          CheckedPopupMenuItem(
              value: SubtitleTrack.no(),
              checked: currentSub == 'no' || currentSub == 'auto',
              child: Text(_subLabel(SubtitleTrack.no()))),
          for (final (t, label) in _numbered(
              subs.where((t) => t.id != 'no').toList(), _subLabel))
            CheckedPopupMenuItem(
                value: t, checked: t.id == currentSub, child: Text(label)),
        ],
      ));
    }
    // Velocidad de reproducción (solo VOD; el directo va a 1x).
    if (!_isLive) {
      actions.add(PopupMenuButton<double>(
        icon: const Icon(Icons.speed),
        tooltip: 'Velocidad (${_rate}x)',
        initialValue: _rate,
        onSelected: (v) {
          _ctrl.player.setRate(v);
          setState(() => _rate = v);
        },
        itemBuilder: (_) => [
          for (final v in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
            CheckedPopupMenuItem(
                value: v, checked: v == _rate, child: Text('${v}x')),
        ],
      ));
    }
    // Relación de aspecto / zoom.
    actions.add(PopupMenuButton<FitMode>(
      icon: const Icon(Icons.aspect_ratio),
      tooltip: 'Aspecto: ${_fit.label} (A)',
      initialValue: _fit,
      onSelected: (f) => setState(() => _fit = f),
      itemBuilder: (_) => [
        for (final f in FitMode.values)
          CheckedPopupMenuItem(
              value: f, checked: f == _fit, child: Text(f.label)),
      ],
    ));
    return actions;
  }

  /// Diálogo con la información técnica del stream (resolución, códecs...).
  Future<void> _showStats() async {
    final info = await _ctrl.streamInfo();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Información del stream'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in info.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                        width: 150,
                        child: Text(e.key,
                            style: const TextStyle(color: Colors.white54))),
                    Expanded(child: Text(e.value)),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _showHelp() => showDialog<void>(
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
              Text('0-9 — Ir al canal por número'),
              Text('F / doble clic — Pantalla completa'),
              Text('A — Cambiar aspecto/zoom'),
            ],
          ),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido')),
          ],
        ),
      );

  /// Menú de desbordamiento: reiniciar (VOD), info del stream y atajos.
  Widget _moreMenu() => PopupMenuButton<String>(
        tooltip: 'Más opciones',
        onSelected: (v) => switch (v) {
          'restart' => _seekTo(0),
          'stats' => _showStats(),
          _ => _showHelp(),
        },
        itemBuilder: (_) => [
          if (!_isLive)
            const PopupMenuItem(
                value: 'restart',
                child: ListTile(
                    leading: Icon(Icons.replay),
                    title: Text('Reiniciar desde el principio'))),
          const PopupMenuItem(
              value: 'stats',
              child: ListTile(
                  leading: Icon(Icons.monitor_heart_outlined),
                  title: Text('Información del stream'))),
          const PopupMenuItem(
              value: 'ayuda',
              child: ListTile(
                  leading: Icon(Icons.keyboard_outlined),
                  title: Text('Atajos de teclado'))),
        ],
      );

  /// El vídeo sin controles integrados: la barra inferior es nuestra (los
  /// controles por defecto de media_kit fallaban a veces con el avance).
  Widget _rawVideo(BoxFit fit) =>
      Video(controller: _video, fit: fit, controls: NoVideoControls);

  /// El vídeo con el modo de aspecto/zoom elegido.
  Widget _videoView() => switch (_fit) {
        FitMode.auto => Center(child: _rawVideo(BoxFit.contain)),
        FitMode.stretch => Center(child: _rawVideo(BoxFit.fill)),
        FitMode.crop => Center(child: _rawVideo(BoxFit.cover)),
        FitMode.ratio169 => Center(
            child: AspectRatio(
                aspectRatio: 16 / 9, child: _rawVideo(BoxFit.fill))),
        FitMode.ratio43 => Center(
            child: AspectRatio(
                aspectRatio: 4 / 3, child: _rawVideo(BoxFit.fill))),
      };

  String _fmtTime(int s) {
    final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = sec.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  /// Barra de controles inferior propia: progreso con arrastre fiable,
  /// tiempos, play/pausa y ±10s. En directo no hay barra de progreso.
  Widget _bottomBar() {
    final total = _duration.inSeconds;
    final canSeek = !_isLive && total > 0;
    final pos = _dragging
        ? _dragValue.round()
        : _positionSeconds.clamp(0, total > 0 ? total : _positionSeconds);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 26, 10, 6),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0xCC000000)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canSeek)
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6.5),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 13),
              ),
              child: Slider(
                value: pos.toDouble().clamp(0, total.toDouble()),
                max: total.toDouble(),
                onChangeStart: (v) {
                  setState(() {
                    _dragging = true;
                    _dragValue = v;
                  });
                  _pokeUi();
                },
                onChanged: (v) => setState(() => _dragValue = v),
                onChangeEnd: (v) {
                  _dragging = false;
                  _seekTo(v.round());
                },
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: Icon(_playing ? Icons.pause : Icons.play_arrow,
                    size: 30),
                tooltip: _playing ? 'Pausa (Espacio)' : 'Reproducir (Espacio)',
                onPressed: () {
                  _onPlayPause();
                  _pokeUi();
                },
              ),
              if (canSeek) ...[
                IconButton(
                  icon: const Icon(Icons.replay_10),
                  tooltip: 'Retroceder 10 s (←)',
                  onPressed: () {
                    _seekBy(-10);
                    _pokeUi();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.forward_10),
                  tooltip: 'Avanzar 10 s (→)',
                  onPressed: () {
                    _seekBy(10);
                    _pokeUi();
                  },
                ),
              ],
              const SizedBox(width: 6),
              if (_isLive)
                Row(children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: Colors.redAccent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  const Text('DIRECTO',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                ])
              else
                Text(
                  total > 0
                      ? '${_fmtTime(pos)} / ${_fmtTime(total)}'
                      : _fmtTime(pos),
                  style: const TextStyle(
                      fontSize: 12.5, color: Colors.white70),
                ),
              const Spacer(),
              IconButton(
                icon: Icon(_mutedVolume != null
                    ? Icons.volume_off
                    : Icons.volume_up),
                tooltip: 'Silenciar (M)',
                onPressed: () {
                  _toggleMute();
                  _pokeUi();
                  setState(() {});
                },
              ),
              SizedBox(
                width: 110,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 10),
                  ),
                  child: Slider(
                    value: (_mutedVolume != null
                            ? 0.0
                            : _ctrl.player.state.volume)
                        .clamp(0.0, 100.0),
                    max: 100,
                    onChanged: (v) {
                      _mutedVolume = null;
                      _ctrl.player.setVolume(v);
                      setState(() {});
                      _pokeUi();
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Barra superior que se desvanece durante la reproducción (UI inmersiva).
  PreferredSizeWidget _appBar() => PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedOpacity(
          opacity: _uiVisible ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: IgnorePointer(
            ignoring: !_uiVisible,
            child: AppBar(
              backgroundColor: Colors.black.withValues(alpha: 0.55),
              leading: widget.viewerWindow
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Cerrar ventana',
                      onPressed: () => exit(0),
                    )
                  : null,
              title: Text(widget.item.name),
              actions: [
                ..._trackActions(),
                _sleepButton(),
                IconButton(
                  icon: Icon(_fullscreen
                      ? Icons.fullscreen_exit
                      : Icons.fullscreen),
                  tooltip: 'Pantalla completa (F / doble clic)',
                  onPressed: _toggleFullscreen,
                ),
                _moreMenu(),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _appBar(),
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: MouseRegion(
          cursor: _uiVisible ? MouseCursor.defer : SystemMouseCursors.none,
          onHover: (_) => _pokeUi(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _pokeUi,
            onDoubleTap: _toggleFullscreen,
            child: Stack(
              children: [
                _videoView(),
                // Indicador de carga central: visible siempre que el stream
                // esté bufferando (p. ej. tras un salto), independiente de que
                // la barra inferior esté oculta. Así un seek que tarda se ve
                // como "cargando" y no como si estuviera colgado.
                if (_buffering && !_reconnecting)
                  const Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(18),
                        child: SizedBox(
                          width: 46,
                          height: 46,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                      ),
                    ),
                  ),
                // Aviso de reconexión en directo (el stream se cayó y se está
                // reabriendo el mismo canal).
                if (_reconnecting)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                              width: 40,
                              height: 40,
                              child:
                                  CircularProgressIndicator(strokeWidth: 3)),
                          SizedBox(height: 12),
                          Text('Reconectando…',
                              style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                // Controles inferiores propios (progreso, play/pausa, volumen).
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedOpacity(
                    opacity: _uiVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: IgnorePointer(
                      ignoring: !_uiVisible,
                      child: _bottomBar(),
                    ),
                  ),
                ),
                // OSD de canal (nombre + programa actual), se desvanece solo.
                if (_isLive)
                  Positioned(
                    left: 16,
                    bottom: 96,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _osdVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 350),
                        child: _osd(),
                      ),
                    ),
                  ),
                // Número de canal que se está tecleando.
                if (_numBuf.isNotEmpty)
                  Positioned(
                    top: kToolbarHeight + 20,
                    right: 20,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_numBuf,
                            style: const TextStyle(
                                fontSize: 34, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
