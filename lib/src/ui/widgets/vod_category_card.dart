import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../domain/category.dart';

/// Tarjeta de categoría de Películas/Series para la vista en cuadrícula:
/// collage con las primeras carátulas (2:3), nombre y recuento.
class VodCategoryCard extends StatelessWidget {
  final Category cat;
  final List<String> posters;
  final IconData fallbackIcon;
  final String countLabel;
  final VoidCallback onTap;
  final VoidCallback onHide;
  const VodCategoryCard({
    super.key,
    required this.cat,
    required this.posters,
    required this.fallbackIcon,
    required this.countLabel,
    required this.onTap,
    required this.onHide,
  });

  Widget _poster(String url) => Padding(
        padding: const EdgeInsets.only(right: 5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 30,
            height: 44,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => Container(
                  color: Colors.white10,
                  child: Icon(fallbackIcon, size: 14, color: Colors.white24)),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: posters.isEmpty
                        ? Icon(fallbackIcon, size: 28)
                        : Row(children: [
                            for (final p in posters.take(3)) _poster(p),
                          ]),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (_) => onHide(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'ocultar',
                          child: ListTile(
                              leading: Icon(Icons.visibility_off),
                              title: Text('Ocultar categoría'))),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              Text(
                cat.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text('${cat.itemCount} $countLabel',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
