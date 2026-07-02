import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/content_type.dart';
import '../domain/media_item.dart';
import 'home_tab.dart';
import 'player_screen.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startupChannel();
      _autoRefresh();
    });
  }

  /// Si está activado "arrancar en el último canal", lo abre directamente
  /// (con su categoría como cola de zapping si sigue existiendo).
  Future<void> _startupChannel() async {
    if (!ref.read(startLastChannelProvider)) return;
    final raw = ref.read(sharedPrefsProvider).getString('last_channel');
    if (raw == null) return;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final url = '${m['url']}';
      if (url.isEmpty) return;
      final group = m['group'];
      List<MediaItem>? queue;
      if (group is String) {
        queue = await ref.read(liveByCategoryProvider(group).future);
      }
      final idx = queue?.indexWhere((e) => e.streamUrl == url) ?? -1;
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PlayerScreen(
          item: idx >= 0
              ? queue![idx]
              : MediaItem(
                  id: 'last:$url',
                  name: '${m['name']}',
                  streamUrl: url,
                  groupTitle: group is String ? group : null,
                  type: ContentType.live,
                ),
          queue: idx >= 0 ? queue : null,
          queueIndex: idx >= 0 ? idx : 0,
        ),
      ));
    } catch (_) {}
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
