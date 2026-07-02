import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../data/tmdb_service.dart';
import '../domain/content_type.dart';
import '../domain/media_item.dart';
import 'movie_detail_screen.dart';
import 'play_helpers.dart';
import 'vod_poster.dart';
import 'widgets/content_rail.dart';

/// Ficha de un actor: foto, bio y filmografía cruzada con el catálogo del
/// usuario ("lo tienes en tu lista" → play directo). Datos de TMDB.
class ActorScreen extends ConsumerWidget {
  final int personId;
  final String name;
  const ActorScreen({super.key, required this.personId, required this.name});

  String _fmtDate(String iso) {
    final p = iso.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
  }

  void _openCredit(BuildContext context, WidgetRef ref, MediaItem item) {
    if (item.type == ContentType.movie) {
      Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => MovieDetailScreen(item: item)));
    } else {
      openSeriesDetail(context, ref, item);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(tmdbPersonProvider(personId)).value;
    final creditsAsync = ref.watch(personCreditsProvider(personId));
    final credits = creditsAsync.value ?? const [];
    final inCatalog = credits.where((c) => c.inCatalog != null).toList();

    return Scaffold(
      appBar: AppBar(title: Text(person?.name ?? name)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 140,
                    height: 210,
                    color: kSurfaceHigh,
                    child: person?.profileUrl == null
                        ? const Icon(Icons.person, size: 56)
                        : CachedNetworkImage(
                            imageUrl: person!.profileUrl!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(person?.name ?? name,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      if (person?.birthday != null)
                        Text(
                          '${_fmtDate(person!.birthday!)}'
                          '${person.deathday != null ? ' — ${_fmtDate(person.deathday!)}' : ''}'
                          '${person.placeOfBirth != null ? ' · ${person.placeOfBirth}' : ''}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      const SizedBox(height: 8),
                      if (inCatalog.isNotEmpty)
                        Text(
                            '${inCatalog.length} títulos suyos en tu lista',
                            style: TextStyle(
                                color: kAccent, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if ((person?.biography ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(person!.biography!,
                  style: const TextStyle(height: 1.5, color: Colors.white70)),
            ),
          if (creditsAsync.isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (inCatalog.isNotEmpty)
            ContentRail(
              title: 'En tu lista',
              items: [
                for (final c in inCatalog)
                  VodPoster(
                    title: c.credit.title,
                    posterUrl: c.credit.posterUrl ?? c.inCatalog!.logoUrl,
                    titleOverlay: true,
                    onTap: () => _openCredit(context, ref, c.inCatalog!),
                  ),
              ],
            ),
          if (credits.any((c) => c.inCatalog == null))
            ContentRail(
              title: 'Filmografía',
              items: [
                for (final c in credits.where((c) => c.inCatalog == null))
                  _FilmographyCard(credit: c.credit),
              ],
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Text(
              'Datos e imágenes de TMDB. Este producto usa la API de TMDB '
              'sin estar avalado ni certificado por TMDB.',
              style: TextStyle(fontSize: 11, color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }
}

/// Título de la filmografía que no está en el catálogo: solo informativo.
class _FilmographyCard extends StatelessWidget {
  final TmdbCredit credit;
  const _FilmographyCard({required this.credit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              color: kSurfaceHigh,
              child: credit.posterUrl == null
                  ? Icon(
                      credit.mediaType == 'tv'
                          ? Icons.theaters_outlined
                          : Icons.movie_outlined,
                      size: 32,
                      color: Colors.white24)
                  : Opacity(
                      opacity: 0.55,
                      child: CachedNetworkImage(
                          imageUrl: credit.posterUrl!, fit: BoxFit.cover),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          credit.year == null ? credit.title : '${credit.title} (${credit.year})',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, color: Colors.white54),
        ),
      ],
    );
  }
}
