import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/category.dart';
import 'channel_list_screen.dart';
import 'widgets/category_tile.dart';

class LiveTab extends ConsumerWidget {
  const LiveTab({super.key});

  void _open(BuildContext context, Category cat) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChannelListScreen(category: cat)),
    );
  }

  Future<void> _hide(WidgetRef ref, Category cat) async {
    await ref.read(playlistRepositoryProvider).hideCategory(cat.name);
    ref.invalidate(liveCategoriesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(liveCategoriesProvider);
    final grid = ref.watch(categoryGridProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text('TV en directo',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ),
              IconButton(
                icon: Icon(grid ? Icons.view_list : Icons.grid_view),
                tooltip: grid ? 'Ver como lista' : 'Ver como cuadrícula',
                onPressed: () => setCategoryGrid(ref, !grid),
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
                return const Center(
                    child: Text('Añade una lista en Ajustes para empezar'));
              }
              return grid
                  ? _buildGrid(context, ref, cats)
                  : _buildList(context, ref, cats);
            },
          ),
        ),
      ],
    );
  }

  PopupMenuButton<String> _menu(WidgetRef ref, Category cat) =>
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
      );

  Widget _buildList(BuildContext context, WidgetRef ref, List<Category> cats) {
    return ListView.builder(
      itemCount: cats.length,
      itemBuilder: (_, i) {
        final cat = cats[i];
        return CategoryTile(
          icon: Icons.live_tv_outlined,
          name: cat.name,
          count: cat.itemCount,
          onTap: () => _open(context, cat),
          onHide: () => _hide(ref, cat),
        );
      },
    );
  }

  /// Mini-collage con los primeros logos de la categoría; si no hay logos,
  /// vuelve al icono genérico de TV.
  Widget _collage(WidgetRef ref, Category cat) {
    final logos =
        ref.watch(liveCategoryLogosProvider).value?[cat.name] ?? const [];
    if (logos.isEmpty) return const Icon(Icons.live_tv, size: 28);
    return Row(
      children: [
        for (final url in logos)
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 5),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(7),
            ),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              errorWidget: (_, _, _) =>
                  const Icon(Icons.live_tv, size: 14, color: Colors.black26),
            ),
          ),
      ],
    );
  }

  Widget _buildGrid(BuildContext context, WidgetRef ref, List<Category> cats) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 1.4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: cats.length,
      itemBuilder: (_, i) {
        final cat = cats[i];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _open(context, cat),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _collage(ref, cat)),
                      _menu(ref, cat),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    cat.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text('${cat.itemCount} canales',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
