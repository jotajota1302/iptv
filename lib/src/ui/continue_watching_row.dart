import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/content_type.dart';
import 'play_helpers.dart';
import 'vod_poster.dart';

/// Fila horizontal "Continuar viendo" con las películas/series empezadas.
/// Si [type] no es null, filtra por ese tipo. Se oculta si no hay nada.
class ContinueWatchingRow extends ConsumerWidget {
  final ContentType? type;
  const ContinueWatchingRow({super.key, this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(continueWatchingProvider);
    final items = (async.value ?? const [])
        .where((i) => type == null || i.type == type)
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(children: [
            Icon(Icons.play_circle_outline, size: 20),
            SizedBox(width: 6),
            Text('Continuar viendo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ]),
        ),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final it = items[i];
              return SizedBox(
                width: 120,
                child: VodPoster(
                  title: it.name,
                  posterUrl: it.logoUrl,
                  fallbackIcon: it.type == ContentType.series
                      ? Icons.theaters
                      : Icons.movie,
                  watchedFraction: it.watchedFraction.toDouble(),
                  onTap: () {
                    openPlayer(context, it);
                    // Al volver, refresca el progreso.
                    ref.invalidate(continueWatchingProvider);
                  },
                ),
              );
            },
          ),
        ),
        const Divider(height: 16),
      ],
    );
  }
}
