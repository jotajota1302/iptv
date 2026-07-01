import 'package:flutter/material.dart';
import '../domain/series_group.dart';
import 'player_screen.dart';

/// Detalle de una serie: una sección plegable (ExpansionTile) por temporada,
/// con la lista de episodios. Tocar un episodio lo reproduce con reanudación.
class SeriesDetailScreen extends StatelessWidget {
  final SeriesGroup series;
  const SeriesDetailScreen({super.key, required this.series});

  String _seasonLabel(int s) => s == 0 ? 'Episodios' : 'Temporada $s';

  @override
  Widget build(BuildContext context) {
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
                  trailing: const Icon(Icons.play_arrow),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          PlayerScreen(item: e.item, resume: true),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
