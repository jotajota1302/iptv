import 'package:flutter/gestures.dart';
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

/// Carrusel horizontal de tarjetas de tamaño fijo, con barra de scroll
/// visible (escritorio) y desplazamiento con la rueda del ratón.
class ContentRail extends StatefulWidget {
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
  State<ContentRail> createState() => _ContentRailState();
}

class _ContentRailState extends State<ContentRail> {
  final _ctrl = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// La rueda del ratón (vertical) desplaza el rail en horizontal.
  void _onScroll(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || !_ctrl.hasClients) return;
    final delta = e.scrollDelta.dy.abs() > e.scrollDelta.dx.abs()
        ? e.scrollDelta.dy
        : e.scrollDelta.dx;
    _ctrl.jumpTo((_ctrl.offset + delta)
        .clamp(0.0, _ctrl.position.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: widget.title, onSeeAll: widget.onSeeAll),
        SizedBox(
          height: widget.height + 12,
          child: Listener(
            onPointerSignal: _onScroll,
            child: Scrollbar(
              controller: _ctrl,
              thumbVisibility: true,
              thickness: 3,
              radius: const Radius.circular(2),
              child: ListView.separated(
                controller: _ctrl,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                itemCount: widget.items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) =>
                    SizedBox(width: widget.itemWidth, child: widget.items[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Skeleton de cuadrícula de carátulas mientras carga.
class PosterGridSkeleton extends StatelessWidget {
  const PosterGridSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 140,
          childAspectRatio: 0.6,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: 12,
        itemBuilder: (_, _) => const SkeletonBox(radius: 14),
      ),
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
