import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../data/series_grouper.dart';
import '../domain/content_type.dart';
import '../domain/media_item.dart';
import '../domain/series_group.dart';
import 'movie_detail_screen.dart';
import 'play_helpers.dart';
import 'widgets/row_grid.dart';

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

  Widget _section(String title, int count) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Row(
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Text('$count',
                style: const TextStyle(fontSize: 13, color: Colors.white38)),
          ],
        ),
      );

  /// Fila de serie agrupada: una entrada por serie (no una por episodio).
  Widget _seriesRow(BuildContext context, WidgetRef ref, SeriesGroup g) {
    final anyEpisode =
        g.seasons[g.sortedSeasons.first]!.first.item;
    return ListTile(
      leading: _thumb(anyEpisode),
      title: Text(g.title),
      subtitle: Text('${g.sortedSeasons.length} temporada(s) · '
          '${g.episodeCount} episodio(s) encontrados'),
      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      onTap: () => openSeriesDetail(context, ref, anyEpisode),
    );
  }

  Widget _thumb(MediaItem it) {
    final icon = Icon(_iconFor(it.type), color: Colors.white38, size: 22);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 46,
        height: 46,
        color: kSurfaceHigh,
        child: it.logoUrl == null
            ? icon
            : CachedNetworkImage(
                imageUrl: it.logoUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => icon,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(searchResultsProvider);
    final filter = ref.watch(searchFilterProvider);
    final query = ref.watch(searchQueryProvider);
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
        child: query.trim().isEmpty
            ? const _SearchHint()
            : results.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (items) {
                  final filtered = filter == null
                      ? items
                      : items.where((i) => i.type == filter).toList();
                  if (filtered.isEmpty) {
                    return const _SearchEmpty();
                  }
                  // Secciones por tipo; los episodios de series se agrupan en
                  // una sola fila por serie para poder navegar por temporadas.
                  final tv = [
                    for (final i in filtered)
                      if (i.type == ContentType.live) i
                  ];
                  final movies = [
                    for (final i in filtered)
                      if (i.type == ContentType.movie) i
                  ];
                  final seriesGroups = groupSeries([
                    for (final i in filtered)
                      if (i.type == ContentType.series) i
                  ]);
                  // Cada sección en columnas responsivas (RowGrid) para no
                  // desperdiciar el ancho en escritorio.
                  return ListView(
                    children: [
                      if (tv.isNotEmpty) ...[
                        _section('TV', tv.length),
                        RowGrid(
                          shrinkWrap: true,
                          itemCount: tv.length,
                          tileHeight: 62,
                          itemBuilder: (_, i) => ListTile(
                            leading: _thumb(tv[i]),
                            title: Text(tv[i].name,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(tv[i].groupTitle ?? '',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () => openPlayer(context, tv[i]),
                          ),
                        ),
                      ],
                      if (movies.isNotEmpty) ...[
                        _section('Películas', movies.length),
                        RowGrid(
                          shrinkWrap: true,
                          itemCount: movies.length,
                          tileHeight: 62,
                          itemBuilder: (_, i) => ListTile(
                            leading: _thumb(movies[i]),
                            title: Text(movies[i].name,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(movies[i].groupTitle ?? '',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      MovieDetailScreen(item: movies[i])),
                            ),
                          ),
                        ),
                      ],
                      if (seriesGroups.isNotEmpty) ...[
                        _section('Series', seriesGroups.length),
                        RowGrid(
                          shrinkWrap: true,
                          itemCount: seriesGroups.length,
                          tileHeight: 62,
                          itemBuilder: (_, i) =>
                              _seriesRow(context, ref, seriesGroups[i]),
                        ),
                      ],
                    ],
                  );
                },
              ),
      ),
    ]);
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search, size: 64, color: Colors.white24),
              SizedBox(height: 12),
              Text('Busca canales, películas y series',
                  style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
}

class _SearchEmpty extends StatelessWidget {
  const _SearchEmpty();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.white24),
              SizedBox(height: 12),
              Text('Sin resultados', style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
}
