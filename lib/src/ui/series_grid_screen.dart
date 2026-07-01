import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/category.dart';
import 'series_detail_screen.dart';
import 'vod_poster.dart';

/// Cuadrícula de series (carátula + título) de una categoría, con buscador.
/// Tocar abre el detalle con temporadas y episodios.
class SeriesGridScreen extends ConsumerStatefulWidget {
  final Category category;
  const SeriesGridScreen({super.key, required this.category});

  @override
  ConsumerState<SeriesGridScreen> createState() => _SeriesGridScreenState();
}

class _SeriesGridScreenState extends ConsumerState<SeriesGridScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final async =
        ref.watch(seriesGroupsByCategoryProvider(widget.category.name));
    return Scaffold(
      appBar: AppBar(title: Text(widget.category.name)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Filtrar en esta categoría',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (all) {
                final series = _query.isEmpty
                    ? all
                    : all
                        .where((s) => s.title.toLowerCase().contains(_query))
                        .toList();
                if (series.isEmpty) {
                  return const Center(child: Text('Sin resultados'));
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 140,
                    childAspectRatio: 0.6,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: series.length,
                  itemBuilder: (_, i) {
                    final s = series[i];
                    return VodPoster(
                      title: s.title,
                      posterUrl: s.poster,
                      fallbackIcon: Icons.theaters,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => SeriesDetailScreen(series: s)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
