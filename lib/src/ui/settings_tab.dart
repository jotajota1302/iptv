import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app/brand.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../data/backup_service.dart';
import '../data/update_service.dart';
import '../domain/xtream_login.dart';
import '../domain/content_type.dart';
import '../domain/lang_match.dart';
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
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _nameCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  /// Modo proveedor (white-label): inicia sesión con usuario/contraseña
  /// contra el servidor fijo de la marca; la URL nunca se muestra.
  Future<void> _login() async {
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text;
    if (user.isEmpty || pass.isEmpty) return;
    final url = buildXtreamListUrl(Brand.server, user, pass);
    final playlists = ref.read(playlistsProvider).playlists;
    final existing = playlists.where((p) => p.name == Brand.name).toList();
    if (existing.isNotEmpty) {
      ref
          .read(playlistsProvider.notifier)
          .update(existing.first.id, url: url);
      ref.read(playlistsProvider.notifier).setActive(existing.first.id);
    } else {
      ref.read(playlistsProvider.notifier).add(SavedPlaylist(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            name: Brand.name,
            url: url,
          ));
    }
    _passCtrl.clear();
    await _run(() => ref.read(playlistRepositoryProvider).loadFromUrl(url));
  }

  /// Comprobación manual de actualizaciones, con resultado siempre visible
  /// (a diferencia del chequeo silencioso del arranque).
  Future<void> _checkUpdates() async {
    final messenger = ScaffoldMessenger.of(context);
    UpdateInfo? info;
    try {
      final current = await ref.read(appVersionProvider.future);
      info = await ref.read(updateServiceProvider).check(current);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text('No se pudo comprobar (¿sin conexión?)')));
      return;
    }
    if (!mounted) return;
    if (info == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Estás en la última versión')));
      return;
    }
    final update = info;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Versión ${update.version} disponible'),
        content: update.notes == null || update.notes!.trim().isEmpty
            ? const Text('Hay una versión más nueva lista para descargar.')
            : SingleChildScrollView(
                child: Text(update.notes!,
                    style: const TextStyle(height: 1.4))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Más tarde')),
          FilledButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Descargar'),
            onPressed: () {
              launchUrl(Uri.parse(update.url),
                  mode: LaunchMode.externalApplication);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
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

  /// Edita nombre y URL de una lista (p. ej. al cambiar la contraseña). Si
  /// cambia la URL y es la lista activa, la recarga.
  Future<void> _editPlaylist(SavedPlaylist pl) async {
    final nameC = TextEditingController(text: pl.name);
    final urlC = TextEditingController(text: pl.url);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar lista'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlC,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(labelText: 'URL de la lista'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final newName = nameC.text.trim().isEmpty ? pl.name : nameC.text.trim();
    final newUrl = urlC.text.trim();
    if (newUrl.isEmpty) return;
    ref.read(playlistsProvider.notifier).update(pl.id, name: newName, url: newUrl);
    // Si cambió la URL y es la activa, recargar el contenido con la nueva.
    final isActive = ref.read(playlistsProvider).activeId == pl.id;
    if (newUrl != pl.url && isActive) {
      await _run(() => ref.read(playlistRepositoryProvider).loadFromUrl(newUrl));
      ref.invalidate(accountInfoProvider(newUrl));
    }
  }

  /// Registra como "Mi lista" la lista que ya está cargada en la BD pero que no
  /// se guardó (cargada antes de existir la gestión de listas).
  void _recover(String url) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    ref
        .read(playlistsProvider.notifier)
        .add(SavedPlaylist(id: id, name: 'Mi lista', url: url));
  }

  /// Tarjeta que ofrece recuperar la lista ya cargada (si la hay).
  Widget _recoverCard() {
    final loaded = ref.watch(loadedListUrlProvider).value;
    if (loaded == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Aún no has guardado ninguna lista. Añade una abajo.',
            style: TextStyle(color: Colors.white54)),
      );
    }
    return Card(
      child: ListTile(
        leading: const Icon(Icons.download_done),
        title: const Text('Recuperar lista cargada'),
        subtitle: Text(loaded, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: FilledButton(
          onPressed: () => _recover(loaded),
          child: const Text('Guardar'),
        ),
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Exporta ajustes + favoritos/progreso a un JSON elegido por el usuario.
  Future<void> _exportBackup() async {
    try {
      final flags =
          await ref.read(playlistRepositoryProvider).exportUserFlags();
      final backup = buildBackup(ref.read(sharedPrefsProvider), flags);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Guardar copia de seguridad',
        fileName: 'iptv_backup.json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (path == null) return;
      await File(path).writeAsString(
          const JsonEncoder.withIndent('  ').convert(backup));
      _toast('Copia guardada en $path');
    } catch (e) {
      _toast('No se pudo exportar: $e');
    }
  }

  /// Importa un JSON de copia: restaura prefs y flags, y refresca la app.
  Future<void> _importBackup() async {
    try {
      final res = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: const ['json']);
      final path = res?.files.single.path;
      if (path == null) return;
      final json = jsonDecode(await File(path).readAsString());
      if (json is! Map<String, dynamic> || !isValidBackup(json)) {
        _toast('Ese archivo no es una copia de seguridad válida');
        return;
      }
      final prefs = ref.read(sharedPrefsProvider);
      await restorePrefs(prefs, json);
      final applied = await ref
          .read(playlistRepositoryProvider)
          .importUserFlags((json['flags'] as Map).cast<String, dynamic>());
      // Refresca acento y providers que se construyen desde prefs o BD.
      kAccent = kAccentChoices[(prefs.getInt('accent_color') ?? 0)
              .clamp(0, kAccentChoices.length - 1)]
          .$2;
      ref.invalidate(accentIndexProvider);
      ref.invalidate(playlistsProvider);
      ref.invalidate(parentalHideProvider);
      ref.invalidate(parentalPinProvider);
      ref.invalidate(hardwareAccelProvider);
      ref.invalidate(deinterlaceProvider);
      ref.invalidate(sortModeProvider);
      ref.invalidate(channelGridProvider);
      ref.invalidate(categoryGridProvider);
      ref.invalidate(channelTileSizeProvider);
      ref.invalidate(autoRefreshProvider);
      ref.invalidate(favoritesProvider);
      ref.invalidate(continueWatchingProvider);
      ref.invalidate(liveCategoriesProvider);
      ref.invalidate(movieCategoriesProvider);
      ref.invalidate(seriesCategoriesProvider);
      ref.invalidate(nowOnFavoritesProvider);
      _toast('Copia restaurada ($applied elementos actualizados)');
    } catch (e) {
      _toast('No se pudo importar: $e');
    }
  }

  String _langLabel(String code) {
    if (code == 'off') return 'Desactivados siempre';
    for (final o in kPreferredLangs) {
      if (o.$1 == code) return o.$2;
    }
    return 'Automático';
  }

  /// Diálogo para elegir un idioma preferido (audio o subtítulos).
  Future<void> _pickLang({
    required String title,
    required String current,
    required void Function(String) onPicked,
    bool withOff = false,
  }) async {
    final options = [
      ...kPreferredLangs,
      if (withOff) ('off', 'Desactivados siempre'),
    ];
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(title),
        children: [
          for (final o in options)
            ListTile(
              leading: Icon(o.$1 == current
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
              title: Text(o.$2),
              onTap: () => Navigator.pop(ctx, o.$1),
            ),
        ],
      ),
    );
    if (v != null) onPicked(v);
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
        const Text('Mis listas', style: TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        if (playlists.playlists.isEmpty) _recoverCard(),
        for (final pl in playlists.playlists)
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    pl.id == playlists.activeId
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: pl.id == playlists.activeId
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  title: Text(pl.name),
                  // En modo proveedor la URL (con credenciales) no se enseña.
                  subtitle: Brand.isWhiteLabel
                      ? null
                      : Text(pl.url,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: PopupMenuButton<String>(
                    enabled: !_loading,
                    onSelected: (a) {
                      if (a == 'editar') {
                        _editPlaylist(pl);
                      } else if (a == 'recargar') {
                        _activate(pl);
                      } else if (a == 'eliminar') {
                        ref.read(playlistsProvider.notifier).remove(pl.id);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'editar',
                          child: ListTile(
                              leading: Icon(Icons.edit),
                              title: Text('Editar'))),
                      PopupMenuItem(
                          value: 'recargar',
                          child: ListTile(
                              leading: Icon(Icons.refresh),
                              title: Text('Recargar'))),
                      PopupMenuItem(
                          value: 'eliminar',
                          child: ListTile(
                              leading: Icon(Icons.delete_outline),
                              title: Text('Eliminar'))),
                    ],
                  ),
                  onTap: _loading ? null : () => _activate(pl),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _AccountStatus(pl.url),
                ),
              ],
            ),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Actualizar lista al iniciar'),
          subtitle: const Text(
              'Recarga la lista activa en segundo plano al abrir la app '
              '(novedades y canales nuevos sin hacer nada).'),
          value: ref.watch(autoRefreshProvider),
          onChanged: (v) => setAutoRefresh(ref, v),
        ),
        const SizedBox(height: 20),
        const Divider(),

        // --- Añadir lista (marca propia) o login (modo proveedor) ---
        if (Brand.isWhiteLabel) ...[
          const Text('Iniciar sesión', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          const Text('Introduce las credenciales de tu suscripción.',
              style: TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 12),
          TextField(
            controller: _userCtrl,
            decoration: const InputDecoration(
              labelText: 'Usuario',
              prefixIcon: Icon(Icons.person_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtrl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _login,
            icon: const Icon(Icons.login),
            label: const Text('Entrar'),
          ),
        ] else ...[
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
                      if (path != null) {
                        await _run(() => repo.loadFromFile(path));
                      }
                    },
              child: const Text('Elegir archivo'),
            ),
          ]),
        ],
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ocultar canales duplicados'),
          subtitle: const Text(
              'Muchas listas repiten el mismo canal varias veces (feeds de '
              'respaldo). Muestra solo uno por nombre; desactívalo si un '
              'canal no funciona y quieres probar sus copias.'),
          value: ref.watch(hideDuplicatesProvider),
          onChanged: (v) => setHideDuplicates(ref, v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Arrancar en el último canal'),
          subtitle: const Text(
              'Al abrir la app, reproduce directamente el último canal de TV '
              'que estabas viendo.'),
          value: ref.watch(startLastChannelProvider),
          onChanged: (v) => setStartLastChannel(ref, v),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.multitrack_audio),
          title: const Text('Idioma de audio preferido'),
          subtitle: Text(_langLabel(ref.watch(preferredAudioLangProvider))),
          onTap: () => _pickLang(
            title: 'Idioma de audio preferido',
            current: ref.read(preferredAudioLangProvider),
            onPicked: (v) => setPreferredAudioLang(ref, v),
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.subtitles_outlined),
          title: const Text('Subtítulos preferidos'),
          subtitle: Text(_langLabel(ref.watch(preferredSubLangProvider))),
          onTap: () => _pickLang(
            title: 'Subtítulos preferidos',
            current: ref.read(preferredSubLangProvider),
            withOff: true,
            onPicked: (v) => setPreferredSubLang(ref, v),
          ),
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

        const SizedBox(height: 24),
        const Divider(),
        const Text('Apariencia', style: TextStyle(fontSize: 20)),
        const SizedBox(height: 6),
        const Text('Color de acento',
            style: TextStyle(fontSize: 13, color: Colors.white54)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          children: [
            for (var i = 0; i < kAccentChoices.length; i++)
              Tooltip(
                message: kAccentChoices[i].$1,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setAccentIndex(ref, i),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: kAccentChoices[i].$2,
                      shape: BoxShape.circle,
                      border: ref.watch(accentIndexProvider) == i
                          ? Border.all(color: Colors.white, width: 2.5)
                          : null,
                    ),
                    child: ref.watch(accentIndexProvider) == i
                        ? const Icon(Icons.check,
                            size: 18, color: Colors.white)
                        : null,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 24),
        const Divider(),
        const Text('Copia de seguridad', style: TextStyle(fontSize: 20)),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.upload_file),
          title: const Text('Exportar'),
          subtitle: const Text(
              'Guarda listas, favoritos, progreso y ajustes en un archivo.'),
          onTap: _exportBackup,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.download),
          title: const Text('Importar'),
          subtitle: const Text(
              'Restaura una copia exportada antes (aquí o en otro equipo).'),
          onTap: _importBackup,
        ),

        const SizedBox(height: 24),
        const Divider(),
        const Text('Acerca de', style: TextStyle(fontSize: 20)),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.live_tv),
          title: const Text(Brand.name),
          subtitle: Text(
              'Versión ${ref.watch(appVersionProvider).value ?? '…'}'
              ' · Flutter + media_kit'),
        ),
        if (Brand.updateFeed.isNotEmpty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.system_update_alt),
            title: const Text('Buscar actualizaciones'),
            subtitle: const Text('Comprueba si hay una versión más nueva.'),
            onTap: _checkUpdates,
          ),
        if (!Brand.isWhiteLabel)
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.code),
            title: Text('Código fuente'),
            subtitle: SelectableText('github.com/jotajota1302/iptv'),
          ),
      ],
    );
  }
}

/// Muestra el estado de la cuenta Xtream de una lista (activa, caducidad,
/// conexiones). Best-effort: no muestra nada si el proveedor no responde.
class _AccountStatus extends ConsumerWidget {
  final String url;
  const _AccountStatus(this.url);

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: TextStyle(fontSize: 11, color: color)),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(accountInfoProvider(url));
    if (async.isLoading) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text('Comprobando estado…',
            style: TextStyle(fontSize: 11, color: Colors.white38)),
      );
    }
    final info = async.value;
    if (info == null) return const SizedBox.shrink();
    const green = Color(0xFF43D17A);
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          _chip(info.isActive ? '● Activa' : '● ${info.status}',
              info.isActive ? green : Colors.redAccent),
          if (info.expiry != null)
            _chip('Caduca ${_fmtDate(info.expiry!)}', Colors.white70),
          if (info.maxConnections > 0)
            _chip('${info.activeConnections}/${info.maxConnections} conexiones',
                Colors.white70),
          if (info.isTrial) _chip('Prueba', Colors.orangeAccent),
        ],
      ),
    );
  }
}
