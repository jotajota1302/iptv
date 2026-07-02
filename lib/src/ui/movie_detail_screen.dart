import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../data/tmdb_service.dart';
import '../data/vod_info_service.dart';
import '../domain/media_item.dart';
import '../domain/trailer_url.dart';
import 'play_helpers.dart';
import 'vod_poster.dart';
import 'widgets/cast_rail.dart';
import 'widgets/content_rail.dart';

/// Ficha de película estilo cine: backdrop a pantalla con degradado, póster
/// superpuesto, metadatos y sinopsis. Datos de la API Xtream (best-effort).
class MovieDetailScreen extends ConsumerWidget {
  final MediaItem item;
  const MovieDetailScreen({super.key, required this.item});

  String _fmt(int s) {
    final h = s ~/ 3600, m = (s % 3600) ~/ 60;
    return h > 0 ? '${h}h ${m}min' : '${m}min';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infoAsync = ref.watch(vodInfoProvider(item.streamUrl));
    final info = infoAsync.value;
    final pos = item.positionSeconds;
    final resumeLabel = pos > 5 ? 'Continuar · ${_fmt(pos)}' : 'Reproducir';
    final cat = item.groupTitle ?? 'Sin categoria';
    // Reparto con fotos (TMDB): se pide cuando la ficha Xtream ya respondió,
    // para aprovechar su tmdb_id/año y no buscar dos veces.
    final tmdbCast = infoAsync.isLoading
        ? const <TmdbCastMember>[]
        : ref
                .watch(castProvider((
              isSeries: false,
              title: item.name,
              year: info?.year ?? yearFromName(item.name),
              tmdbId: info?.tmdbId,
            )))
                .value ??
            const <TmdbCastMember>[];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            stretch: true,
            backgroundColor: kBackground,
            flexibleSpace: FlexibleSpaceBar(
              // Backdrop de fondo con el póster grande centrado encima,
              // estilo cartelera (el pequeño a la izquierda quedaba perdido).
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _Backdrop(item: item, info: info),
                  Align(
                    alignment: const Alignment(0, 0.65),
                    child: Hero(
                      tag: 'movie-${item.id}',
                      child: Container(
                        width: 200,
                        height: 300,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.75),
                                blurRadius: 26,
                                offset: const Offset(0, 14)),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            color: kSurfaceHigh,
                            child: item.logoUrl == null
                                ? const Icon(Icons.movie_outlined, size: 48)
                                : CachedNetworkImage(
                                    imageUrl: item.logoUrl!,
                                    fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              stretchModes: const [StretchMode.zoomBackground],
            ),
          ),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(item.name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              height: 1.2)),
                      const SizedBox(height: 12),
                      if (info != null) Center(child: _chips(context, info)),
                      const SizedBox(height: 16),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: _actions(context, ref, resumeLabel, cat, info),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (infoAsync.isLoading) const _LoadingLine(),
                      if (info != null && (info.plot ?? '').isNotEmpty) ...[
                        const Text('Sinopsis',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 6),
                        Text(info.plot!,
                            style: const TextStyle(
                                height: 1.5, color: Colors.white70)),
                        const SizedBox(height: 16),
                      ],
                      // El texto plano del proveedor solo si TMDB no da caras.
                      if (info?.cast != null && tmdbCast.isEmpty)
                        _line('Reparto', info!.cast!),
                      if (info?.director != null)
                        _line('Dirección', info!.director!),
                      if (info == null && !infoAsync.isLoading)
                        const Text('Sin ficha disponible para este contenido',
                            style: TextStyle(color: Colors.white38)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (tmdbCast.isNotEmpty)
            SliverToBoxAdapter(child: CastRail(cast: tmdbCast)),
          SliverToBoxAdapter(child: _related(context, ref, cat)),
        ],
      ),
    );
  }

  Widget _related(BuildContext context, WidgetRef ref, String cat) {
    final others = (ref.watch(moviesByCategoryProvider(cat)).value ??
            const <MediaItem>[])
        .where((m) => m.id != item.id)
        .take(15)
        .toList();
    if (others.isEmpty) return const SizedBox(height: 8);
    return ContentRail(
      title: 'Más en $cat',
      items: [
        for (final m in others)
          VodPoster(
            title: m.name,
            posterUrl: m.logoUrl,
            titleOverlay: true,
            favorite: m.isFavorite,
            onTap: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => MovieDetailScreen(item: m)),
            ),
          ),
      ],
    );
  }

  Widget _chips(BuildContext context, VodInfo info) {
    final chips = <String>[
      if (info.year != null) info.year!,
      if (info.genre != null) info.genre!,
      if (info.durationText != null) info.durationText!,
      if (info.rating != null) '⭐ ${info.rating}',
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.center,
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

  Widget _actions(BuildContext context, WidgetRef ref, String resumeLabel,
      String cat, VodInfo? info) {
    final trailer = trailerUrl(info?.youtubeTrailer);
    final watched = item.watchedFraction >= 0.9;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () async {
              await openPlayer(context, item);
              ref.invalidate(continueWatchingProvider);
              ref.invalidate(moviesByCategoryProvider(cat));
            },
            icon: const Icon(Icons.play_arrow),
            label: Text(resumeLabel),
          ),
        ),
        if (trailer != null) ...[
          const SizedBox(width: 10),
          IconButton.filledTonal(
            iconSize: 22,
            tooltip: 'Ver tráiler',
            onPressed: () => launchUrl(Uri.parse(trailer),
                mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.ondemand_video),
          ),
        ],
        const SizedBox(width: 10),
        IconButton.filledTonal(
          iconSize: 22,
          tooltip: watched ? 'Marcar como no visto' : 'Marcar como visto',
          onPressed: () async {
            await ref
                .read(playlistRepositoryProvider)
                .setWatched(item, !watched);
            ref.invalidate(continueWatchingProvider);
            ref.invalidate(historyProvider);
            ref.invalidate(moviesByCategoryProvider(cat));
          },
          icon: Icon(watched ? Icons.check_circle : Icons.check_circle_outline),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          iconSize: 22,
          onPressed: () async {
            await ref.read(playlistRepositoryProvider).toggleFavorite(item);
            ref.invalidate(favoritesProvider);
            ref.invalidate(moviesByCategoryProvider(cat));
          },
          icon: Icon(
              item.isFavorite ? Icons.favorite : Icons.favorite_border),
        ),
      ],
    );
  }

  Widget _line(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: RichText(
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
        ),
      );
}

class _Backdrop extends StatelessWidget {
  final MediaItem item;
  final VodInfo? info;
  const _Backdrop({required this.item, required this.info});

  /// Póster desenfocado como fondo: siempre pega con la película.
  Widget _blurredPoster(String poster) => ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover),
      );

  @override
  Widget build(BuildContext context) {
    final wide = info?.backdrop;
    final poster = info?.cover ?? item.logoUrl;
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
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [const Color(0x22000000), kBackground],
              stops: const [0.35, 1.0],
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
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Row(children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 8),
          Text('Cargando ficha...', style: TextStyle(color: Colors.white54)),
        ]),
      );
}
