import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/sort_mode.dart';

/// Botón de menú (para AppBar) que elige el modo de ordenación global.
class SortMenu extends ConsumerWidget {
  const SortMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(sortModeProvider);
    return PopupMenuButton<SortMode>(
      icon: const Icon(Icons.sort),
      tooltip: 'Ordenar',
      onSelected: (m) => setSortMode(ref, m),
      itemBuilder: (_) => [
        for (final m in SortMode.values)
          CheckedPopupMenuItem(
            value: m,
            checked: m == current,
            child: Text(m.label),
          ),
      ],
    );
  }
}
