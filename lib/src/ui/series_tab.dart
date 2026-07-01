import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/category.dart';
import '../domain/content_type.dart';
import 'continue_watching_row.dart';
import 'series_grid_screen.dart';
import 'widgets/category_tile.dart';

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
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Series',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
                  for (final cat in cats)
                    CategoryTile(
                      icon: Icons.theaters_outlined,
                      name: cat.name,
                      count: cat.itemCount,
                      onTap: () => _open(context, cat),
                      onHide: () => _hide(ref, cat),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
