import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/category.dart';
import 'player_screen.dart';

class ChannelListScreen extends ConsumerWidget {
  final Category category;
  const ChannelListScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(liveByCategoryProvider(category.name));
    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) => ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) {
            final it = items[i];
            return ListTile(
              leading: it.logoUrl == null
                  ? const Icon(Icons.live_tv)
                  : CachedNetworkImage(
                      imageUrl: it.logoUrl!,
                      width: 48,
                      errorWidget: (_, _, _) => const Icon(Icons.live_tv),
                    ),
              title: Text(it.name),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(it.isFavorite
                        ? Icons.favorite
                        : Icons.favorite_border),
                    onPressed: () async {
                      await ref
                          .read(playlistRepositoryProvider)
                          .toggleFavorite(it);
                      ref.invalidate(liveByCategoryProvider(category.name));
                      ref.invalidate(favoritesProvider);
                    },
                  ),
                  PopupMenuButton<String>(
                    onSelected: (action) async {
                      final repo = ref.read(playlistRepositoryProvider);
                      if (action == 'ocultar') {
                        await repo.hideItem(it);
                      } else if (action == 'borrar') {
                        await repo.deleteItem(it);
                      }
                      ref.invalidate(liveByCategoryProvider(category.name));
                      ref.invalidate(liveCategoriesProvider);
                      ref.invalidate(favoritesProvider);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'ocultar',
                          child: ListTile(
                              leading: Icon(Icons.visibility_off),
                              title: Text('Ocultar'))),
                      PopupMenuItem(
                          value: 'borrar',
                          child: ListTile(
                              leading: Icon(Icons.delete_outline),
                              title: Text('Borrar'))),
                    ],
                  ),
                ],
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PlayerScreen(item: it)),
              ),
            );
          },
        ),
      ),
    );
  }
}
