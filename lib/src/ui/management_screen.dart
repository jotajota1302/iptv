import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/category.dart';
import '../domain/content_type.dart';
import '../domain/media_item.dart';

/// Invalida los providers de navegación visibles del tipo dado (para que la UI
/// refleje ocultar/restaurar al instante).
void _invalidateNav(WidgetRef ref, ContentType type, String group) {
  ref.invalidate(favoritesProvider);
  switch (type) {
    case ContentType.live:
      ref.invalidate(liveCategoriesProvider);
      ref.invalidate(liveByCategoryProvider(group));
    case ContentType.movie:
      ref.invalidate(movieCategoriesProvider);
      ref.invalidate(moviesByCategoryProvider(group));
    case ContentType.series:
      ref.invalidate(seriesCategoriesProvider);
      ref.invalidate(seriesGroupsByCategoryProvider(group));
    case ContentType.unknown:
      break;
  }
}

String _titleFor(ContentType type) {
  switch (type) {
    case ContentType.movie:
      return 'Gestionar películas';
    case ContentType.series:
      return 'Gestionar series';
    default:
      return 'Gestionar canales';
  }
}

/// Lista de categorías de un tipo (incluye las que tienen items ocultos).
class ManagementScreen extends ConsumerWidget {
  final ContentType type;
  const ManagementScreen({super.key, this.type = ContentType.live});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(manageCategoriesByTypeProvider(type));
    final hidden =
        ref.watch(hiddenCountsByTypeProvider(type)).value ?? const <String, int>{};

    void refresh(String group) {
      ref.invalidate(manageCategoriesByTypeProvider(type));
      ref.invalidate(hiddenCountsByTypeProvider(type));
      ref.invalidate(manageByCategoryProvider((type: type, group: group)));
      _invalidateNav(ref, type, group);
    }

    return Scaffold(
      appBar: AppBar(title: Text(_titleFor(type))),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (cats) => cats.isEmpty
            ? const Center(child: Text('Añade una lista primero'))
            : ListView.builder(
                itemCount: cats.length,
                itemBuilder: (_, i) {
                  final cat = cats[i];
                  final nHidden = hidden[cat.name] ?? 0;
                  return ListTile(
                    leading: Icon(
                      nHidden > 0 ? Icons.visibility_off : Icons.folder_open,
                      color: nHidden > 0 ? Colors.orange : null,
                    ),
                    title: Text(cat.name),
                    subtitle: nHidden > 0
                        ? Text('$nHidden oculto(s) / borrado(s)',
                            style: const TextStyle(color: Colors.orange))
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${cat.itemCount}'),
                        if (nHidden > 0)
                          IconButton(
                            icon: const Icon(Icons.restore),
                            tooltip: 'Restaurar categoría',
                            onPressed: () async {
                              await ref
                                  .read(playlistRepositoryProvider)
                                  .restoreCategoryOf(type, cat.name);
                              refresh(cat.name);
                            },
                          ),
                        PopupMenuButton<String>(
                          onSelected: (action) async {
                            final repo = ref.read(playlistRepositoryProvider);
                            if (action == 'ocultar') {
                              await repo.hideCategoryOf(type, cat.name);
                            } else if (action == 'restaurar') {
                              await repo.restoreCategoryOf(type, cat.name);
                            }
                            refresh(cat.name);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'ocultar',
                                child: Text('Ocultar categoría')),
                            PopupMenuItem(
                                value: 'restaurar',
                                child: Text('Restaurar categoría')),
                          ],
                        ),
                      ],
                    ),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ManageCategoryScreen(category: cat),
                    )),
                  );
                },
              ),
      ),
    );
  }
}

/// Items de una categoría con su estado y acciones de gestión.
class ManageCategoryScreen extends ConsumerWidget {
  final Category category;
  const ManageCategoryScreen({super.key, required this.category});

  ({String label, Color color, IconData icon}) _status(MediaItem it) {
    if (it.isDeleted) {
      return (label: 'Borrado', color: Colors.red, icon: Icons.delete);
    }
    if (it.isHidden) {
      return (label: 'Oculto', color: Colors.orange, icon: Icons.visibility_off);
    }
    return (label: 'Visible', color: Colors.green, icon: Icons.visibility);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = category.type;
    final key = (type: type, group: category.name);
    final async = ref.watch(manageByCategoryProvider(key));

    void refresh() {
      ref.invalidate(manageByCategoryProvider(key));
      ref.invalidate(manageCategoriesByTypeProvider(type));
      ref.invalidate(hiddenCountsByTypeProvider(type));
      _invalidateNav(ref, type, category.name);
    }

    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) => ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) {
            final it = items[i];
            final st = _status(it);
            final repo = ref.read(playlistRepositoryProvider);
            final oculto = it.isHidden || it.isDeleted;
            return ListTile(
              leading: Icon(st.icon, color: st.color),
              title: Text(it.name),
              subtitle: Text(st.label, style: TextStyle(color: st.color)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (oculto)
                    IconButton(
                      icon: const Icon(Icons.restore),
                      tooltip: 'Restaurar',
                      onPressed: () async {
                        await repo.restoreItem(it);
                        refresh();
                      },
                    ),
                  PopupMenuButton<String>(
                    onSelected: (action) async {
                      if (action == 'ocultar') await repo.hideItem(it);
                      if (action == 'borrar') await repo.deleteItem(it);
                      if (action == 'restaurar') await repo.restoreItem(it);
                      refresh();
                    },
                    itemBuilder: (_) => [
                      if (!oculto) ...const [
                        PopupMenuItem(value: 'ocultar', child: Text('Ocultar')),
                        PopupMenuItem(value: 'borrar', child: Text('Borrar')),
                      ],
                      if (oculto)
                        const PopupMenuItem(
                            value: 'restaurar', child: Text('Restaurar')),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
