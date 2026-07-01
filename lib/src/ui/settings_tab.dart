import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import 'management_screen.dart';

class SettingsTab extends ConsumerStatefulWidget {
  const SettingsTab({super.key});
  @override
  ConsumerState<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<SettingsTab> {
  final _urlCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
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

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(playlistRepositoryProvider);
    final status = ref.watch(loadStateProvider);
    final hwAccel = ref.watch(hardwareAccelProvider);
    final deinterlace = ref.watch(deinterlaceProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Añadir lista M3U', style: TextStyle(fontSize: 20)),
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
            onPressed: _loading
                ? null
                : () => _run(() => repo.loadFromUrl(_urlCtrl.text.trim())),
            child: const Text('Cargar URL'),
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
      ]),
    );
  }
}
