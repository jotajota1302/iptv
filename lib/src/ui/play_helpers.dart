import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../data/series_grouper.dart';
import '../domain/content_type.dart';
import '../domain/media_item.dart';
import 'player_screen.dart';
import 'series_detail_screen.dart';

/// Abre el reproductor para cualquier item. El VOD (película/serie) reanuda
/// desde la posición guardada; la TV en directo empieza siempre desde el vivo.
/// Devuelve un Future que se completa al cerrar el reproductor (para refrescar).
Future<void> openPlayer(BuildContext context, MediaItem item) {
  final resume =
      item.type == ContentType.movie || item.type == ContentType.series;
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => PlayerScreen(item: item, resume: resume),
  ));
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
