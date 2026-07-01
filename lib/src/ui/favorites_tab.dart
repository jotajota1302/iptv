import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import 'player_screen.dart';

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
            return ListTile(
              leading: const Icon(Icons.favorite),
              title: Text(it.name),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await ref.read(playlistRepositoryProvider).toggleFavorite(it);
                  ref.invalidate(favoritesProvider);
                },
              ),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PlayerScreen(item: it),
              )),
            );
          },
        );
      },
    );
  }
}
