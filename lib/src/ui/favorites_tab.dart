import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/content_type.dart';
import 'play_helpers.dart';

class FavoritesTab extends ConsumerWidget {
  const FavoritesTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(favoritesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('No tienes favoritos todavía'));
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) {
            final it = items[i];
            final icon = switch (it.type) {
              ContentType.movie => Icons.movie,
              ContentType.series => Icons.theaters,
              _ => Icons.live_tv,
            };
            return ListTile(
              leading: Icon(icon),
              title: Text(it.name),
              subtitle: it.groupTitle != null ? Text(it.groupTitle!) : null,
              trailing: IconButton(
                icon: const Icon(Icons.favorite),
                tooltip: 'Quitar de favoritos',
                onPressed: () async {
                  await ref.read(playlistRepositoryProvider).toggleFavorite(it);
                  ref.invalidate(favoritesProvider);
                },
              ),
              onTap: () => openPlayer(context, it),
            );
          },
        );
      },
    );
  }
}
