import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/tmdb_service.dart';
import '../actor_screen.dart';
import 'content_rail.dart';

/// Carrusel de caras del reparto (datos de TMDB). Cada actor abre su ficha.
class CastRail extends StatelessWidget {
  final List<TmdbCastMember> cast;
  const CastRail({super.key, required this.cast});

  @override
  Widget build(BuildContext context) {
    if (cast.isEmpty) return const SizedBox.shrink();
    return ContentRail(
      title: 'Reparto',
      itemWidth: 96,
      height: 168,
      items: [
        for (final m in cast.take(20))
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ActorScreen(personId: m.id, name: m.name))),
            child: Column(
              children: [
                ClipOval(
                  child: Container(
                    width: 80,
                    height: 80,
                    color: kSurfaceHigh,
                    child: m.profileUrl == null
                        ? const Icon(Icons.person,
                            size: 36, color: Colors.white24)
                        : CachedNetworkImage(
                            imageUrl: m.profileUrl!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 6),
                Text(m.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                if (m.character != null)
                  Text(m.character!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 10, color: Colors.white54)),
              ],
            ),
          ),
      ],
    );
  }
}
