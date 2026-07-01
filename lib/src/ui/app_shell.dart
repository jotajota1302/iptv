import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import 'home_tab.dart';
import 'live_tab.dart';
import 'movies_tab.dart';
import 'series_tab.dart';
import 'search_tab.dart';
import 'settings_tab.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const _tabs = [
    HomeTab(),
    LiveTab(),
    MoviesTab(),
    SeriesTab(),
    SearchTab(),
    SettingsTab(),
  ];
  static const _destinations = [
    (icon: Icons.home_outlined, sel: Icons.home, label: 'Inicio'),
    (icon: Icons.live_tv_outlined, sel: Icons.live_tv, label: 'TV'),
    (icon: Icons.movie_outlined, sel: Icons.movie, label: 'Películas'),
    (icon: Icons.theaters_outlined, sel: Icons.theaters, label: 'Series'),
    (icon: Icons.search, sel: Icons.search, label: 'Buscar'),
    (icon: Icons.settings_outlined, sel: Icons.settings, label: 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(selectedTabProvider);
    void select(int i) => ref.read(selectedTabProvider.notifier).state = i;
    final wide = MediaQuery.of(context).size.width >= 600;

    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: index,
            onDestinationSelected: select,
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.sel),
                    label: Text(d.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _tabs[index]),
        ]),
      );
    }
    return Scaffold(
      body: _tabs[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: select,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.sel),
                label: d.label),
        ],
      ),
    );
  }
}
