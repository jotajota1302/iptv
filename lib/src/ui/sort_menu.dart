import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/sort_mode.dart';

/// Botón de menú (para AppBar) que elige el modo de ordenación global.
/// [showCustom] solo donde existe reordenación manual (canales).
class SortMenu extends ConsumerWidget {
  final bool showCustom;
  const SortMenu({super.key, this.showCustom = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(sortModeProvider);
    final modes = SortMode.values
        .where((m) => showCustom || m != SortMode.custom)
        .toList();
    return PopupMenuButton<SortMode>(
      icon: const Icon(Icons.sort),
      tooltip: 'Ordenar',
      onSelected: (m) => setSortMode(ref, m),
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
