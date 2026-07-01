import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/saved_playlist.dart';
import 'management_screen.dart';

class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});
  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  final _urlCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<int> Function() action) async {
    setState(() => _loading = true);
    ref.read(loadStateProvider.notifier).state = null;
    try {
      final n = await action();
      ref.read(loadStateProvider.notifier).state = 'Cargados $n elementos';
      ref.invalidate(liveCategoriesProvider);
      ref.invalidate(favoritesProvider);
    } catch (e) {
      ref.read(loadStateProvider.notifier).state = 'Error: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Guarda una nueva lista (nombre + URL) y la carga.
  Future<void> _addAndLoad() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    final name = _nameCtrl.text.trim().isEmpty
        ? 'Lista ${ref.read(playlistsProvider).playlists.length + 1}'
        : _nameCtrl.text.trim();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    ref
        .read(playlistsProvider.notifier)
        .add(SavedPlaylist(id: id, name: name, url: url));
    _urlCtrl.clear();
    _nameCtrl.clear();
    await _run(() => ref.read(playlistRepositoryProvider).loadFromUrl(url));
  }

  /// Cambia a una lista guardada y la carga.
  Future<void> _activate(SavedPlaylist pl) async {
    ref.read(playlistsProvider.notifier).setActive(pl.id);
    await _run(() => ref.read(playlistRepositoryProvider).loadFromUrl(pl.url));
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(playlistRepositoryProvider);
    final status = ref.watch(loadStateProvider);
    final hwAccel = ref.watch(hardwareAccelProvider);
    final deinterlace = ref.watch(deinterlaceProvider);
    final playlists = ref.watch(playlistsProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- Mis listas ---
        if (playlists.playlists.isNotEmpty) ...[
          const Text('Mis listas', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          for (final pl in playlists.playlists)
            Card(
              child: ListTile(
                leading: Icon(
                  pl.id == playlists.activeId
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: pl.id == playlists.activeId
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text(pl.name),
                subtitle: Text(pl.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Eliminar lista',
                  onPressed: _loading
                      ? null
                      : () => ref.read(playlistsProvider.notifier).remove(pl.id),
                ),
                onTap: _loading ? null : () => _activate(pl),
              ),
            ),
          const SizedBox(height: 20),
          const Divider(),
        ],

        // --- Añadir lista ---
        const Text('Añadir lista M3U', style: TextStyle(fontSize: 20)),
        const SizedBox(height: 12),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre (opcional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _urlCtrl,
          decoration: const InputDecoration(
            labelText: 'URL de la lista',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          FilledButton(
            onPressed: _loading ? null : _addAndLoad,
            child: const Text('Añadir y cargar'),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: _loading
                ? null
                : () async {
                    final res = await FilePicker.platform
                        .pickFiles(type: FileType.any, withData: false);
                    final path = res?.files.single.path;
                    if (path != null) await _run(() => repo.loadFromFile(path));
                  },
            child: const Text('Elegir archivo'),
          ),
        ]),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const ManagementScreen(),
          )),
          icon: const Icon(Icons.tune),
          label: const Text('Gestionar canales (ocultar / borrar)'),
        ),
        const SizedBox(height: 16),
        if (_loading) const LinearProgressIndicator(),
        if (status != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(status),
          ),

        const SizedBox(height: 24),
        const Divider(),
        const Text('Reproducción', style: TextStyle(fontSize: 20)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Aceleración por hardware (GPU)'),
          subtitle: const Text(
              'Si ves triángulos o bloques en vídeo HD/4K, desactívala '
              '(usa más CPU pero corrige artefactos). Aplica al abrir el vídeo.'),
          value: hwAccel,
          onChanged: (v) => setHardwareAccel(ref, v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Desentrelazado (deinterlace)'),
          subtitle: const Text(
              'Corrige las "líneas peine" en TV en directo entrelazada '
              '(1080i/576i). Recomendado activado. Aplica al abrir el vídeo.'),
          value: deinterlace,
          onChanged: (v) => setDeinterlaceSetting(ref, v),
        ),
      ],
    );
  }
}
