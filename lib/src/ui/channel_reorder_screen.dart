import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/media_item.dart';
import '../domain/sort_mode.dart';

/// Reordenación manual de los canales de una categoría (drag & drop). Cada
/// arrastre se guarda al momento y activa el modo de orden "Personalizado".
class ChannelReorderScreen extends ConsumerStatefulWidget {
  final String category;
  final List<MediaItem> items;
  const ChannelReorderScreen(
      {super.key, required this.category, required this.items});

  @override
  ConsumerState<ChannelReorderScreen> createState() =>
      _ChannelReorderScreenState();
}

class _ChannelReorderScreenState extends ConsumerState<ChannelReorderScreen> {
  late final List<MediaItem> _items = [...widget.items];

  // onReorderItem ya entrega newIndex ajustado (sin el hueco del extraído).
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final it = _items.removeAt(oldIndex);
      _items.insert(newIndex, it);
    });
    setChannelOrder(ref, widget.category, [for (final i in _items) i.id]);
    if (ref.read(sortModeProvider) != SortMode.custom) {
      setSortMode(ref, SortMode.custom);
    }
  }

  Widget _logo(MediaItem it) {
    const fallback =
        Icon(Icons.live_tv, size: 20, color: Colors.black38);
    return Container(
      width: 40,
      height: 40,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Ordenar · ${widget.category}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Restablecer orden del proveedor',
            onPressed: () {
              setChannelOrder(ref, widget.category, const []);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Text(
              'Arrastra los canales para colocarlos a tu gusto. El orden se '
              'guarda solo y se usa también para el zapping.',
              style: TextStyle(fontSize: 12.5, color: Colors.white54),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              itemCount: _items.length,
              onReorderItem: _onReorder,
              itemBuilder: (_, i) {
                final it = _items[i];
                return ReorderableDragStartListener(
                  key: ValueKey(it.id),
                  index: i,
                  child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 30,
                          child: Text('${i + 1}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.white38)),
                        ),
                        _logo(it),
                      ],
                    ),
                    title: Text(it.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing:
                        const Icon(Icons.drag_handle, color: Colors.white38),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
