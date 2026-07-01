import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../app/providers.dart';
import '../domain/category.dart';
import '../domain/media_item.dart';
import '../player/media_kit_player_controller.dart';
import 'player_screen.dart';

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

  @override
  void dispose() {
    _previewCtrl?.dispose();
    super.dispose();
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
    await _previewCtrl!.setDeinterlace(ref.read(deinterlaceProvider));
  }

  /// Abre el canal en pantalla completa. Pausa el preview antes (evita audio
  /// doble) y lo deja parado al volver: nada sigue sonando al salir.
  Future<void> _fullscreen(MediaItem it) async {
    await _previewCtrl?.pause();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlayerScreen(item: it)),
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
        onSelected: (a) => _action(a, it),
        itemBuilder: (_) => [
          PopupMenuItem(
              value: 'favorito',
              child: Text(it.isFavorite
                  ? 'Quitar de favoritos'
                  : 'Añadir a favoritos')),
          const PopupMenuItem(value: 'ocultar', child: Text('Ocultar')),
          const PopupMenuItem(value: 'borrar', child: Text('Borrar')),
        ],
      );

  Widget _logo(MediaItem it, {double size = 48}) {
    final fallback =
        Icon(Icons.live_tv, size: size * 0.55, color: Colors.black54);
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.name),
        actions: [
          IconButton(
            icon: Icon(grid ? Icons.view_list : Icons.grid_view),
            tooltip: grid ? 'Ver como lista' : 'Ver como cuadrícula',
            onPressed: () => setChannelGrid(ref, !grid),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) => LayoutBuilder(
          builder: (context, constraints) {
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
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                    sel.isFavorite ? Icons.favorite : Icons.favorite_border),
                onPressed: () => _action('favorito', sel),
              ),
            ],
          ),
        ),
        const Divider(height: 24),
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
            final now = i == 0;
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Text(_hhmm(e.start),
                  style: TextStyle(
                      fontWeight: now ? FontWeight.bold : FontWeight.normal)),
              title: Text(e.title,
                  style: TextStyle(
                      fontWeight: now ? FontWeight.bold : FontWeight.normal)),
              subtitle: now ? const Text('Ahora') : null,
            );
          },
        );
      },
    );
  }

  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Widget _buildList(BuildContext context, List<MediaItem> items, bool wide) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final it = items[i];
        return ListTile(
          selected: _selected?.id == it.id,
          leading: _logo(it),
          title: Text(it.name),
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

  Widget _buildGrid(BuildContext context, List<MediaItem> items, bool wide) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        childAspectRatio: 0.82,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final it = items[i];
        final selected = _selected?.id == it.id;
        return Card(
          clipBehavior: Clip.antiAlias,
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: InkWell(
            onTap: () => _onTap(it, wide),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Center(child: _logo(it, size: 64)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    it.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(it.isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border),
                      onPressed: () => _action('favorito', it),
                    ),
                    IconButton(
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.fullscreen),
                      tooltip: 'Pantalla completa',
                      onPressed: () => _fullscreen(it),
                    ),
                    _menu(it),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
