import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../data/series_grouper.dart';
import '../domain/category.dart';
import '../domain/content_type.dart';
import 'continue_watching_row.dart';
import 'play_helpers.dart';
import 'series_grid_screen.dart';
import 'vod_poster.dart';
import 'widgets/category_tile.dart';
import 'widgets/row_grid.dart';
import 'widgets/vod_category_card.dart';

class SeriesTab extends ConsumerStatefulWidget {
  const SeriesTab({super.key});
  @override
  ConsumerState<SeriesTab> createState() => _SeriesTabState();
}

class _SeriesTabState extends ConsumerState<SeriesTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _open(Category cat) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SeriesGridScreen(category: cat)),
    );
  }

  Future<void> _hide(Category cat) async {
    await ref
        .read(playlistRepositoryProvider)
        .hideCategoryOf(ContentType.series, cat.name);
    ref.invalidate(seriesCategoriesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(seriesCategoriesProvider);
    final grid = ref.watch(vodCategoryGridProvider);
    final searching = _query.trim().isNotEmpty;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text('Series',
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
        // Buscador global de series (sin pasar por categorías).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar serie...',
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
                          child: Text('No hay series en esta lista'));
                    }
                    return ListView(
                      children: [
                        const ContinueWatchingRow(type: ContentType.series),
                        if (!grid)
                          RowGrid(
                            shrinkWrap: true,
                            itemCount: cats.length,
                            tileHeight: 68,
                            itemBuilder: (_, i) => CategoryTile(
                              icon: Icons.theaters_outlined,
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

  /// Resultados agrupados: una carátula por serie (no por episodio). Al tocar
  /// se abre el detalle completo de la serie (todas sus temporadas).
  Widget _results() {
    final async = ref
        .watch(searchByTypeProvider((type: ContentType.series, query: _query)));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        final groups = groupSeries(items);
        if (groups.isEmpty) {
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
          itemCount: groups.length,
          itemBuilder: (_, i) {
            final g = groups[i];
            final anyEpisode = g.seasons[g.sortedSeasons.first]!.first.item;
            return VodPoster(
              title: g.title,
              posterUrl: g.poster,
              titleOverlay: true,
              fallbackIcon: Icons.theaters,
              onTap: () => openSeriesDetail(context, ref, anyEpisode),
            );
          },
        );
      },
    );
  }

  Widget _grid(List<Category> cats) {
    final logos =
        ref.watch(categoryLogosProvider(ContentType.series)).value ?? const {};
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
          fallbackIcon: Icons.theaters_outlined,
          countLabel: 'series',
          onTap: () => _open(cat),
          onHide: () => _hide(cat),
        );
      },
    );
  }
}
