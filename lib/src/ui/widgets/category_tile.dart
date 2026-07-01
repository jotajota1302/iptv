import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// Fila de categoría con estilo premium: icono en contenedor redondeado,
/// nombre, contador y menú opcional para ocultar.
class CategoryTile extends StatelessWidget {
  final IconData icon;
  final String name;
  final int count;
  final VoidCallback onTap;
  final VoidCallback? onHide;
  const CategoryTile({
    super.key,
    required this.icon,
    required this.name,
    required this.count,
    required this.onTap,
    this.onHide,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Material(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kAccent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: kAccent, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: kSurfaceHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$count',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white70)),
                ),
                if (onHide != null)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (a) {
                      if (a == 'ocultar') onHide!();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'ocultar',
                          child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.visibility_off),
                              title: Text('Ocultar categoría'))),
                    ],
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.chevron_right, color: Colors.white38),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton de una lista de categorías.
class CategoryListSkeleton extends StatelessWidget {
  const CategoryListSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        for (var i = 0; i < 8; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
      ],
    );
  }
}
