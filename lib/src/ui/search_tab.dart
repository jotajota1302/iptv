import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/content_type.dart';
import '../domain/media_item.dart';
import 'play_helpers.dart';

class SearchTab extends ConsumerWidget {
  const SearchTab({super.key});

  static const _filters = <(String, ContentType?)>[
    ('Todo', null),
    ('TV', ContentType.live),
    ('Películas', ContentType.movie),
    ('Series', ContentType.series),
  ];

  IconData _iconFor(ContentType type) => switch (type) {
        ContentType.movie => Icons.movie,
        ContentType.series => Icons.theaters,
        _ => Icons.live_tv,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(searchResultsProvider);
    final filter = ref.watch(searchFilterProvider);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Buscar canales, películas, series',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
        ),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            for (final f in _filters)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f.$1),
                  selected: filter == f.$2,
                  onSelected: (_) =>
                      ref.read(searchFilterProvider.notifier).state = f.$2,
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: results.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (items) {
            final filtered = filter == null
                ? items
                : items.where((i) => i.type == filter).toList();
            if (filtered.isEmpty) {
              return const Center(child: Text('Sin resultados'));
            }
            return ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final MediaItem it = filtered[i];
                return ListTile(
                  leading: Icon(_iconFor(it.type)),
                  title: Text(it.name),
                  subtitle: Text(it.groupTitle ?? ''),
                  onTap: () => openPlayer(context, it),
                );
              },
            );
          },
        ),
      ),
    ]);
  }
}
