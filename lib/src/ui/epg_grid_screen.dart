import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../data/epg_service.dart';
import '../domain/media_item.dart';
import '../domain/reminder.dart';
import 'player_screen.dart';

/// Rejilla de programación multicanal (timeline estilo TiviMate): columna
/// fija de canales a la izquierda y programas sobre una línea de tiempo
/// común que se desplaza en horizontal. Datos del EPG XMLTV completo.
class EpgGridScreen extends ConsumerStatefulWidget {
  final String categoryName;
  const EpgGridScreen({super.key, required this.categoryName});

  @override
  ConsumerState<EpgGridScreen> createState() => _EpgGridScreenState();
}

class _EpgGridScreenState extends ConsumerState<EpgGridScreen> {
  static const _pxPerMin = 5.0;
  static const _rowH = 58.0;
  static const _chanColW = 168.0;
  static const _windowHours = 14; // desde 1 h antes de ahora

  late final DateTime _start;
  double _dx = 0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Arranca la ventana 1 h antes de ahora, redondeada a la media hora.
    _start = DateTime(now.year, now.month, now.day, now.hour)
        .subtract(const Duration(hours: 1));
    // Posiciona la vista 30 min antes de ahora.
    _dx = _offsetOf(now.subtract(const Duration(minutes: 30)));
  }

  double _offsetOf(DateTime t) =>
      (t.difference(_start).inMinutes * _pxPerMin).clamp(0.0, _width);

  double get _width => _windowHours * 60 * _pxPerMin;

  void _pan(double delta) {
    setState(() => _dx = (_dx - delta).clamp(0.0, _width - 300));
  }

  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final channelsAsync =
        ref.watch(liveByCategoryProvider(widget.categoryName));
    final guideAsync = ref.watch(xmltvGuideProvider);
    return Scaffold(
      appBar: AppBar(title: Text('Guía · ${widget.categoryName}')),
      body: channelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (channels) {
          if (guideAsync.isLoading) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Descargando guía completa…',
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            );
          }
          final guide = guideAsync.value;
          if (guide == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                    'Este servidor no ofrece guía XMLTV completa.\n'
                    'La guía por canal sigue disponible desde el preview.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54)),
              ),
            );
          }
          return GestureDetector(
            onHorizontalDragUpdate: (d) => _pan(d.delta.dx),
            child: Column(
              children: [
                _timeHeader(),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: channels.length,
                    itemBuilder: (_, i) => _row(channels[i], guide),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Cabecera con las horas (cada 30 min) y la línea de "ahora".
  Widget _timeHeader() {
    final marks = <Widget>[];
    for (var m = 0; m <= _windowHours * 60; m += 30) {
      final t = _start.add(Duration(minutes: m));
      marks.add(Positioned(
        left: m * _pxPerMin + 4,
        top: 8,
        child: Text(_hhmm(t),
            style: const TextStyle(fontSize: 11, color: Colors.white54)),
      ));
    }
    return SizedBox(
      height: 30,
      child: Row(
        children: [
          const SizedBox(
            width: _chanColW,
            child: Padding(
              padding: EdgeInsets.only(left: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Canal',
                    style: TextStyle(fontSize: 11, color: Colors.white38)),
              ),
            ),
          ),
          Expanded(
            child: ClipRect(
              child: Transform.translate(
                offset: Offset(-_dx, 0),
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  maxWidth: _width,
                  child: SizedBox(
                    width: _width,
                    height: 30,
                    child: Stack(children: [...marks, _nowLine(30)]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nowLine(double height) => Positioned(
        left: _offsetOf(DateTime.now()),
        top: 0,
        child: Container(width: 2, height: height, color: Colors.redAccent),
      );

  Widget _row(MediaItem channel, dynamic guide) {
    final entries =
        (guide.forChannel(channel.tvgId, channel.name) as List<EpgEntry>);
    final now = DateTime.now();
    final end = _start.add(Duration(hours: _windowHours));
    final blocks = <Widget>[];
    for (final e in entries) {
      if (e.end.isBefore(_start) || e.start.isAfter(end)) continue;
      final left = e.start.isBefore(_start) ? 0.0 : _offsetOf(e.start);
      final right = e.end.isAfter(end) ? _width : _offsetOf(e.end);
      final w = right - left;
      if (w < 8) continue;
      final onNow = !now.isBefore(e.start) && now.isBefore(e.end);
      final hasReminder = ref.watch(remindersProvider
          .select((l) => l.any((r) => r.id == _reminderId(channel, e))));
      blocks.add(Positioned(
        left: left,
        top: 4,
        width: w - 3,
        height: _rowH - 8,
        child: InkWell(
          onTap: () => _programDialog(channel, e),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: onNow
                  ? kAccent.withValues(alpha: 0.28)
                  : kSurfaceHigh,
              borderRadius: BorderRadius.circular(8),
              border: onNow ? Border.all(color: kAccent, width: 1) : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (hasReminder)
                      const Padding(
                        padding: EdgeInsets.only(right: 3),
                        child: Icon(Icons.notifications_active,
                            size: 12, color: Colors.amberAccent),
                      ),
                    Expanded(
                      child: Text(e.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text('${_hhmm(e.start)}–${_hhmm(e.end)}',
                    style: const TextStyle(
                        fontSize: 10.5, color: Colors.white54)),
              ],
            ),
          ),
        ),
      ));
    }

    return SizedBox(
      height: _rowH,
      child: Row(
        children: [
          SizedBox(
            width: _chanColW,
            child: InkWell(
              onTap: () => _play(channel),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: channel.logoUrl == null
                          ? const Icon(Icons.live_tv,
                              size: 16, color: Colors.black38)
                          : CachedNetworkImage(
                              imageUrl: channel.logoUrl!,
                              fit: BoxFit.contain,
                              errorWidget: (_, _, _) => const Icon(
                                  Icons.live_tv,
                                  size: 16,
                                  color: Colors.black38)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(channel.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, height: 1.1)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ClipRect(
              child: Transform.translate(
                offset: Offset(-_dx, 0),
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  maxWidth: _width,
                  child: SizedBox(
                    width: _width,
                    height: _rowH,
                    child: Stack(children: [...blocks, _nowLine(_rowH)]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _reminderId(MediaItem c, EpgEntry e) =>
      '${c.streamUrl}@${e.start.millisecondsSinceEpoch}';

  void _play(MediaItem channel) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerScreen(item: channel),
    ));
  }

  /// Detalle del programa: sinopsis y acciones (recordar / ver canal).
  void _programDialog(MediaItem channel, EpgEntry e) {
    final future = e.start.isAfter(DateTime.now());
    final id = _reminderId(channel, e);
    final reminders = ref.read(remindersProvider.notifier);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${channel.name} · ${_hhmm(e.start)}–${_hhmm(e.end)}',
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
            if ((e.description ?? '').isNotEmpty) ...[
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Text(e.description!,
                    style: const TextStyle(height: 1.4)),
              ),
            ],
          ],
        ),
        actions: [
          if (future)
            TextButton.icon(
              icon: Icon(reminders.contains(id)
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_active_outlined),
              label: Text(
                  reminders.contains(id) ? 'Quitar aviso' : 'Recordar'),
              onPressed: () {
                if (reminders.contains(id)) {
                  reminders.remove(id);
                } else {
                  reminders.add(Reminder(
                    channelName: channel.name,
                    channelUrl: channel.streamUrl,
                    title: e.title,
                    start: e.start,
                  ));
                }
                Navigator.pop(ctx);
              },
            ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _play(channel);
            },
            child: const Text('Ver canal'),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar')),
        ],
      ),
    );
  }
}
