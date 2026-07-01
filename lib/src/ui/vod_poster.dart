import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Carátula VOD reutilizable: imagen 2:3, título y, opcionalmente, una barra de
/// progreso (fracción vista), un menú contextual (mantener pulsado) y el título
/// superpuesto con degradado (estilo streaming) para los carruseles.
class VodPoster extends StatelessWidget {
  final String title;
  final String? posterUrl;
  final IconData fallbackIcon;
  final double watchedFraction;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool favorite;

  /// Si es true, el título se dibuja sobre la imagen con degradado (rails).
  /// Si es false (por defecto), va debajo (cuadrículas).
  final bool titleOverlay;

  const VodPoster({
    super.key,
    required this.title,
    required this.posterUrl,
    required this.onTap,
    this.fallbackIcon = Icons.movie_outlined,
    this.watchedFraction = 0,
    this.onLongPress,
    this.favorite = false,
    this.titleOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    final image = _poster(context);
    if (titleOverlay) {
      return _Frame(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            _scrim(),
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
              ),
            ),
            if (favorite) _favBadge(),
            if (watchedFraction > 0) _progress(),
          ],
        ),
      );
    }
    return _Frame(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                image,
                if (favorite) _favBadge(),
                if (watchedFraction > 0) _progress(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, height: 1.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _poster(BuildContext context) {
    final fallback = Container(
      color: const Color(0xFF23252F),
      child: Icon(fallbackIcon, size: 38, color: Colors.white24),
    );
    if (posterUrl == null) return fallback;
    return CachedNetworkImage(
      imageUrl: posterUrl!,
      fit: BoxFit.cover,
      fadeInDuration: const Duration(milliseconds: 250),
      placeholder: (_, _) => Container(color: const Color(0xFF1E2029)),
      errorWidget: (_, _, _) => fallback,
    );
  }

  Widget _scrim() => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.center,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xE6000000)],
          ),
        ),
      );

  Widget _favBadge() => const Positioned(
        top: 6,
        right: 6,
        child: CircleAvatar(
          radius: 12,
          backgroundColor: Colors.black54,
          child: Icon(Icons.favorite, color: Colors.redAccent, size: 14),
        ),
      );

  Widget _progress() => Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: LinearProgressIndicator(
          value: watchedFraction,
          minHeight: 3,
          backgroundColor: Colors.white24,
        ),
      );
}

class _Frame extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _Frame({required this.child, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF181A20),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: child,
      ),
    );
  }
}
