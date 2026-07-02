import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import 'home_tab.dart';
import 'live_tab.dart';
import 'movies_tab.dart';
import 'series_tab.dart';
import 'search_tab.dart';
import 'settings_tab.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoRefresh());
  }

  /// Recarga la lista activa en segundo plano al arrancar (si el ajuste está
  /// activo). Silencioso: sin red se sigue usando el contenido ya cargado.
  Future<void> _autoRefresh() async {
    if (!ref.read(autoRefreshProvider)) return;
    final active = ref.read(playlistsProvider).active;
    if (active == null) return;
    try {
      await ref.read(playlistRepositoryProvider).loadFromUrl(active.url);
      if (!mounted) return;
      ref.invalidate(liveCategoriesProvider);
      ref.invalidate(movieCategoriesProvider);
      ref.invalidate(seriesCategoriesProvider);
      ref.invalidate(recentMoviesProvider);
      ref.invalidate(recentSeriesProvider);
      ref.invalidate(continueWatchingProvider);
      ref.invalidate(favoritesProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
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
