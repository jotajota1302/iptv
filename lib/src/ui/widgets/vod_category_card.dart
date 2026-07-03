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

  /// Tarjeta grande (pantallas anchas): carátulas y texto escalados.
  final bool big;
  const VodCategoryCard({
    super.key,
    required this.cat,
    required this.posters,
    required this.fallbackIcon,
    required this.countLabel,
    required this.onTap,
    required this.onHide,
    this.big = false,
  });

  Widget _poster(String url) => Padding(
        padding: EdgeInsets.only(right: big ? 8 : 5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(big ? 8 : 6),
          child: SizedBox(
            width: big ? 56 : 30,
            height: big ? 84 : 44,
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
    final titleSize = big ? 17.0 : 15.0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(big ? 16 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: posters.isEmpty
                        ? Align(
                            alignment: Alignment.centerLeft,
                            child: Icon(fallbackIcon, size: big ? 40 : 28))
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
              // Bloque de título con altura reservada (2 líneas): los nombres
              // largos no empujan el contenido fuera de la tarjeta y todas
              // quedan alineadas.
              SizedBox(
                height: titleSize * 1.2 * 2 + 2,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    cat.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: titleSize,
                        height: 1.2,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text('${cat.itemCount} $countLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
