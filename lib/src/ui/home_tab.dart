import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  void _goTab(WidgetRef ref, int i) =>
      ref.read(selectedTabProvider.notifier).state = i;

  /// Mezcla los últimos estrenos de películas y series intercalados para el
  /// carrusel jukebox (solo entradas con carátula).
  List<_Featured> _featured(List<MediaItem> ms, List<SeriesGroup> ss) {
    final movies = [
      for (final m in ms)
        if (m.logoUrl != null)
          _Featured(title: m.name, poster: m.logoUrl, item: m)
    ];
    final series = [
      for (final s in ss)
        if (s.poster != null && s.episodeCount > 0)
          _Featured(
              title: s.title,
              poster: s.poster,
              item: s.seasons[s.sortedSeasons.first]!.first.item,
              series: s)
    ];
    final out = <_Featured>[];
    var mi = 0, si = 0;
    while (out.length < 15 && (mi < movies.length || si < series.length)) {
      if (mi < movies.length) out.add(movies[mi++]);
      if (si < series.length && out.length < 15) out.add(series[si++]);
    }
    return out;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movies = ref.watch(recentMoviesProvider);
    final series = ref.watch(recentSeriesProvider);
    final cont = ref.watch(continueWatchingProvider);
    final favs = ref.watch(favoritesProvider);
    final nowOn = ref.watch(nowOnFavoritesProvider);

    final loading = movies.isLoading && series.isLoading;
    final featured = _featured(
        movies.value ?? const [], series.value ?? const []);

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
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text('Últimos estrenos',
                  style:
                      TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ),
            if (loading) ...[
              const SizedBox(height: 12),
              const RailSkeleton(),
              const RailSkeleton(),
            ],
            if (nothing) _EmptyHome(onAdd: () => _goTab(ref, 5)),
            if (featured.isNotEmpty) _Hero(items: featured),
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

/// Un estreno del jukebox: película o serie (con su grupo para abrirla).
class _Featured {
  final String title;
  final String? poster;
  final MediaItem item; // la película, o un episodio de la serie
  final SeriesGroup? series; // != null si es serie
  const _Featured(
      {required this.title, required this.poster, required this.item, this.series});

  bool get isSeries => series != null;
}

/// Carrusel "jukebox" de últimos estrenos (películas y series): fila de
/// carátulas todas visibles con la central destacada (más grande y con
/// acento) y la ficha compacta debajo. Aprovecha todo el ancho.
class _Hero extends StatefulWidget {
  final List<_Featured> items;
  const _Hero({required this.items});
  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  PageController? _pc;
  double _fraction = 0;

  /// Carrusel infinito: el PageView tiene muchas páginas y cada una mapea a
  /// items[i % n], así al pasar el último se vuelve al primero sin corte.
  /// Arranca lejos del borde para poder navegar a ambos lados.
  late int _page = widget.items.length * 500 + widget.items.length ~/ 2;

  int get _n => widget.items.length;

  _Featured get _current => widget.items[_page % _n];

  void _openDetail(_Featured f) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => f.isSeries
            ? SeriesDetailScreen(series: f.series!)
            : MovieDetailScreen(item: f.item)));
  }

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
    _pc?.animateToPage(_page + delta,
        duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
  }

  /// Flechas ←/→ del teclado mueven el carrusel (escritorio/TV).
  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _go(-1);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      _go(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
      children: [
        const SizedBox(height: 12),
        SizedBox(
          height: 254,
          child: LayoutBuilder(
            builder: (context, constraints) {
              _ensureController(constraints.maxWidth);
              final pc = _pc!;
              return Stack(
                alignment: Alignment.center,
                children: [
                  PageView.builder(
                    controller: pc,
                    // "Infinito": muchas páginas mapeadas con módulo.
                    itemCount: items.length * 1000,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) => AnimatedBuilder(
                      animation: pc,
                      builder: (_, _) {
                        final f = items[i % items.length];
                        final page = pc.position.haveDimensions
                            ? (pc.page ?? _page.toDouble())
                            : _page.toDouble();
                        // Coverflow: las laterales se inclinan hacia el
                        // centro, bajan en arco, encogen y se oscurecen de
                        // forma continua según su distancia al foco.
                        final signed = (page - i).toDouble();
                        final d = signed.abs().clamp(0.0, 4.0);
                        final scale = (1.0 - d * 0.12).clamp(0.60, 1.0);
                        final dy = (d * 15).clamp(0.0, 50.0);
                        final angle = signed.clamp(-2.2, 2.2) * -0.24;
                        final dim = (d * 0.22).clamp(0.0, 0.55);
                        final focus = (1.0 - d * 1.6).clamp(0.0, 1.0);
                        final m = Matrix4.identity()
                          ..setEntry(3, 2, 0.0016)
                          ..rotateY(angle)
                          ..scaleByDouble(scale, scale, scale, 1);
                        return Center(
                          child: Transform.translate(
                            offset: Offset(0, dy),
                            child: Transform(
                              transform: m,
                              alignment: Alignment.center,
                              child: _JukeboxCard(
                                poster: f.poster,
                                fallbackIcon: f.isSeries
                                    ? Icons.theaters
                                    : Icons.movie_outlined,
                                focus: focus,
                                dim: dim,
                                onTap: () {
                                  if (i == _page) {
                                    _openDetail(f);
                                  } else {
                                    pc.animateToPage(i,
                                        duration:
                                            const Duration(milliseconds: 420),
                                        curve: Curves.easeOutCubic);
                                  }
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    left: 8,
                    child: _HeroArrow(
                        icon: Icons.chevron_left, onTap: () => _go(-1)),
                  ),
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
              key: ValueKey('${_page % _n}-${_current.item.id}'),
              featured: _current),
        ),
      ],
      ),
    );
  }
}

/// Carátula 2:3 del jukebox, estilo cartel de cine: sombra profunda
/// proyectada hacia abajo (volumen), halo/borde de acento que se funde de
/// forma continua con [focus] (0..1) y atenuado de las laterales con [dim].
class _JukeboxCard extends StatelessWidget {
  final String? poster;
  final IconData fallbackIcon;
  final double focus;
  final double dim;
  final VoidCallback onTap;
  const _JukeboxCard({
    required this.poster,
    required this.fallbackIcon,
    required this.focus,
    required this.dim,
    required this.onTap,
  });

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
            border: focus > 0.05
                ? Border.all(
                    color: kAccent.withValues(alpha: focus),
                    width: 2.5 * focus)
                : null,
            boxShadow: [
              if (focus > 0.05)
                BoxShadow(
                    color: kAccent.withValues(alpha: 0.35 * focus),
                    blurRadius: 22,
                    spreadRadius: 1),
              // Sombra de cartel: caída hacia abajo con cuerpo.
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.65),
                  blurRadius: 18,
                  offset: const Offset(0, 12)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9.5),
            child: Stack(
              fit: StackFit.expand,
              children: [
                poster == null
                    ? Container(
                        color: kSurfaceHigh,
                        child: Icon(fallbackIcon, size: 40))
                    : CachedNetworkImage(
                        imageUrl: poster!,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) => Container(
                            color: kSurfaceHigh,
                            child: Icon(fallbackIcon, size: 40)),
                      ),
                if (dim > 0.01)
                  Container(color: Colors.black.withValues(alpha: dim)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Título + metadatos + acciones del estreno enfocado en el jukebox
/// (película o serie).
class _FocusedInfo extends ConsumerWidget {
  final _Featured featured;
  const _FocusedInfo({super.key, required this.featured});

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
    final f = featured;
    String? year, genre, rating;
    if (f.isSeries) {
      final info = ref
          .watch(seriesInfoProvider(
              (streamUrl: f.item.streamUrl, title: f.series!.title)))
          .value;
      year = info?.year;
      genre = info?.genre;
      rating = info?.rating;
    } else {
      final info = ref.watch(vodInfoProvider(f.item.streamUrl)).value;
      year = info?.year;
      genre = info?.genre;
      rating = info?.rating;
    }
    final meta = <String>[
      if (f.isSeries) 'Serie · ${f.series!.sortedSeasons.length} temporada(s)',
      ?year,
      if ((genre ?? '').isNotEmpty) genre!,
      if ((rating ?? '').isNotEmpty) '⭐ $rating',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(f.title,
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
              if (f.isSeries)
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) =>
                              SeriesDetailScreen(series: f.series!))),
                  icon: const Icon(Icons.theaters, size: 18),
                  label: const Text('Ver serie'),
                )
              else ...[
                FilledButton.icon(
                  onPressed: () => openPlayer(context, f.item),
                  icon: const Icon(Icons.play_arrow, size: 20),
                  label: const Text('Ver'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => MovieDetailScreen(item: f.item))),
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('Info'),
                ),
              ],
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
