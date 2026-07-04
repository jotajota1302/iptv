import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../app/external_viewer.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../data/epg_service.dart';
import '../data/xmltv_service.dart';
import '../domain/category.dart';
import '../domain/deinterlacer.dart';
import '../domain/media_item.dart';
import '../domain/sort_mode.dart';
import '../player/media_kit_player_controller.dart';
import 'channel_guide_screen.dart';
import 'channel_reorder_screen.dart';
import 'epg_grid_screen.dart';
import 'player_screen.dart';
import 'sort_menu.dart';
import 'widgets/row_grid.dart';

/// Ancho mínimo para mostrar el panel de preview lateral.
const _kPreviewBreakpoint = 820.0;

class ChannelListScreen extends ConsumerStatefulWidget {
  final Category category;
  const ChannelListScreen({super.key, required this.category});

  @override
  ConsumerState<ChannelListScreen> createState() => _ChannelListScreenState();
}

class _ChannelListScreenState extends ConsumerState<ChannelListScreen> {
  MediaKitPlayerController? _previewCtrl;
  VideoController? _previewVideo;
  MediaItem? _selected;
  final _scroll = ScrollController();
  bool _showToTop = false;

  /// Canales tal y como se muestran (ya ordenados): es la cola de zapping
  /// que se pasa al reproductor a pantalla completa.
  List<MediaItem> _visibleItems = const [];

  /// Guía XMLTV (si el servidor la da) para pintar el programa en emisión
  /// con su hora en cada canal. Se refresca cada minuto.
  XmltvGuide? _guide;
  Timer? _epgTick;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final show = _scroll.offset > 600;
      if (show != _showToTop) setState(() => _showToTop = show);
    });
    _epgTick = Timer.periodic(
        const Duration(seconds: 60), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _epgTick?.cancel();
    _scroll.dispose();
    _previewCtrl?.dispose();
    super.dispose();
  }

  /// Programa en emisión de un canal según la guía XMLTV (lista ordenada).
  EpgEntry? _nowFor(MediaItem it) {
    final guide = _guide;
    if (guide == null) return null;
    final now = DateTime.now();
    for (final e in guide.forChannel(it.tvgId, it.name)) {
      if (!now.isBefore(e.start) && now.isBefore(e.end)) return e;
      if (e.start.isAfter(now)) break;
    }
    return null;
  }

  double _epgProgress(EpgEntry e) {
    final now = DateTime.now();
    final len = e.end.difference(e.start).inSeconds.clamp(1, 1 << 31);
    return (now.difference(e.start).inSeconds / len).clamp(0.0, 1.0);
  }

  void _ensurePreview() {
    if (_previewCtrl != null) return;
    final ctrl = MediaKitPlayerController();
    _previewCtrl = ctrl;
    _previewVideo = VideoController(
      ctrl.player,
      configuration: VideoControllerConfiguration(
          enableHardwareAcceleration: ref.read(hardwareAccelProvider)),
    );
  }

  /// Reproduce el canal en el panel de preview (pantallas anchas).
  Future<void> _preview(MediaItem it) async {
    _ensurePreview();
    setState(() => _selected = it);
    await _previewCtrl!.open(it.streamUrl);
    await _previewCtrl!.setDeinterlace(ref.read(deinterlaceProvider),
        candidates: deinterlacerCandidates(ref.read(deinterlacerProvider)));
  }

  /// Abre el canal en pantalla completa. Pausa el preview antes (evita audio
  /// doble) y lo deja parado al volver: nada sigue sonando al salir. Se pasa
  /// la lista visible como cola para poder hacer zapping (canal ant./sig.).
  Future<void> _fullscreen(MediaItem it) async {
    await _previewCtrl?.pause();
    if (!mounted) return;
    final idx = _visibleItems.indexWhere((e) => e.id == it.id);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          item: it,
          queue: idx >= 0 ? _visibleItems : null,
          queueIndex: idx >= 0 ? idx : 0,
        ),
      ),
    );
  }

  Future<void> _action(String action, MediaItem it) async {
    final repo = ref.read(playlistRepositoryProvider);
    if (action == 'favorito') {
      await repo.toggleFavorite(it);
    } else if (action == 'ocultar') {
      await repo.hideItem(it);
    } else if (action == 'borrar') {
      await repo.deleteItem(it);
    }
    ref.invalidate(liveByCategoryProvider(widget.category.name));
    ref.invalidate(liveCategoriesProvider);
    ref.invalidate(favoritesProvider);
  }

  PopupMenuButton<String> _menu(MediaItem it) => PopupMenuButton<String>(
        onSelected: (a) => a == 'ventana'
            ? openExternalViewer(it)
            : _action(a, it),
        itemBuilder: (_) => [
          PopupMenuItem(
              value: 'favorito',
              child: Text(it.isFavorite
                  ? 'Quitar de favoritos'
                  : 'Añadir a favoritos')),
          if (canOpenExternalViewer)
            const PopupMenuItem(
                value: 'ventana', child: Text('Abrir en ventana nueva')),
          const PopupMenuItem(value: 'ocultar', child: Text('Ocultar')),
          const PopupMenuItem(value: 'borrar', child: Text('Borrar')),
        ],
      );

  Widget _logo(MediaItem it, {double size = 48}) {
    // Plato claro: los logos de TV suelen ser oscuros sobre transparente, así
    // que sobre blanco se ven mucho mejor. Con margen y esquinas redondeadas
    // para un acabado limpio.
    final fallback = Icon(Icons.live_tv, size: size * 0.5, color: Colors.black38);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: it.logoUrl == null
          ? fallback
          : CachedNetworkImage(
              imageUrl: it.logoUrl!,
              fit: BoxFit.contain,
              errorWidget: (_, _, _) => fallback,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(liveByCategoryProvider(widget.category.name));
    final grid = ref.watch(channelGridProvider);
    final sort = ref.watch(sortModeProvider);
    final customOrder =
        ref.watch(channelOrderProvider)[widget.category.name];
    _guide = ref.watch(xmltvGuideProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_view_week),
            tooltip: 'Guía de programación (rejilla)',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  EpgGridScreen(categoryName: widget.category.name),
            )),
          ),
          IconButton(
            icon: const Icon(Icons.swap_vert),
            tooltip: 'Ordenar canales a mano (arrastrar)',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChannelReorderScreen(
                category: widget.category.name,
                items: _visibleItems,
              ),
            )),
          ),
          SortMenu(
            current: sort,
            modes: channelSortModes(showCustom: true),
            onSelected: (m) => setSortMode(ref, m),
          ),
          if (grid)
            PopupMenuButton<int>(
              icon: const Icon(Icons.photo_size_select_large),
              tooltip: 'Tamaño de los canales',
              initialValue: ref.watch(channelTileSizeProvider),
              onSelected: (v) => setChannelTileSize(ref, v),
              itemBuilder: (_) => const [
                CheckedPopupMenuItem(value: 0, child: Text('Compacto')),
                CheckedPopupMenuItem(value: 1, child: Text('Medio')),
                CheckedPopupMenuItem(value: 2, child: Text('Grande')),
              ],
            ),
          IconButton(
            icon: Icon(grid ? Icons.view_list : Icons.grid_view),
            tooltip: grid ? 'Ver como lista' : 'Ver como cuadrícula',
            onPressed: () => setChannelGrid(ref, !grid),
          ),
        ],
      ),
      floatingActionButton: _showToTop
          ? FloatingActionButton.small(
              tooltip: 'Volver arriba',
              onPressed: () => _scroll.animateTo(0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic),
              child: const Icon(Icons.keyboard_arrow_up),
            )
          : null,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (all) => LayoutBuilder(
          builder: (context, constraints) {
            final items = sortItems(all, sort, customOrder: customOrder);
            _visibleItems = items;
            final wide = constraints.maxWidth >= _kPreviewBreakpoint;
            final content = grid
                ? _buildGrid(context, items, wide)
                : _buildList(context, items, wide);
            if (!wide) return content;
            return Row(
              children: [
                Expanded(child: content),
                const VerticalDivider(width: 1),
                SizedBox(width: 380, child: _previewPanel()),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Al tocar un canal: preview si hay panel, o pantalla completa si no.
  void _onTap(MediaItem it, bool wide) => wide ? _preview(it) : _fullscreen(it);

  Widget _previewPanel() {
    final sel = _selected;
    if (sel == null || _previewVideo == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Selecciona un canal para previsualizar qué están emitiendo',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: Colors.black,
            child: Video(controller: _previewVideo!, controls: NoVideoControls),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(sel.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              FilledButton.icon(
                onPressed: () => _fullscreen(sel),
                icon: const Icon(Icons.fullscreen),
                label: const Text('Pantalla completa'),
              ),
              const SizedBox(width: 4),
              if (canOpenExternalViewer)
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  tooltip: 'Abrir en ventana nueva',
                  onPressed: () async {
                    // El visor externo asume la reproducción: paramos el
                    // preview para no oír el canal por duplicado.
                    await openExternalViewer(sel);
                    await _previewCtrl?.pause();
                  },
                ),
              IconButton(
                icon: Icon(
                    sel.isFavorite ? Icons.favorite : Icons.favorite_border),
                onPressed: () => _action('favorito', sel),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChannelGuideScreen(channel: sel),
            )),
            icon: const Icon(Icons.calendar_month, size: 18),
            label: const Text('Guía completa'),
          ),
        ),
        const Divider(height: 8),
        Expanded(child: _epgSection(sel)),
      ],
    );
  }

  /// Sección de programación (EPG) bajo el preview: programa actual y los
  /// siguientes. Si no hay datos disponibles, muestra un aviso discreto.
  Widget _epgSection(MediaItem sel) {
    final async = ref.watch(previewEpgProvider(sel.streamUrl));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const _EpgEmpty(),
      data: (entries) {
        if (entries.isEmpty) return const _EpgEmpty();
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: entries.length,
          itemBuilder: (_, i) {
            final e = entries[i];
            final now = DateTime.now();
            final current = !now.isBefore(e.start) && now.isBefore(e.end);
            final weight = current ? FontWeight.bold : FontWeight.normal;
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Text(_hhmm(e.start), style: TextStyle(fontWeight: weight)),
              title: Text(e.title, style: TextStyle(fontWeight: weight)),
              // El programa en emisión muestra su avance y cuándo termina.
              subtitle: current
                  ? Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: (now.difference(e.start).inSeconds /
                                      e.end
                                          .difference(e.start)
                                          .inSeconds
                                          .clamp(1, 1 << 31))
                                  .clamp(0.0, 1.0),
                              minHeight: 4,
                              backgroundColor: Colors.white12,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text('Hasta las ${_hhmm(e.end)}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white54)),
                        ],
                      ),
                    )
                  : null,
            );
          },
        );
      },
    );
  }

  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Widget _buildList(BuildContext context, List<MediaItem> items, bool wide) {
    return RowGrid(
      controller: _scroll,
      itemCount: items.length,
      maxTileWidth: 560,
      tileHeight: _guide != null ? 66 : 58,
      itemBuilder: (_, i) {
        final it = items[i];
        final nowE = _nowFor(it);
        return ListTile(
          selected: _selected?.id == it.id,
          // Número de canal: coincide con el zapping por número (teclas 0-9).
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 30,
                child: Text('${i + 1}',
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.white38)),
              ),
              _logo(it),
            ],
          ),
          title: Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: nowE == null
              ? null
              : Text(
                  '${_hhmm(nowE.start)}–${_hhmm(nowE.end)} · ${nowE.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.white54)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.fullscreen),
                tooltip: 'Pantalla completa',
                onPressed: () => _fullscreen(it),
              ),
              IconButton(
                icon: Icon(
                    it.isFavorite ? Icons.favorite : Icons.favorite_border),
                onPressed: () => _action('favorito', it),
              ),
              _menu(it),
            ],
          ),
          onTap: () => _onTap(it, wide),
        );
      },
    );
  }

  /// Tamaños de la cuadrícula según la densidad elegida (S/M/L).
  static const _tileExtents = [150.0, 195.0, 248.0];
  static const _logoSizes = [56.0, 78.0, 100.0];

  Widget _buildGrid(BuildContext context, List<MediaItem> items, bool wide) {
    final density = ref.watch(channelTileSizeProvider);
    final showEpg = _guide != null;
    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _tileExtents[density],
        // Con EPG la tarjeta es algo más alta para el programa y su hora.
        childAspectRatio: showEpg ? 0.9 : 1.06,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final it = items[i];
        final nowE = _nowFor(it);
        return _ChannelCard(
          logo: _logo(it, size: _logoSizes[density]),
          name: it.name,
          epgLine: nowE == null
              ? (showEpg ? '' : null)
              : '${_hhmm(nowE.start)}–${_hhmm(nowE.end)} · ${nowE.title}',
          epgProgress: nowE == null ? null : _epgProgress(nowE),
          selected: _selected?.id == it.id,
          favorite: it.isFavorite,
          onTap: () => _onTap(it, wide),
          onLongPress: () => _actionsSheet(it),
          hoverActions: [
            _hoverBtn(
              it.isFavorite ? Icons.favorite : Icons.favorite_border,
              'Favorito',
              () => _action('favorito', it),
            ),
            if (canOpenExternalViewer)
              _hoverBtn(Icons.open_in_new, 'Abrir en ventana nueva',
                  () => openExternalViewer(it)),
            _hoverBtn(Icons.fullscreen, 'Pantalla completa',
                () => _fullscreen(it)),
          ],
        );
      },
    );
  }

  Widget _hoverBtn(IconData icon, String tooltip, VoidCallback onTap) {
    return IconButton(
      iconSize: 17,
      padding: const EdgeInsets.all(5),
      constraints: const BoxConstraints(),
      visualDensity: VisualDensity.compact,
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: onTap,
    );
  }

  /// Hoja de acciones del canal (pulsación larga: táctil / mando).
  void _actionsSheet(MediaItem it) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) {
        void run(void Function() f) {
          Navigator.pop(sheet);
          f();
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(it.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.fullscreen),
                title: const Text('Pantalla completa'),
                onTap: () => run(() => _fullscreen(it)),
              ),
              ListTile(
                leading: Icon(
                    it.isFavorite ? Icons.favorite : Icons.favorite_border),
                title: Text(it.isFavorite
                    ? 'Quitar de favoritos'
                    : 'Añadir a favoritos'),
                onTap: () => run(() => _action('favorito', it)),
              ),
              if (canOpenExternalViewer)
                ListTile(
                  leading: const Icon(Icons.open_in_new),
                  title: const Text('Abrir en ventana nueva'),
                  onTap: () => run(() => openExternalViewer(it)),
                ),
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text('Ocultar'),
                onTap: () => run(() => _action('ocultar', it)),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Borrar'),
                onTap: () => run(() => _action('borrar', it)),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Tile de canal: logo protagonista y nombre; las acciones aparecen al pasar
/// el ratón (escritorio) o con pulsación larga (táctil/TV), para que la
/// cuadrícula respire. El corazón marca los favoritos de forma permanente.
class _ChannelCard extends StatefulWidget {
  final Widget logo;
  final String name;

  /// Programa en emisión con su franja ("20:30–22:00 · Telediario").
  /// '' reserva la línea sin datos (para que la cuadrícula no baile);
  /// null = la lista no tiene guía y la línea no existe.
  final String? epgLine;
  final double? epgProgress;
  final bool selected;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final List<Widget> hoverActions;
  const _ChannelCard({
    required this.logo,
    required this.name,
    this.epgLine,
    this.epgProgress,
    required this.selected,
    required this.favorite,
    required this.onTap,
    required this.onLongPress,
    required this.hoverActions,
  });

  @override
  State<_ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<_ChannelCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      color: widget.selected
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
                      child: Center(child: widget.logo),
                    ),
                  ),
                  // Altura fija (2 líneas) para que el logo no baile según la
                  // longitud del nombre.
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
                    child: SizedBox(
                      height: 32,
                      child: Center(
                        child: Text(
                          widget.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, height: 1.15),
                        ),
                      ),
                    ),
                  ),
                  // Programa en emisión + avance (si la lista tiene guía).
                  if (widget.epgLine != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 7),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 14,
                            child: Text(
                              widget.epgLine!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 10.5, color: Colors.white54),
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: widget.epgProgress ?? 0,
                              minHeight: 3,
                              backgroundColor: Colors.white10,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const SizedBox(height: 4),
                ],
              ),
              if (widget.favorite)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Icon(Icons.favorite, size: 14, color: kAccent),
                ),
              if (_hover)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: widget.hoverActions,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aviso cuando no hay guía de programación disponible para el canal.
class _EpgEmpty extends StatelessWidget {
  const _EpgEmpty();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('Sin guía de programación disponible',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}
