import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/content_type.dart';
import 'play_helpers.dart';

/// Favoritos con grupos personalizados: chips para filtrar por grupo, y
/// gestión de a qué grupos pertenece cada favorito.
class FavoritesTab extends ConsumerStatefulWidget {
  const FavoritesTab({super.key});
  @override
  ConsumerState<FavoritesTab> createState() => _FavoritesTabState();
}

class _FavoritesTabState extends ConsumerState<FavoritesTab> {
  String? _group; // null = Todos

  Future<void> _newGroupDialog() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo grupo de favoritos'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
              labelText: 'Nombre (p. ej. Deportes, Niños)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Crear')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      ref.read(favGroupsProvider.notifier).createGroup(name);
      setState(() => _group = name.trim());
    }
  }

  /// Diálogo para elegir en qué grupos está un favorito.
  void _groupsDialog(String itemId) {
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final groups = ref.read(favGroupsProvider);
          return AlertDialog(
            title: const Text('Grupos'),
            content: SizedBox(
              width: 320,
              child: groups.isEmpty
                  ? const Text('Crea un grupo con el botón + de arriba.',
                      style: TextStyle(color: Colors.white54))
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final g in groups.keys)
                          CheckboxListTile(
                            title: Text(g),
                            value: ref
                                .read(favGroupsProvider.notifier)
                                .isIn(g, itemId),
                            onChanged: (_) {
                              ref
                                  .read(favGroupsProvider.notifier)
                                  .toggle(g, itemId);
                              setLocal(() {});
                            },
                          ),
                      ],
                    ),
            ),
            actions: [
              FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Hecho')),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(favoritesProvider);
    final groups = ref.watch(favGroupsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (all) {
        if (all.isEmpty) {
          return const Center(child: Text('No tienes favoritos todavía'));
        }
        final ids = _group == null ? null : (groups[_group] ?? const []);
        final items =
            ids == null ? all : all.where((i) => ids.contains(i.id)).toList();
        return Column(
          children: [
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
                    child: ChoiceChip(
                      label: const Text('Todos'),
                      selected: _group == null,
                      onSelected: (_) => setState(() => _group = null),
                    ),
                  ),
                  for (final g in groups.keys)
                    Padding(
                      padding:
                          const EdgeInsets.only(right: 8, top: 6, bottom: 6),
                      child: InputChip(
                        label: Text(g),
                        selected: _group == g,
                        onSelected: (_) => setState(() => _group = g),
                        onDeleted: () {
                          ref.read(favGroupsProvider.notifier).deleteGroup(g);
                          if (_group == g) setState(() => _group = null);
                        },
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 6),
                    child: ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('Grupo'),
                      onPressed: _newGroupDialog,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text('Este grupo está vacío',
                          style: TextStyle(color: Colors.white54)))
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final it = items[i];
                        final icon = switch (it.type) {
                          ContentType.movie => Icons.movie,
                          ContentType.series => Icons.theaters,
                          _ => Icons.live_tv,
                        };
                        return ListTile(
                          leading: Icon(icon),
                          title: Text(it.name),
                          subtitle: it.groupTitle != null
                              ? Text(it.groupTitle!)
                              : null,
                          trailing: PopupMenuButton<String>(
                            onSelected: (a) async {
                              if (a == 'grupos') {
                                _groupsDialog(it.id);
                              } else {
                                await ref
                                    .read(playlistRepositoryProvider)
                                    .toggleFavorite(it);
                                ref.invalidate(favoritesProvider);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                  value: 'grupos',
                                  child: ListTile(
                                      leading: Icon(Icons.folder_outlined),
                                      title: Text('Grupos…'))),
                              PopupMenuItem(
                                  value: 'quitar',
                                  child: ListTile(
                                      leading: Icon(Icons.favorite),
                                      title: Text('Quitar de favoritos'))),
                            ],
                          ),
                          onTap: () => openPlayer(context, it),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
