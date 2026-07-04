import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../data/series_grouper.dart';
import '../domain/content_type.dart';
import '../domain/media_item.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';

/// Abre el reproductor para cualquier item. El VOD (película/serie) reanuda
/// desde la posición guardada (salvo [fromBeginning]); la TV en directo empieza
/// siempre desde el vivo. Devuelve un Future que se completa al cerrar el
/// reproductor (para refrescar).
Future<void> openPlayer(BuildContext context, MediaItem item,
    {bool fromBeginning = false}) {
  final resume =
      item.type == ContentType.movie || item.type == ContentType.series;
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => PlayerScreen(
        item: item, resume: resume, startFromBeginning: fromBeginning),
  ));
}

String _fmtProgress(int s) {
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = sec.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// Si el VOD tiene progreso guardado (>5 s), pregunta si continuar o empezar de
/// nuevo. Devuelve true = desde el principio, false = continuar, null =
/// cancelado. Sin progreso (o directo) devuelve false sin diálogo.
Future<bool?> chooseStartFromBeginning(
    BuildContext context, WidgetRef ref, MediaItem item) async {
  final resume =
      item.type == ContentType.movie || item.type == ContentType.series;
  if (!resume) return false;
  final saved = await ref.read(playlistRepositoryProvider).progress(item.id);
  if (saved <= 5 || !context.mounted) return false;
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('¿Continuar viendo?'),
      content: Text('Lo dejaste en ${_fmtProgress(saved)}.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desde el principio')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuar')),
      ],
    ),
  );
}

/// Abre el detalle de la serie a la que pertenece [episode]: reconstruye el
/// grupo completo (temporadas/episodios) desde su categoría. Si no se
/// encuentra, reproduce el episodio directamente.
Future<void> openSeriesDetail(
    BuildContext context, WidgetRef ref, MediaItem episode) async {
  final group = episode.groupTitle ?? 'Sin categoria';
  final items =
      await ref.read(playlistRepositoryProvider).seriesByCategory(group);
  final groups = groupSeries(items);
  for (final g in groups) {
    final match =
        g.seasons.values.any((eps) => eps.any((e) => e.item.id == episode.id));
    if (match) {
      if (context.mounted) {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SeriesDetailScreen(series: g)));
      }
      return;
    }
  }
  if (context.mounted) await openPlayer(context, episode);
}
