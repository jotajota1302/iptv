import 'package:shared_preferences/shared_preferences.dart';

/// Claves de SharedPreferences que forman parte de la copia de seguridad:
/// listas guardadas, control parental y preferencias de la interfaz.
const kBackupPrefsKeys = <String>[
  'playlists',
  'active_playlist_id',
  'parental_hide',
  'parental_pin',
  'hardware_accel',
  'deinterlace',
  'image_quality',
  'sort_mode',
  'channel_grid',
  'category_grid',
  'vod_category_grid',
  'channel_tile_size',
  'accent_color',
  'theme_style',
  'auto_refresh',
  'hide_duplicates',
  'pref_audio_lang',
  'pref_sub_lang',
  'start_last_channel',
  'last_channel',
  'fav_groups',
  'epg_reminders',
  'tmdb_key',
  'channel_order',
];

/// Construye el JSON de la copia de seguridad: ajustes (prefs) + flags de
/// usuario de la base de datos (favoritos, ocultos, progreso), versionado.
Map<String, dynamic> buildBackup(
    SharedPreferences prefs, Map<String, dynamic> flags) {
  return {
    'app': 'iptv_player',
    'version': 1,
    'prefs': {
      for (final k in kBackupPrefsKeys)
        if (prefs.get(k) != null) k: prefs.get(k),
    },
    'flags': flags,
  };
}

/// Comprueba que el JSON tiene pinta de copia de seguridad nuestra.
bool isValidBackup(Map<String, dynamic> json) =>
    json['app'] == 'iptv_player' &&
    json['prefs'] is Map &&
    json['flags'] is Map;

/// Restaura los ajustes de la copia en SharedPreferences. Devuelve cuántas
/// claves se han escrito. Ignora claves desconocidas o de tipo inesperado.
Future<int> restorePrefs(
    SharedPreferences prefs, Map<String, dynamic> backup) async {
  final source = backup['prefs'];
  if (source is! Map) return 0;
  var written = 0;
  for (final k in kBackupPrefsKeys) {
    final v = source[k];
    if (v is bool) {
      await prefs.setBool(k, v);
    } else if (v is int) {
      await prefs.setInt(k, v);
    } else if (v is String) {
      await prefs.setString(k, v);
    } else {
      continue;
    }
    written++;
  }
  return written;
}
