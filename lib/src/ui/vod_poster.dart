import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Carátula VOD reutilizable: imagen 2:3, título y, opcionalmente, una barra de
/// progreso (fracción vista) y un menú contextual (mantener pulsado).
class VodPoster extends StatelessWidget {
  final String title;
  final String? posterUrl;
  final IconData fallbackIcon;
  final double watchedFraction;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool favorite;
  const VodPoster({
    super.key,
    required this.title,
    required this.posterUrl,
    required this.onTap,
    this.fallbackIcon = Icons.movie,
    this.watchedFraction = 0,
    this.onLongPress,
    this.favorite = false,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: Colors.grey.shade800,
      child: Center(child: Icon(fallbackIcon, size: 40)),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  posterUrl == null
                      ? fallback
                      : CachedNetworkImage(
                          imageUrl: posterUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => fallback,
                        ),
                  if (favorite)
                    const Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(Icons.favorite, color: Colors.redAccent, size: 18),
                    ),
                  if (watchedFraction > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: watchedFraction,
                        minHeight: 4,
                        backgroundColor: Colors.black45,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                title,
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
