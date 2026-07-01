import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/content_type.dart';
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
      ref.invalidate(movieCategoriesProvider);
      ref.invalidate(seriesCategoriesProvider);
      ref.invalidate(continueWatchingProvider);
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

  /// Cambia el control parental. Al desactivarlo, si hay PIN, lo pide.
  Future<void> _toggleParental(bool value) async {
    final pin = ref.read(parentalPinProvider);
    if (!value && pin.isNotEmpty) {
      final ok = await _askPin('Introduce el PIN para mostrar +18', pin);
      if (!ok) return;
    }
    setParentalHide(ref, value);
  }

  /// Pide un PIN y devuelve true si coincide con [expected].
  Future<bool> _askPin(String title, String expected) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'PIN'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text == expected),
              child: const Text('Aceptar')),
        ],
      ),
    );
    return ok ?? false;
  }

  /// Define o cambia el PIN. Si ya había PIN, pide el actual primero.
  Future<void> _changePin() async {
    final current = ref.read(parentalPinProvider);
    if (current.isNotEmpty) {
      final ok = await _askPin('PIN actual', current);
      if (!ok) return;
    }
    if (!mounted) return;
    final ctrl = TextEditingController();
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo PIN (vacío = quitar)'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Nuevo PIN'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (nuevo != null) setParentalPin(ref, nuevo.trim());
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
        const Text('Gestionar (ocultar / borrar)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const ManagementScreen(type: ContentType.live),
          )),
          icon: const Icon(Icons.live_tv),
          label: const Text('Canales de TV'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const ManagementScreen(type: ContentType.movie),
          )),
          icon: const Icon(Icons.movie),
          label: const Text('Películas'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const ManagementScreen(type: ContentType.series),
          )),
          icon: const Icon(Icons.theaters),
          label: const Text('Series'),
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

        const SizedBox(height: 24),
        const Divider(),
        const Text('Control parental', style: TextStyle(fontSize: 20)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ocultar contenido para adultos (+18)'),
          subtitle: const Text(
              'Oculta categorías y resultados de adultos en TV, Películas, '
              'Series y búsqueda.'),
          value: ref.watch(parentalHideProvider),
          onChanged: _toggleParental,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.password),
          title: Text(ref.watch(parentalPinProvider).isEmpty
              ? 'Establecer PIN'
              : 'Cambiar / quitar PIN'),
          subtitle: const Text(
              'Opcional: exige PIN para volver a mostrar el contenido +18.'),
          onTap: _changePin,
        ),
      ],
    );
  }
}
