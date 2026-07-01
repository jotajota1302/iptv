import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/category.dart';
import '../domain/media_item.dart';
import 'player_screen.dart';

class ChannelListScreen extends ConsumerWidget {
  final Category category;
  const ChannelListScreen({super.key, required this.category});

  void _play(BuildContext context, MediaItem it) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerScreen(item: it)),
    );
  }

  Future<void> _action(WidgetRef ref, String action, MediaItem it) async {
    final repo = ref.read(playlistRepositoryProvider);
    if (action == 'favorito') {
      await repo.toggleFavorite(it);
    } else if (action == 'ocultar') {
      await repo.hideItem(it);
    } else if (action == 'borrar') {
      await repo.deleteItem(it);
    }
    ref.invalidate(liveByCategoryProvider(category.name));
    ref.invalidate(liveCategoriesProvider);
    ref.invalidate(favoritesProvider);
  }

  PopupMenuButton<String> _menu(WidgetRef ref, MediaItem it) =>
      PopupMenuButton<String>(
        onSelected: (a) => _action(ref, a, it),
        itemBuilder: (_) => [
          PopupMenuItem(
              value: 'favorito',
              child: Text(it.isFavorite
                  ? 'Quitar de favoritos'
                  : 'Añadir a favoritos')),
          const PopupMenuItem(value: 'ocultar', child: Text('Ocultar')),
          const PopupMenuItem(value: 'borrar', child: Text('Borrar')),
        ],
      );

  Widget _logo(MediaItem it, {double size = 48}) => it.logoUrl == null
      ? Icon(Icons.live_tv, size: size)
      : CachedNetworkImage(
          imageUrl: it.logoUrl!,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorWidget: (_, _, _) => Icon(Icons.live_tv, size: size),
        );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(liveByCategoryProvider(category.name));
    final grid = ref.watch(channelGridProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(category.name),
        actions: [
          IconButton(
            icon: Icon(grid ? Icons.view_list : Icons.grid_view),
            tooltip: grid ? 'Ver como lista' : 'Ver como cuadrícula',
            onPressed: () => setChannelGrid(ref, !grid),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) => grid
            ? _buildGrid(context, ref, items)
            : _buildList(context, ref, items),
      ),
    );
  }

  Widget _buildList(BuildContext context, WidgetRef ref, List<MediaItem> items) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final it = items[i];
        return ListTile(
          leading: _logo(it),
          title: Text(it.name),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                    it.isFavorite ? Icons.favorite : Icons.favorite_border),
                onPressed: () => _action(ref, 'favorito', it),
              ),
              _menu(ref, it),
            ],
          ),
          onTap: () => _play(context, it),
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context, WidgetRef ref, List<MediaItem> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        childAspectRatio: 0.82,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final it = items[i];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _play(context, it),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Center(child: _logo(it, size: 64)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    it.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      iconSize: 20,
                      icon: Icon(it.isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border),
                      onPressed: () => _action(ref, 'favorito', it),
                    ),
                    _menu(ref, it),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
