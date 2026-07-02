import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../data/series_grouper.dart';
import '../data/series_info_service.dart';
import '../domain/series_group.dart';
import '../domain/trailer_url.dart';
import 'player_screen.dart';

/// Detalle de una serie estilo cine: backdrop con degradado, ficha (sinopsis,
/// rating, género) y episodios con miniatura, título limpio y duración. Los
/// metadatos vienen de la API Xtream (best-effort: sin red, la pantalla sigue
/// funcionando con los datos del M3U).
class SeriesDetailScreen extends ConsumerStatefulWidget {
  final SeriesGroup series;
  const SeriesDetailScreen({super.key, required this.series});

  @override
  ConsumerState<SeriesDetailScreen> createState() =>
      _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends ConsumerState<SeriesDetailScreen> {
  late int _season = widget.series.sortedSeasons.first;
  bool _plotExpanded = false;

  SeriesGroup get series => widget.series;

  String _seasonLabel(int s) => s == 0 ? 'Episodios' : 'Temporada $s';

  /// URL de cualquier episodio: de ella se derivan las credenciales de la API.
  String get _anyEpisodeUrl =>
      series.seasons[series.sortedSeasons.first]!.first.item.streamUrl;

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
    final infoAsync = ref.watch(
        seriesInfoProvider((streamUrl: _anyEpisodeUrl, title: series.title)));
    final info = infoAsync.value;
    final seasons = series.sortedSeasons;
    final episodes = series.seasons[_season] ?? const <Episode>[];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            stretch: true,
            backgroundColor: kBackground,
            flexibleSpace: FlexibleSpaceBar(
              background: _Backdrop(series: series, info: info),
              stretchModes: const [StretchMode.zoomBackground],
            ),
          ),
          // Sin Transform.translate: desplaza el dibujo pero no la zona de
          // toque de los slivers, y dejaba chips/botones sin responder.
          SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _posterAndTitle(info),
                    const SizedBox(height: 14),
                    _chips(info),
                    if (trailerUrl(info?.youtubeTrailer) != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.ondemand_video, size: 18),
                          label: const Text('Ver tráiler'),
                          onPressed: () => launchUrl(
                              Uri.parse(trailerUrl(info!.youtubeTrailer)!),
                              mode: LaunchMode.externalApplication),
                        ),
                      ),
                    ],
                    if (infoAsync.isLoading) ...[
                      const SizedBox(height: 14),
                      const _LoadingLine(),
                    ],
                    if ((info?.plot ?? '').isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _plot(info!.plot!),
                    ],
                    if ((info?.cast ?? '').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _line('Reparto', info!.cast!),
                    ],
                    const SizedBox(height: 6),
                  ],
                ),
            ),
          ),
          if (seasons.length > 1)
            SliverToBoxAdapter(
              child: SizedBox(
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
            ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 24),
            sliver: SliverList.builder(
              itemCount: episodes.length,
              itemBuilder: (_, i) =>
                  _episodeTile(episodes, episodes[i], info),
            ),
          ),
        ],
      ),
    );
  }

  Widget _posterAndTitle(SeriesApiInfo? info) {
    final poster = info?.cover ?? series.poster;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 100,
            height: 150,
            color: kSurfaceHigh,
            child: poster == null
                ? const Icon(Icons.theaters, size: 40)
                : CachedNetworkImage(
                    imageUrl: poster,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) =>
                        const Icon(Icons.theaters, size: 40),
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(series.title,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, height: 1.2)),
          ),
        ),
      ],
    );
  }

  Widget _chips(SeriesApiInfo? info) {
    final chips = <String>[
      if (info?.year != null) info!.year!,
      if ((info?.genre ?? '').isNotEmpty) info!.genre!,
      if ((info?.rating ?? '').isNotEmpty) '⭐ ${info!.rating}',
      '${series.sortedSeasons.length} temporada(s) · '
          '${series.episodeCount} episodio(s)',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final t in chips)
          Chip(
            label: Text(t, style: const TextStyle(fontSize: 12)),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
      ],
    );
  }

  /// Sinopsis plegada a 4 líneas; al tocarla se expande/contrae.
  Widget _plot(String plot) {
    return GestureDetector(
      onTap: () => setState(() => _plotExpanded = !_plotExpanded),
      child: Text(
        plot,
        maxLines: _plotExpanded ? null : 4,
        overflow: _plotExpanded ? null : TextOverflow.ellipsis,
        style: const TextStyle(height: 1.5, color: Colors.white70),
      ),
    );
  }

  Widget _line(String label, String value) => RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white70, height: 1.4),
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: Colors.white)),
            TextSpan(text: value),
          ],
        ),
      );

  Widget _episodeTile(
      List<Episode> episodes, Episode e, SeriesApiInfo? info) {
    final apiEp = info?.episodesById[episodeIdFromUrl(e.item.streamUrl)];
    final frac = e.item.watchedFraction.toDouble();
    final watched = frac >= 0.9;

    var title = cleanEpisodeName(apiEp?.title ?? e.item.name, series.title);
    if (title.isEmpty) {
      title = e.episode > 0 ? 'Episodio ${e.episode}' : e.item.name;
    }
    if (e.episode > 0) title = '${e.episode}. $title';

    final subtitle = [
      ?formatEpisodeDuration(apiEp?.durationText),
      if ((apiEp?.plot ?? '').isNotEmpty) apiEp!.plot!,
    ].join(' · ');

    return InkWell(
      onTap: () => _play(episodes, e),
      onLongPress: () => _episodeSheet(e, watched),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _thumb(apiEp?.image, frac, watched),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 2),
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: watched ? Colors.white54 : Colors.white)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, color: Colors.white54)),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                  e.item.isFavorite ? Icons.favorite : Icons.favorite_border,
                  size: 20),
              tooltip: 'Favorito',
              onPressed: () async {
                await ref
                    .read(playlistRepositoryProvider)
                    .toggleFavorite(e.item);
                ref.invalidate(favoritesProvider);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Acciones del episodio (pulsación larga): marcar visto / no visto.
  void _episodeSheet(Episode e, bool watched) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(watched
                  ? Icons.remove_done
                  : Icons.check_circle_outline),
              title: Text(watched
                  ? 'Marcar como no visto'
                  : 'Marcar como visto'),
              onTap: () async {
                Navigator.pop(sheet);
                await ref
                    .read(playlistRepositoryProvider)
                    .setWatched(e.item, !watched);
                ref.invalidate(continueWatchingProvider);
                ref.invalidate(historyProvider);
                if (e.item.groupTitle != null) {
                  ref.invalidate(seriesGroupsByCategoryProvider(
                      e.item.groupTitle!));
                }
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Miniatura 16:9 del episodio con progreso y marca de visto. Si la API no
  /// da imagen se usa el póster de la serie; sin nada, un icono.
  Widget _thumb(String? image, double frac, bool watched) {
    final url = image ?? series.poster;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 118,
        height: 66,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url == null)
              Container(
                  color: kSurfaceHigh,
                  child: const Icon(Icons.theaters,
                      size: 24, color: Colors.white38))
            else
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => Container(
                    color: kSurfaceHigh,
                    child: const Icon(Icons.theaters,
                        size: 24, color: Colors.white38)),
              ),
            if (watched) ...[
              Container(color: Colors.black45),
              Center(
                  child: Icon(Icons.check_circle, color: kAccent, size: 26)),
            ] else if (frac > 0)
              Align(
                alignment: Alignment.bottomCenter,
                child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 3,
                    backgroundColor: Colors.white24),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fondo de cabecera: backdrop de la API o, en su defecto, el póster
/// desenfocado, siempre con degradado hacia el fondo de la app.
class _Backdrop extends StatelessWidget {
  final SeriesGroup series;
  final SeriesApiInfo? info;
  const _Backdrop({required this.series, required this.info});

  Widget _blurredPoster(String poster) => ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover),
      );

  @override
  Widget build(BuildContext context) {
    final wide = info?.backdrop;
    final poster = info?.cover ?? series.poster;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (wide != null)
          CachedNetworkImage(
            imageUrl: wide,
            fit: BoxFit.cover,
            // Si el backdrop del proveedor falla, cae al póster difuminado.
            errorWidget: (_, _, _) => poster != null
                ? _blurredPoster(poster)
                : Container(color: kSurfaceHigh),
          )
        else if (poster != null)
          _blurredPoster(poster)
        else
          Container(color: kSurfaceHigh),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x22000000), kBackground],
              stops: [0.35, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

class _LoadingLine extends StatelessWidget {
  const _LoadingLine();
  @override
  Widget build(BuildContext context) => const Row(children: [
        SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2)),
        SizedBox(width: 8),
        Text('Cargando ficha...', style: TextStyle(color: Colors.white54)),
      ]);
}
