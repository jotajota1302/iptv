import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../data/vod_info_service.dart';
import '../domain/media_item.dart';
import 'play_helpers.dart';
import 'vod_poster.dart';
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

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            stretch: true,
            backgroundColor: kBackground,
            flexibleSpace: FlexibleSpaceBar(
              background: _Backdrop(item: item, info: info),
              stretchModes: const [StretchMode.zoomBackground],
            ),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -48),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _posterAndTitle(context, info),
                    const SizedBox(height: 16),
                    if (info != null) _chips(context, info),
                    const SizedBox(height: 16),
                    _actions(context, ref, resumeLabel, cat),
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
                    if (info?.cast != null) _line('Reparto', info!.cast!),
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
    return Transform.translate(
      offset: const Offset(0, -40),
      child: ContentRail(
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
      ),
    );
  }

  Widget _posterAndTitle(BuildContext context, VodInfo? info) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Hero(
          tag: 'movie-${item.id}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 110,
              height: 165,
              color: kSurfaceHigh,
              child: item.logoUrl == null
                  ? const Icon(Icons.movie_outlined, size: 40)
                  : CachedNetworkImage(
                      imageUrl: item.logoUrl!, fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(item.name,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800, height: 1.2)),
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

  Widget _actions(
      BuildContext context, WidgetRef ref, String resumeLabel, String cat) {
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

  @override
  Widget build(BuildContext context) {
    final wide = info?.backdrop;
    final poster = info?.cover ?? item.logoUrl;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (wide != null)
          CachedNetworkImage(imageUrl: wide, fit: BoxFit.cover)
        else if (poster != null)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover),
          )
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
