import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../data/vod_info_service.dart';
import '../domain/content_type.dart';
import '../domain/media_item.dart';
import '../domain/series_group.dart';
import 'favorites_tab.dart';
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
    final hour = TimeOfDay.now().hour;

    final loading = movies.isLoading && series.isLoading;
    final featured = (movies.value ?? const <MediaItem>[])
        .where((m) => m.logoUrl != null)
        .take(6)
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
            _railContinue(context, ref, cont.value ?? const []),
            _railMovies(context, ref, movies.value ?? const []),
            _railSeries(context, ref, series.value ?? const []),
            _railFavorites(context, ref, favs.value ?? const []),
          ],
        ),
      ),
    );
  }

  Widget _railContinue(BuildContext c, WidgetRef ref, List<MediaItem> items) {
    return ContentRail(
      title: 'Continuar viendo',
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

/// Carrusel "hero" destacado en la parte superior.
class _Hero extends StatefulWidget {
  final List<MediaItem> movies;
  const _Hero({required this.movies});
  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  final _pc = PageController(viewportFraction: 0.92);
  int _page = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final target = (_page + delta).clamp(0, widget.movies.length - 1);
    _pc.animateToPage(target,
        duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final movies = widget.movies;
    return Column(
      children: [
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PageView.builder(
                controller: _pc,
                itemCount: movies.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _HeroCard(movie: movies[i]),
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
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < movies.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? kAccent : Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
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

class _HeroCard extends ConsumerWidget {
  final MediaItem movie;
  const _HeroCard({required this.movie});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(vodInfoProvider(movie.streamUrl)).value;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo: backdrop de la ficha si existe, o el póster desenfocado.
          if (info?.backdrop != null)
            CachedNetworkImage(imageUrl: info!.backdrop!, fit: BoxFit.cover)
          else if (movie.logoUrl != null)
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: CachedNetworkImage(
                  imageUrl: movie.logoUrl!, fit: BoxFit.cover),
            )
          else
            Container(color: kSurfaceHigh),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0x66000000), Color(0xF5000000)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 110,
                    height: 165,
                    child: movie.logoUrl == null
                        ? Container(
                            color: kSurfaceHigh,
                            child: const Icon(Icons.movie_outlined, size: 40))
                        : CachedNetworkImage(
                            imageUrl: movie.logoUrl!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: _details(context, info)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _details(BuildContext context, VodInfo? info) {
    final meta = <String>[
      if (info?.year != null) info!.year!,
      if (info?.genre != null) info!.genre!,
      if (info?.rating != null) '⭐ ${info!.rating}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('DESTACADA',
            style: TextStyle(
                color: kAccent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2)),
        const SizedBox(height: 4),
        Text(movie.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [for (final m in meta) _pill(m)],
          ),
        ],
        const SizedBox(height: 8),
        Expanded(
          child: (info?.plot ?? '').isEmpty
              ? const SizedBox.shrink()
              : Text(info!.plot!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12.5, height: 1.35, color: Colors.white70)),
        ),
        if (info?.cast != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('Reparto: ${info!.cast!}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.white54)),
          ),
        Row(
          children: [
            FilledButton.icon(
              onPressed: () => openPlayer(context, movie),
              icon: const Icon(Icons.play_arrow, size: 20),
              label: const Text('Ver'),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => MovieDetailScreen(item: movie)),
              ),
              icon: const Icon(Icons.info_outline),
            ),
          ],
        ),
      ],
    );
  }

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: const TextStyle(fontSize: 11)),
      );
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
