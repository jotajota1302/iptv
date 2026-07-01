import 'package:flutter/material.dart';
import 'shimmer.dart';

/// Cabecera de sección (título + acción opcional "Ver todos").
class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const SectionHeader({super.key, required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: const Text('Ver todos'),
            ),
        ],
      ),
    );
  }
}

/// Carrusel horizontal de tarjetas de tamaño fijo.
class ContentRail extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  final List<Widget> items;
  final double itemWidth;
  final double height;
  const ContentRail({
    super.key,
    required this.title,
    required this.items,
    this.onSeeAll,
    this.itemWidth = 122,
    this.height = 210,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, onSeeAll: onSeeAll),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => SizedBox(width: itemWidth, child: items[i]),
          ),
        ),
      ],
    );
  }
}

/// Skeleton de un rail mientras carga.
class RailSkeleton extends StatelessWidget {
  final double itemWidth;
  final double height;
  const RailSkeleton({super.key, this.itemWidth = 122, this.height = 210});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 8, 8),
          child: SkeletonBox(width: 160, height: 18),
        ),
        SizedBox(
          height: height,
          child: Shimmer(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 5,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, _) =>
                  SkeletonBox(width: itemWidth, height: height, radius: 14),
            ),
          ),
        ),
      ],
    );
  }
}
