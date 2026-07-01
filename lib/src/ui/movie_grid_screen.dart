import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/category.dart';
import '../domain/media_item.dart';
import '../domain/sort_mode.dart';
import 'movie_detail_screen.dart';
import 'sort_menu.dart';
import 'vod_poster.dart';

/// Cuadrícula de carátulas de películas (poster 2:3) con buscador, progreso
/// de "continuar viendo" y menú por película (favorito/ocultar/borrar).
class MovieGridScreen extends ConsumerStatefulWidget {
  final Category category;
  const MovieGridScreen({super.key, required this.category});

  @override
  ConsumerState<MovieGridScreen> createState() => _MovieGridScreenState();
}

class _MovieGridScreenState extends ConsumerState<MovieGridScreen> {
  String _query = '';

  void _refresh() {
    ref.invalidate(moviesByCategoryProvider(widget.category.name));
    ref.invalidate(movieCategoriesProvider);
    ref.invalidate(favoritesProvider);
    ref.invalidate(continueWatchingProvider);
  }

  Future<void> _menu(MediaItem it) async {
    final repo = ref.read(playlistRepositoryProvider);
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                  it.isFavorite ? Icons.favorite : Icons.favorite_border),
              title: Text(
                  it.isFavorite ? 'Quitar de favoritos' : 'Añadir a favoritos'),
              onTap: () async {
                await repo.toggleFavorite(it);
                if (mounted) Navigator.pop(context);
                _refresh();
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off),
              title: const Text('Ocultar'),
              onTap: () async {
                await repo.hideItem(it);
                if (mounted) Navigator.pop(context);
                _refresh();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Borrar'),
              onTap: () async {
                await repo.deleteItem(it);
                if (mounted) Navigator.pop(context);
                _refresh();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(moviesByCategoryProvider(widget.category.name));
    final sort = ref.watch(sortModeProvider);
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.category.name), actions: const [SortMenu()]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Filtrar en esta categoría',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (all) {
                final filtered = _query.isEmpty
                    ? all
                    : all
                        .where((m) => m.name.toLowerCase().contains(_query))
                        .toList();
                final movies = sortItems(filtered, sort);
                if (movies.isEmpty) {
                  return const Center(child: Text('Sin resultados'));
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 140,
                    childAspectRatio: 0.6,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: movies.length,
                  itemBuilder: (_, i) {
                    final it = movies[i];
                    return VodPoster(
                      title: it.name,
                      posterUrl: it.logoUrl,
                      watchedFraction: it.watchedFraction.toDouble(),
                      favorite: it.isFavorite,
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => MovieDetailScreen(item: it),
                        ));
                        ref.invalidate(
                            moviesByCategoryProvider(widget.category.name));
                        ref.invalidate(continueWatchingProvider);
                      },
                      onLongPress: () => _menu(it),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
