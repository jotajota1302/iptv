import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/category.dart';
import '../domain/media_item.dart';

/// Lista de categorías en directo (incluye las que tienen canales ocultos).
class ManagementScreen extends ConsumerWidget {
  const ManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(manageCategoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar canales')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (cats) => cats.isEmpty
            ? const Center(child: Text('Añade una lista primero'))
            : ListView.builder(
                itemCount: cats.length,
                itemBuilder: (_, i) {
                  final cat = cats[i];
                  return ListTile(
                    title: Text(cat.name),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${cat.itemCount}'),
                        PopupMenuButton<String>(
                          onSelected: (action) async {
                            final repo = ref.read(playlistRepositoryProvider);
                            if (action == 'ocultar') {
                              await repo.hideCategory(cat.name);
                            } else if (action == 'restaurar') {
                              await repo.restoreCategory(cat.name);
                            }
                            ref.invalidate(manageCategoriesProvider);
                            ref.invalidate(
                                manageLiveByCategoryProvider(cat.name));
                            ref.invalidate(liveByCategoryProvider(cat.name));
                            ref.invalidate(liveCategoriesProvider);
                            ref.invalidate(favoritesProvider);
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

/// Canales de una categoría con su estado y acciones de gestión.
class ManageCategoryScreen extends ConsumerWidget {
  final Category category;
  const ManageCategoryScreen({super.key, required this.category});

  ({String label, Color color}) _status(MediaItem it) {
    if (it.isDeleted) return (label: 'Borrado', color: Colors.red);
    if (it.isHidden) return (label: 'Oculto', color: Colors.orange);
    return (label: 'Visible', color: Colors.green);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(manageLiveByCategoryProvider(category.name));

    void refresh() {
      ref.invalidate(manageLiveByCategoryProvider(category.name));
      ref.invalidate(manageCategoriesProvider);
      ref.invalidate(liveByCategoryProvider(category.name));
      ref.invalidate(liveCategoriesProvider);
      ref.invalidate(favoritesProvider);
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
            return ListTile(
              title: Text(it.name),
              subtitle: Text(st.label, style: TextStyle(color: st.color)),
              trailing: PopupMenuButton<String>(
                onSelected: (action) async {
                  if (action == 'ocultar') await repo.hideItem(it);
                  if (action == 'borrar') await repo.deleteItem(it);
                  if (action == 'restaurar') await repo.restoreItem(it);
                  refresh();
                },
                itemBuilder: (_) => [
                  if (!it.isHidden && !it.isDeleted) ...const [
                    PopupMenuItem(value: 'ocultar', child: Text('Ocultar')),
                    PopupMenuItem(value: 'borrar', child: Text('Borrar')),
                  ],
                  if (it.isHidden || it.isDeleted)
                    const PopupMenuItem(
                        value: 'restaurar', child: Text('Restaurar')),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
