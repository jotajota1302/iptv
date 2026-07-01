import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/series_group.dart';
import 'play_helpers.dart';

/// Detalle de una serie: una sección plegable (ExpansionTile) por temporada,
/// con la lista de episodios. Tocar un episodio lo reproduce con reanudación;
/// cada episodio se puede marcar como favorito.
class SeriesDetailScreen extends ConsumerWidget {
  final SeriesGroup series;
  const SeriesDetailScreen({super.key, required this.series});

  String _seasonLabel(int s) => s == 0 ? 'Episodios' : 'Temporada $s';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasons = series.sortedSeasons;
    return Scaffold(
      appBar: AppBar(title: Text(series.title)),
      body: ListView.builder(
        itemCount: seasons.length,
        itemBuilder: (_, i) {
          final s = seasons[i];
          final episodes = series.seasons[s]!;
          return ExpansionTile(
            title: Text(_seasonLabel(s)),
            subtitle: Text('${episodes.length} episodio(s)'),
            initiallyExpanded: seasons.length == 1,
            children: [
              for (final e in episodes)
                ListTile(
                  leading: CircleAvatar(
                    child: Text(e.episode > 0 ? '${e.episode}' : '•'),
                  ),
                  title: Text(e.item.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(e.item.isFavorite
                            ? Icons.favorite
                            : Icons.favorite_border),
                        tooltip: 'Favorito',
                        onPressed: () async {
                          await ref
                              .read(playlistRepositoryProvider)
                              .toggleFavorite(e.item);
                          ref.invalidate(favoritesProvider);
                        },
                      ),
                      const Icon(Icons.play_arrow),
                    ],
                  ),
                  onTap: () => openPlayer(context, e.item),
                ),
            ],
          );
        },
      ),
    );
  }
}
