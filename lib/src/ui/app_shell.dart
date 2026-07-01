import 'package:flutter/material.dart';
import 'live_tab.dart';
import 'movies_tab.dart';
import 'series_tab.dart';
import 'favorites_tab.dart';
import 'search_tab.dart';
import 'settings_tab.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  static const _tabs = [
    LiveTab(),
    MoviesTab(),
    SeriesTab(),
    FavoritesTab(),
    SearchTab(),
    SettingsTab(),
  ];
  static const _destinations = [
    (icon: Icons.live_tv, label: 'TV'),
    (icon: Icons.movie, label: 'Películas'),
    (icon: Icons.theaters, label: 'Series'),
    (icon: Icons.favorite, label: 'Favoritos'),
    (icon: Icons.search, label: 'Buscar'),
    (icon: Icons.settings, label: 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 600;
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                    icon: Icon(d.icon), label: Text(d.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _tabs[_index]),
        ]),
      );
    }
    return Scaffold(
      body: _tabs[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }
}
