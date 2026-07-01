import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';

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
        if (_loading) const LinearProgressIndicator(),
        if (status != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(status),
          ),
      ]),
    );
  }
}
