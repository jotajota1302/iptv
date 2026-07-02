import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/category.dart';
import '../domain/content_type.dart';
import 'continue_watching_row.dart';
import 'series_grid_screen.dart';
import 'widgets/category_tile.dart';
import 'widgets/vod_category_card.dart';

class SeriesTab extends ConsumerWidget {
  const SeriesTab({super.key});

  void _open(BuildContext context, Category cat) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SeriesGridScreen(category: cat)),
    );
  }

  Future<void> _hide(WidgetRef ref, Category cat) async {
    await ref
        .read(playlistRepositoryProvider)
        .hideCategoryOf(ContentType.series, cat.name);
    ref.invalidate(seriesCategoriesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(seriesCategoriesProvider);
    final grid = ref.watch(vodCategoryGridProvider);
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
        Expanded(
          child: async.when(
            loading: () => const CategoryListSkeleton(),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (cats) {
              if (cats.isEmpty) {
                return const Center(child: Text('No hay series en esta lista'));
              }
              return ListView(
                children: [
                  const ContinueWatchingRow(type: ContentType.series),
                  if (!grid)
                    for (final cat in cats)
                      CategoryTile(
                        icon: Icons.theaters_outlined,
                        name: cat.name,
                        count: cat.itemCount,
                        onTap: () => _open(context, cat),
                        onHide: () => _hide(ref, cat),
                      )
                  else
                    _grid(context, ref, cats),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _grid(BuildContext context, WidgetRef ref, List<Category> cats) {
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
          onTap: () => _open(context, cat),
          onHide: () => _hide(ref, cat),
        );
      },
    );
  }
}
