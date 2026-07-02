import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/category.dart';
import '../domain/content_type.dart';
import 'continue_watching_row.dart';
import 'movie_detail_screen.dart';
import 'movie_grid_screen.dart';
import 'vod_poster.dart';
import 'widgets/category_tile.dart';
import 'widgets/row_grid.dart';
import 'widgets/vod_category_card.dart';

class MoviesTab extends ConsumerStatefulWidget {
  const MoviesTab({super.key});
  @override
  ConsumerState<MoviesTab> createState() => _MoviesTabState();
}

class _MoviesTabState extends ConsumerState<MoviesTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _open(Category cat) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MovieGridScreen(category: cat)),
    );
  }

  Future<void> _hide(Category cat) async {
    await ref
        .read(playlistRepositoryProvider)
        .hideCategoryOf(ContentType.movie, cat.name);
    ref.invalidate(movieCategoriesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(movieCategoriesProvider);
    final grid = ref.watch(vodCategoryGridProvider);
    final searching = _query.trim().isNotEmpty;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text('Películas',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: Icon(grid ? Icons.view_list : Icons.grid_view),
                tooltip: grid ? 'Ver como lista' : 'Ver como cuadrícula',
                onPressed: () => setVodCategoryGrid(ref, !grid),
              ),
            ],
          ),
        ),
        // Buscador global de películas (sin pasar por categorías).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar película...',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: searching
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: searching
              ? _results()
              : async.when(
                  loading: () => const CategoryListSkeleton(),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (cats) {
                    if (cats.isEmpty) {
                      return const Center(
                          child: Text('No hay películas en esta lista'));
                    }
                    return ListView(
                      children: [
                        const ContinueWatchingRow(type: ContentType.movie),
                        if (!grid)
                          RowGrid(
                            shrinkWrap: true,
                            itemCount: cats.length,
                            tileHeight: 68,
                            itemBuilder: (_, i) => CategoryTile(
                              icon: Icons.movie_outlined,
                              name: cats[i].name,
                              count: cats[i].itemCount,
                              onTap: () => _open(cats[i]),
                              onHide: () => _hide(cats[i]),
                            ),
                          )
                        else
                          _grid(cats),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Resultados de búsqueda como cuadrícula de carátulas.
  Widget _results() {
    final async = ref
        .watch(searchByTypeProvider((type: ContentType.movie, query: _query)));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(
              child: Text('Sin resultados',
                  style: TextStyle(color: Colors.white54)));
        }
        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 140,
            childAspectRatio: 0.62,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final it = items[i];
            return VodPoster(
              title: it.name,
              posterUrl: it.logoUrl,
              titleOverlay: true,
              favorite: it.isFavorite,
              watchedFraction: it.watchedFraction.toDouble(),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MovieDetailScreen(item: it))),
            );
          },
        );
      },
    );
  }

  Widget _grid(List<Category> cats) {
    final logos =
        ref.watch(categoryLogosProvider(ContentType.movie)).value ?? const {};
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 210,
        childAspectRatio: 1.35,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: cats.length,
      itemBuilder: (_, i) {
        final cat = cats[i];
        return VodCategoryCard(
          cat: cat,
          posters: logos[cat.name] ?? const [],
          fallbackIcon: Icons.movie_outlined,
          countLabel: 'películas',
          onTap: () => _open(cat),
          onHide: () => _hide(cat),
        );
      },
    );
  }
}
