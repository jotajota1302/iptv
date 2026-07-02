import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/category.dart';
import '../domain/content_type.dart';
import '../domain/media_item.dart';
import 'channel_list_screen.dart';
import 'player_screen.dart';
import 'widgets/category_tile.dart';
import 'widgets/row_grid.dart';

class LiveTab extends ConsumerStatefulWidget {
  const LiveTab({super.key});
  @override
  ConsumerState<LiveTab> createState() => _LiveTabState();
}

class _LiveTabState extends ConsumerState<LiveTab> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _open(Category cat) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChannelListScreen(category: cat)),
    );
  }

  Future<void> _hide(Category cat) async {
    await ref.read(playlistRepositoryProvider).hideCategory(cat.name);
    ref.invalidate(liveCategoriesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(liveCategoriesProvider);
    final grid = ref.watch(categoryGridProvider);
    final searching = _query.trim().isNotEmpty;
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
        // Buscador global de canales (sin pasar por categorías).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Buscar canal...',
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
                          child:
                              Text('Añade una lista en Ajustes para empezar'));
                    }
                    return grid ? _buildGrid(cats) : _buildList(cats);
                  },
                ),
        ),
      ],
    );
  }

  /// Resultados de búsqueda: la lista sirve además de cola de zapping.
  Widget _results() {
    final async = ref
        .watch(searchByTypeProvider((type: ContentType.live, query: _query)));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(
              child: Text('Sin resultados',
                  style: TextStyle(color: Colors.white54)));
        }
        return RowGrid(
          itemCount: items.length,
          tileHeight: 62,
          itemBuilder: (_, i) {
            final it = items[i];
            return ListTile(
              leading: _logo(it),
              title: Text(it.name, maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              subtitle: it.groupTitle != null
                  ? Text(it.groupTitle!,
                      maxLines: 1, overflow: TextOverflow.ellipsis)
                  : null,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    PlayerScreen(item: it, queue: items, queueIndex: i),
              )),
            );
          },
        );
      },
    );
  }

  Widget _logo(MediaItem it) {
    const fallback = Icon(Icons.live_tv, size: 22, color: Colors.black38);
    return Container(
      width: 46,
      height: 46,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(9),
      ),
      child: it.logoUrl == null
          ? fallback
          : CachedNetworkImage(
              imageUrl: it.logoUrl!,
              fit: BoxFit.contain,
              errorWidget: (_, _, _) => fallback,
            ),
    );
  }

  PopupMenuButton<String> _menu(Category cat) => PopupMenuButton<String>(
        onSelected: (a) {
          if (a == 'ocultar') _hide(cat);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
              value: 'ocultar',
              child: ListTile(
                  leading: Icon(Icons.visibility_off),
                  title: Text('Ocultar categoría'))),
        ],
      );

  Widget _buildList(List<Category> cats) {
    return RowGrid(
      itemCount: cats.length,
      tileHeight: 68,
      itemBuilder: (_, i) {
        final cat = cats[i];
        return CategoryTile(
          icon: Icons.live_tv_outlined,
          name: cat.name,
          count: cat.itemCount,
          onTap: () => _open(cat),
          onHide: () => _hide(cat),
        );
      },
    );
  }

  /// Mini-collage con los primeros logos de la categoría; si no hay logos,
  /// vuelve al icono genérico de TV.
  Widget _collage(Category cat) {
    final logos = ref
            .watch(categoryLogosProvider(ContentType.live))
            .value?[cat.name] ??
        const [];
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

  Widget _buildGrid(List<Category> cats) {
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
            onTap: () => _open(cat),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _collage(cat)),
                      _menu(cat),
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
