import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/category.dart';
import '../domain/series_group.dart';
import 'series_detail_screen.dart';

/// Cuadrícula de series (carátula + título) de una categoría. Tocar abre el
/// detalle con temporadas y episodios.
class SeriesGridScreen extends ConsumerWidget {
  final Category category;
  const SeriesGridScreen({super.key, required this.category});

  void _open(BuildContext context, SeriesGroup series) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SeriesDetailScreen(series: series)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(seriesGroupsByCategoryProvider(category.name));
    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (series) => GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 140,
            childAspectRatio: 0.62,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: series.length,
          itemBuilder: (_, i) => _SeriesPoster(
            series: series[i],
            onTap: () => _open(context, series[i]),
          ),
        ),
      ),
    );
  }
}

class _SeriesPoster extends StatelessWidget {
  final SeriesGroup series;
  final VoidCallback onTap;
  const _SeriesPoster({required this.series, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: Colors.grey.shade800,
      child: const Center(child: Icon(Icons.theaters, size: 40)),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: series.poster == null
                  ? fallback
                  : CachedNetworkImage(
                      imageUrl: series.poster!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => fallback,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                series.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
