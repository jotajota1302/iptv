import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../domain/content_type.dart';
import '../domain/media_item.dart';
import 'play_helpers.dart';

/// Historial de reproducción: todo lo visto (o empezado), más reciente
/// primero, con progreso y acciones para marcar visto o restablecer.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  IconData _iconFor(ContentType type) => switch (type) {
        ContentType.movie => Icons.movie,
        ContentType.series => Icons.theaters,
        _ => Icons.live_tv,
      };

  Future<void> _setWatched(
      WidgetRef ref, MediaItem it, bool watched) async {
    await ref.read(playlistRepositoryProvider).setWatched(it, watched);
    ref.invalidate(historyProvider);
    ref.invalidate(continueWatchingProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(historyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
                child: Text('Aún no has reproducido nada',
                    style: TextStyle(color: Colors.white54)));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) {
              final it = items[i];
              final frac = it.watchedFraction.toDouble();
              final pct = (frac * 100).round();
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 46,
                    height: 46,
                    color: kSurfaceHigh,
                    child: it.logoUrl == null
                        ? Icon(_iconFor(it.type),
                            color: Colors.white38, size: 22)
                        : CachedNetworkImage(
                            imageUrl: it.logoUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => Icon(_iconFor(it.type),
                                color: Colors.white38, size: 22)),
                  ),
                ),
                title: Text(it.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(frac >= 0.9
                    ? 'Visto'
                    : (pct > 0 ? 'Visto al $pct%' : 'Empezado')),
                trailing: PopupMenuButton<String>(
                  onSelected: (a) => _setWatched(ref, it, a == 'visto'),
                  itemBuilder: (_) => [
                    if (frac < 0.9)
                      const PopupMenuItem(
                          value: 'visto',
                          child: Text('Marcar como visto')),
                    const PopupMenuItem(
                        value: 'reset',
                        child: Text('Quitar del historial')),
                  ],
                ),
                onTap: () => openPlayer(context, it),
              );
            },
          );
        },
      ),
    );
  }
}
