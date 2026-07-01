import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../data/vod_info_service.dart';
import '../domain/media_item.dart';
import 'play_helpers.dart';

/// Ficha de una película: carátula/fondo, sinopsis, año, género, valoración,
/// reparto y botón de reproducir/continuar. Los metadatos se cargan de la API
/// Xtream (best-effort); si no hay, se muestra igualmente lo básico.
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
    final resumeLabel = pos > 5 ? 'Continuar (${_fmt(pos)})' : 'Reproducir';

    Future<void> refreshAndPop() async {
      ref.invalidate(favoritesProvider);
      ref.invalidate(moviesByCategoryProvider(item.groupTitle ?? 'Sin categoria'));
    }

    return Scaffold(
      appBar: AppBar(title: Text(item.name)),
      body: ListView(
        children: [
          _Header(item: item, info: info),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (info != null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (info.year != null) _chip(context, info.year!),
                      if (info.genre != null) _chip(context, info.genre!),
                      if (info.durationText != null)
                        _chip(context, info.durationText!),
                      if (info.rating != null)
                        _chip(context, '⭐ ${info.rating}'),
                    ],
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        await openPlayer(context, item);
                        ref.invalidate(continueWatchingProvider);
                        ref.invalidate(moviesByCategoryProvider(
                            item.groupTitle ?? 'Sin categoria'));
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: Text(resumeLabel),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(item.isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border),
                      tooltip: 'Favorito',
                      onPressed: () async {
                        await ref
                            .read(playlistRepositoryProvider)
                            .toggleFavorite(item);
                        await refreshAndPop();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (infoAsync.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 8),
                      Text('Cargando ficha...'),
                    ]),
                  ),
                if (info != null && (info.plot ?? '').isNotEmpty) ...[
                  Text(info.plot!, style: const TextStyle(height: 1.4)),
                  const SizedBox(height: 16),
                ],
                if (info?.cast != null)
                  _line(context, 'Reparto', info!.cast!),
                if (info?.director != null)
                  _line(context, 'Dirección', info!.director!),
                if (info == null && !infoAsync.isLoading)
                  const Text('Sin ficha disponible para este contenido',
                      style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String text) => Chip(
        label: Text(text),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      );

  Widget _line(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: RichText(
          text: TextSpan(
            style: DefaultTextStyle.of(context).style,
            children: [
              TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              TextSpan(text: value),
            ],
          ),
        ),
      );
}

class _Header extends StatelessWidget {
  final MediaItem item;
  final VodInfo? info;
  const _Header({required this.item, required this.info});

  @override
  Widget build(BuildContext context) {
    final img = info?.backdrop ?? info?.cover ?? item.logoUrl;
    if (img == null) {
      return Container(
        height: 180,
        color: Colors.grey.shade900,
        child: const Center(child: Icon(Icons.movie, size: 60)),
      );
    }
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: CachedNetworkImage(
        imageUrl: img,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => Container(
          color: Colors.grey.shade900,
          child: const Center(child: Icon(Icons.movie, size: 60)),
        ),
      ),
    );
  }
}
