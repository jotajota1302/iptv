import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/category.dart';
import '../domain/media_item.dart';
import 'player_screen.dart';

/// Cuadrícula de carátulas de películas (poster 2:3). Tocar reproduce con
/// reanudación (resume: true).
class MovieGridScreen extends ConsumerWidget {
  final Category category;
  const MovieGridScreen({super.key, required this.category});

  void _play(BuildContext context, MediaItem it) {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => PlayerScreen(item: it, resume: true)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(moviesByCategoryProvider(category.name));
    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (movies) => GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 140,
            childAspectRatio: 0.62,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: movies.length,
          itemBuilder: (_, i) => _MoviePoster(
            item: movies[i],
            onTap: () => _play(context, movies[i]),
          ),
        ),
      ),
    );
  }
}

class _MoviePoster extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;
  const _MoviePoster({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: Colors.grey.shade800,
      child: const Center(child: Icon(Icons.movie, size: 40)),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: item.logoUrl == null
                  ? fallback
                  : CachedNetworkImage(
                      imageUrl: item.logoUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => fallback,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                item.name,
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
