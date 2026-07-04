import 'package:flutter/material.dart';
import '../domain/sort_mode.dart';

/// Modos de ordenación ofrecidos en las agrupaciones VOD (películas y series).
/// "Novedades" va primero por ser el orden por defecto.
const kVodSortModes = [
  SortMode.newest,
  SortMode.nameAsc,
  SortMode.nameDesc,
  SortMode.yearDesc,
  SortMode.yearAsc,
];

/// Modos ofrecidos en la lista de canales (incluye el manual si [showCustom]).
List<SortMode> channelSortModes({bool showCustom = false}) => [
      SortMode.nameAsc,
      SortMode.nameDesc,
      SortMode.recent,
      SortMode.favFirst,
      if (showCustom) SortMode.custom,
    ];

/// Botón de menú (para AppBar) que elige el modo de ordenación. Recibe el modo
/// actual, la lista de modos a mostrar y el callback de selección; así la misma
/// pieza sirve para canales y para VOD sobre providers distintos.
class SortMenu extends StatelessWidget {
  final SortMode current;
  final List<SortMode> modes;
  final ValueChanged<SortMode> onSelected;
  const SortMenu({
    super.key,
    required this.current,
    required this.modes,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SortMode>(
      icon: const Icon(Icons.sort),
      tooltip: 'Ordenar',
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final m in modes)
          CheckedPopupMenuItem(
            value: m,
            checked: m == current,
            child: Text(m.label),
          ),
      ],
    );
  }
}
