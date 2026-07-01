import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/category.dart';
import '../domain/content_type.dart';
import 'continue_watching_row.dart';
import 'movie_grid_screen.dart';

class MoviesTab extends ConsumerWidget {
  const MoviesTab({super.key});

  void _open(BuildContext context, Category cat) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MovieGridScreen(category: cat)),
    );
  }

  Future<void> _hide(WidgetRef ref, Category cat) async {
    await ref
        .read(playlistRepositoryProvider)
        .hideCategoryOf(ContentType.movie, cat.name);
    ref.invalidate(movieCategoriesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(movieCategoriesProvider);
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Películas',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (cats) {
              if (cats.isEmpty) {
                return const Center(
                    child: Text('No hay películas en esta lista'));
              }
              return ListView(
                children: [
                  const ContinueWatchingRow(type: ContentType.movie),
                  for (final cat in cats)
                    ListTile(
                      leading: const Icon(Icons.movie),
                      title: Text(cat.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${cat.itemCount}'),
                          PopupMenuButton<String>(
                            onSelected: (a) {
                              if (a == 'ocultar') _hide(ref, cat);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                  value: 'ocultar',
                                  child: ListTile(
                                      leading: Icon(Icons.visibility_off),
                                      title: Text('Ocultar categoría'))),
                            ],
                          ),
                        ],
                      ),
                      onTap: () => _open(context, cat),
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
