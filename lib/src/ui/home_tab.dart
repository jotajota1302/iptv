import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../data/epg_service.dart';
import '../domain/content_type.dart';
import '../domain/media_item.dart';
import '../domain/series_group.dart';
import 'favorites_tab.dart';
import 'history_screen.dart';
import 'movie_detail_screen.dart';
import 'play_helpers.dart';
import 'series_detail_screen.dart';
import 'vod_poster.dart';
import 'widgets/content_rail.dart';

/// Pantalla de Inicio estilo streaming: saludo, hero destacado y carruseles
/// (Continuar viendo, Novedades, Favoritos).
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  String _greeting(int hour) {
    if (hour < 6) return 'Buenas noches';
    if (hour < 13) return 'Buenos días';
    if (hour < 21) return 'Buenas tardes';
    return 'Buenas noches';
  }

  void _goTab(WidgetRef ref, int i) =>
      ref.read(selectedTabProvider.notifier).state = i;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movies = ref.watch(recentMoviesProvider);
    final series = ref.watch(recentSeriesProvider);
    final cont = ref.watch(continueWatchingProvider);
    final favs = ref.watch(favoritesProvider);
    final nowOn = ref.watch(nowOnFavoritesProvider);
    final hour = TimeOfDay.now().hour;

    final loading = movies.isLoading && series.isLoading;
    final featured = (movies.value ?? const <MediaItem>[])
        .where((m) => m.logoUrl != null)
        .take(14)
        .toList();

    final nothing = !loading &&
        (movies.value ?? const []).isEmpty &&
        (series.value ?? const []).isEmpty &&
        (cont.value ?? const []).isEmpty &&
        (favs.value ?? const []).isEmpty;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(recentMoviesProvider);
          ref.invalidate(recentSeriesProvider);
          ref.invalidate(continueWatchingProvider);
          ref.invalidate(favoritesProvider);
          ref.invalidate(nowOnFavoritesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text('${_greeting(hour)} 👋',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800)),
            ),
            if (loading) ...[
              const SizedBox(height: 12),
              const RailSkeleton(),
              const RailSkeleton(),
            ],
            if (nothing) _EmptyHome(onAdd: () => _goTab(ref, 5)),
            if (featured.isNotEmpty) _Hero(movies: featured),
            _railNowOn(context, nowOn.value ?? const []),
            _railContinue(context, ref, cont.value ?? const []),
            _railMovies(context, ref, movies.value ?? const []),
            _railSeries(context, ref, series.value ?? const []),
            _railFavorites(context, ref, favs.value ?? const []),
          ],
        ),
      ),
    );
  }

  /// Qué están emitiendo ahora los canales favoritos.
  Widget _railNowOn(
      BuildContext c, List<({MediaItem channel, EpgEntry entry})> items) {
    return ContentRail(
      title: 'Ahora en tus canales',
      itemWidth: 270,
      height: 86,
      items: [
        for (final it in items)
          _NowCard(channel: it.channel, entry: it.entry),
      ],
    );
  }

  Widget _railContinue(BuildContext c, WidgetRef ref, List<MediaItem> items) {
    return ContentRail(
      title: 'Continuar viendo',
      onSeeAll: () => Navigator.of(c).push(
          MaterialPageRoute(builder: (_) => const HistoryScreen())),
      items: [
        for (final it in items)
          VodPoster(
            title: it.name,
            posterUrl: it.logoUrl,
            titleOverlay: true,
            watchedFraction: it.watchedFraction.toDouble(),
            fallbackIcon: it.type == ContentType.series
                ? Icons.theaters
                : Icons.movie_outlined,
            onTap: () async {
              await openPlayer(c, it);
              ref.invalidate(continueWatchingProvider);
            },
          ),
      ],
    );
  }

  Widget _railMovies(BuildContext c, WidgetRef ref, List<MediaItem> items) {
    return ContentRail(
      title: 'Novedades en Películas',
      onSeeAll: () => _goTab(ref, 2),
      items: [
        for (final it in items)
          VodPoster(
            title: it.name,
            posterUrl: it.logoUrl,
            titleOverlay: true,
            favorite: it.isFavorite,
            onTap: () => Navigator.of(c).push(MaterialPageRoute(
                builder: (_) => MovieDetailScreen(item: it))),
          ),
      ],
    );
  }

  Widget _railSeries(BuildContext c, WidgetRef ref, List<SeriesGroup> items) {
    return ContentRail(
      title: 'Novedades en Series',
      onSeeAll: () => _goTab(ref, 3),
      items: [
        for (final s in items)
          VodPoster(
            title: s.title,
            posterUrl: s.poster,
            titleOverlay: true,
            fallbackIcon: Icons.theaters,
            onTap: () => Navigator.of(c).push(MaterialPageRoute(
                builder: (_) => SeriesDetailScreen(series: s))),
          ),
      ],
    );
  }

  Widget _railFavorites(BuildContext c, WidgetRef ref, List<MediaItem> items) {
    return ContentRail(
      title: 'Tus favoritos',
      onSeeAll: () => Navigator.of(c).push(MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Favoritos')),
          body: const FavoritesTab(),
        ),
      )),
      items: [
        for (final it in items)
          VodPoster(
            title: it.name,
            posterUrl: it.logoUrl,
            titleOverlay: true,
            favorite: true,
            fallbackIcon: it.type == ContentType.series
                ? Icons.theaters
                : (it.type == ContentType.movie
                    ? Icons.movie_outlined
                    : Icons.live_tv),
            onTap: () => openPlayer(c, it),
          ),
      ],
    );
  }
}

/// Carrusel "jukebox" de novedades: fila de carátulas todas visibles con la
/// central destacada (más grande y con acento) y la ficha compacta debajo.
/// Aprovecha todo el ancho de la ventana sin dejar espacio muerto.
class _Hero extends StatefulWidget {
  final List<MediaItem> movies;
  const _Hero({required this.movies});
  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  PageController? _pc;
  double _fraction = 0;
  int _page = 0;

  /// El PageController depende del ancho (cada carátula ≈176 px lógicos);
  /// se recrea si la ventana cambia de tamaño, conservando la página.
  void _ensureController(double width) {
    final f = (176 / width).clamp(0.07, 0.45).toDouble();
    if (_pc != null && (f - _fraction).abs() < 0.005) return;
    final old = _pc;
    _fraction = f;
    _pc = PageController(viewportFraction: f, initialPage: _page);
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  @override
  void dispose() {
    _pc?.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final target = (_page + delta).clamp(0, widget.movies.length - 1);
    _pc?.animateToPage(target,
        duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final movies = widget.movies;
    return Column(
      children: [
        const SizedBox(height: 12),
        SizedBox(
          height: 236,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _ensureController(constraints.maxWidth);
              final pc = _pc!;
              return Stack(
                alignment: Alignment.center,
                children: [
                  PageView.builder(
                    controller: pc,
                    itemCount: movies.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) => AnimatedBuilder(
                      animation: pc,
                      builder: (_, _) {
                        final page = pc.position.haveDimensions
                            ? (pc.page ?? _page.toDouble())
                            : _page.toDouble();
                        final d = (page - i).abs().clamp(0.0, 3.0);
                        final scale = 1.0 - (d * 0.13).clamp(0.0, 0.34);
                        final opacity = 1.0 - (d * 0.22).clamp(0.0, 0.62);
                        return Center(
                          child: Opacity(
                            opacity: opacity,
                            child: Transform.scale(
                              scale: scale,
                              child: _JukeboxCard(
                                movie: movies[i],
                                focused: i == _page,
                                onTap: () {
                                  if (i == _page) {
                                    Navigator.of(context).push(
                                        MaterialPageRoute(
                                            builder: (_) => MovieDetailScreen(
                                                item: movies[i])));
                                  } else {
                                    pc.animateToPage(i,
                                        duration:
                                            const Duration(milliseconds: 350),
                                        curve: Curves.easeOut);
                                  }
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_page > 0)
                    Positioned(
                      left: 8,
                      child: _HeroArrow(
                          icon: Icons.chevron_left, onTap: () => _go(-1)),
                    ),
                  if (_page < movies.length - 1)
                    Positioned(
                      right: 8,
                      child: _HeroArrow(
                          icon: Icons.chevron_right, onTap: () => _go(1)),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Ficha compacta de la carátula enfocada.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _FocusedInfo(
              key: ValueKey(movies[_page].id), movie: movies[_page]),
        ),
      ],
    );
  }
}

/// Carátula 2:3 del jukebox; la enfocada lleva borde de acento y sombra.
class _JukeboxCard extends StatelessWidget {
  final MediaItem movie;
  final bool focused;
  final VoidCallback onTap;
  const _JukeboxCard(
      {required this.movie, required this.focused, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: focused ? Border.all(color: kAccent, width: 2.5) : null,
            boxShadow: focused
                ? [
                    BoxShadow(
                        color: kAccent.withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 1)
                  ]
                : const [
                    BoxShadow(color: Colors.black54, blurRadius: 8),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9.5),
            child: movie.logoUrl == null
                ? Container(
                    color: kSurfaceHigh,
                    child: const Icon(Icons.movie_outlined, size: 40))
                : CachedNetworkImage(
                    imageUrl: movie.logoUrl!,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
                        color: kSurfaceHigh,
                        child: const Icon(Icons.movie_outlined, size: 40)),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Título + metadatos + acciones de la película enfocada en el jukebox.
class _FocusedInfo extends ConsumerWidget {
  final MediaItem movie;
  const _FocusedInfo({super.key, required this.movie});

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: const TextStyle(fontSize: 11.5)),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(vodInfoProvider(movie.streamUrl)).value;
    final meta = <String>[
      if (info?.year != null) info!.year!,
      if ((info?.genre ?? '').isNotEmpty) info!.genre!,
      if ((info?.rating ?? '').isNotEmpty) '⭐ ${info!.rating}',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(movie.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [for (final m in meta) _pill(m)],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () => openPlayer(context, movie),
                icon: const Icon(Icons.play_arrow, size: 20),
                label: const Text('Ver'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => MovieDetailScreen(item: movie))),
                icon: const Icon(Icons.info_outline, size: 18),
                label: const Text('Info'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeroArrow({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

/// Tarjeta del rail "Ahora en tus canales": canal + programa en emisión con
/// su avance. Al tocarla se abre el canal a pantalla completa.
class _NowCard extends StatelessWidget {
  final MediaItem channel;
  final EpgEntry entry;
  const _NowCard({required this.channel, required this.entry});

  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final progress = (now.difference(entry.start).inSeconds /
            entry.end.difference(entry.start).inSeconds.clamp(1, 1 << 31))
        .clamp(0.0, 1.0);
    return Card(
      child: InkWell(
        onTap: () => openPlayer(context, channel),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: channel.logoUrl == null
                    ? const Icon(Icons.live_tv,
                        size: 22, color: Colors.black38)
                    : CachedNetworkImage(
                        imageUrl: channel.logoUrl!,
                        fit: BoxFit.contain,
                        errorWidget: (_, _, _) => const Icon(Icons.live_tv,
                            size: 22, color: Colors.black38),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 3,
                                backgroundColor: Colors.white12),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(_hhmm(entry.end),
                            style: const TextStyle(
                                fontSize: 10, color: Colors.white38)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHome extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyHome({required this.onAdd});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      child: Column(
        children: [
          const Icon(Icons.live_tv, size: 72, color: Colors.white24),
          const SizedBox(height: 16),
          const Text('Aún no hay contenido',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Añade una lista M3U para empezar a ver.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Añadir lista'),
          ),
        ],
      ),
    );
  }
}
