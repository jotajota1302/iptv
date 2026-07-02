import 'package:flutter/material.dart';

/// Cuadrícula de "filas" (tiles horizontales de altura fija) que reparte el
/// ancho en columnas: 1 en móvil, 2-4 en escritorio. Sustituye a las listas
/// de una sola columna, que en pantallas anchas dejaban media fila vacía.
class RowGrid extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Ancho máximo de cada tile: define cuántas columnas caben.
  final double maxTileWidth;
  final double tileHeight;

  /// true para incrustarla en otra lista scrollable (p. ej. bajo un rail).
  final bool shrinkWrap;
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;

  const RowGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.maxTileWidth = 470,
    this.tileHeight = 64,
    this.shrinkWrap = false,
    this.controller,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: controller,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: padding,
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: maxTileWidth,
        mainAxisExtent: tileHeight,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
