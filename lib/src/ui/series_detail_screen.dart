import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../domain/series_group.dart';
import 'player_screen.dart';

/// Detalle de una serie con selector de temporadas (chips) y lista de
/// capítulos de la temporada elegida, con indicadores de visto/progreso y
/// reproducción con auto‑paso al siguiente episodio.
class SeriesDetailScreen extends ConsumerStatefulWidget {
  final SeriesGroup series;
  const SeriesDetailScreen({super.key, required this.series});

  @override
  ConsumerState<SeriesDetailScreen> createState() =>
      _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends ConsumerState<SeriesDetailScreen> {
  late int _season = widget.series.sortedSeasons.first;

  SeriesGroup get series => widget.series;

  String _seasonLabel(int s) => s == 0 ? 'Episodios' : 'Temporada $s';

  void _play(List<Episode> episodes, Episode e) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlayerScreen(
        item: e.item,
        resume: true,
        queue: [for (final x in episodes) x.item],
        queueIndex: episodes.indexOf(e),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final seasons = series.sortedSeasons;
    final episodes = series.seasons[_season] ?? const <Episode>[];
    return Scaffold(
      appBar: AppBar(title: Text(series.title)),
      body: Column(
        children: [
          _header(context),
          if (seasons.length > 1)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final s in seasons)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_seasonLabel(s)),
                        selected: s == _season,
                        onSelected: (_) => setState(() => _season = s),
                      ),
                    ),
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: episodes.length,
              itemBuilder: (_, i) => _episodeTile(episodes, episodes[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _episodeTile(List<Episode> episodes, Episode e) {
    final frac = e.item.watchedFraction.toDouble();
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: frac >= 0.9 ? kAccent : null,
        child: frac >= 0.9
            ? const Icon(Icons.check, size: 18)
            : Text(e.episode > 0 ? '${e.episode}' : '•'),
      ),
      title: Text(e.item.name),
      subtitle: frac > 0 && frac < 0.9
          ? Padding(
              padding: const EdgeInsets.only(top: 6),
              child: LinearProgressIndicator(
                  value: frac, minHeight: 3, backgroundColor: Colors.white12),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
                e.item.isFavorite ? Icons.favorite : Icons.favorite_border),
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
      onTap: () => _play(episodes, e),
    );
  }

  Widget _header(BuildContext context) {
    final total = series.episodeCount;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 96,
              height: 144,
              child: series.poster == null
                  ? Container(
                      color: kSurfaceHigh,
                      child: const Icon(Icons.theaters, size: 40))
                  : CachedNetworkImage(
                      imageUrl: series.poster!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Container(
                          color: kSurfaceHigh,
                          child: const Icon(Icons.theaters, size: 40)),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(series.title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('${series.sortedSeasons.length} temporada(s) · '
                    '$total episodio(s)',
                    style: const TextStyle(color: Colors.white60)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
