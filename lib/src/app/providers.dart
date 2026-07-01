import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'playlists_controller.dart';
import '../data/app_database.dart';
import '../data/m3u_source.dart';
import '../data/playlist_repository.dart';
import '../domain/category.dart';
import '../domain/media_item.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return PlaylistRepository(M3uSource(DioHttpClient()), db);
});

final liveCategoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(playlistRepositoryProvider).liveCategories();
});

final favoritesProvider = FutureProvider<List<MediaItem>>((ref) {
  return ref.watch(playlistRepositoryProvider).favorites();
});

final searchQueryProvider = StateProvider<String>((_) => '');

final searchResultsProvider = FutureProvider<List<MediaItem>>((ref) {
  final q = ref.watch(searchQueryProvider);
  if (q.trim().isEmpty) return Future.value(<MediaItem>[]);
  return ref.watch(playlistRepositoryProvider).search(q);
});

final loadStateProvider = StateProvider<String?>((_) => null);

/// Listas IPTV guardadas y cuál está activa (persistidas en prefs).
final playlistsProvider =
    StateNotifierProvider<PlaylistsNotifier, PlaylistsState>((ref) {
  return PlaylistsNotifier(ref.watch(sharedPrefsProvider));
});

/// Instancia de SharedPreferences. Se inyecta en `main()` con override.
final sharedPrefsProvider = Provider<SharedPreferences>(
    (_) => throw UnimplementedError('sharedPrefsProvider debe sobrescribirse'));

const _kHwAccel = 'hardware_accel';
const _kDeinterlace = 'deinterlace';

/// Aceleración por hardware del vídeo (GPU). Si hay artefactos (triángulos,
/// bloques) en HD/4K, desactivarla fuerza decodificación por software.
/// Valor inicial persistido en SharedPreferences.
final hardwareAccelProvider = StateProvider<bool>(
    (ref) => ref.watch(sharedPrefsProvider).getBool(_kHwAccel) ?? true);

/// Desentrelazado (deinterlace). La TV en directo suele emitir entrelazada
/// (1080i/576i) y sin esto se ven "líneas peine" en bordes y movimiento.
/// Valor inicial persistido en SharedPreferences.
final deinterlaceProvider = StateProvider<bool>(
    (ref) => ref.watch(sharedPrefsProvider).getBool(_kDeinterlace) ?? true);

/// Persiste el valor de aceleración por hardware y actualiza el estado.
void setHardwareAccel(WidgetRef ref, bool value) {
  ref.read(hardwareAccelProvider.notifier).state = value;
  ref.read(sharedPrefsProvider).setBool(_kHwAccel, value);
}

/// Persiste el valor de desentrelazado y actualiza el estado.
void setDeinterlaceSetting(WidgetRef ref, bool value) {
  ref.read(deinterlaceProvider.notifier).state = value;
  ref.read(sharedPrefsProvider).setBool(_kDeinterlace, value);
}

final liveByCategoryProvider =
    FutureProvider.family<List<MediaItem>, String>((ref, group) {
  return ref.watch(playlistRepositoryProvider).liveByCategory(group);
});

/// Categorías en directo para la pantalla de gestión (incluye ocultos).
final manageCategoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(playlistRepositoryProvider).manageCategories();
});

/// Todos los canales de una categoría (con su estado) para gestión.
final manageLiveByCategoryProvider =
    FutureProvider.family<List<MediaItem>, String>((ref, group) {
  return ref.watch(playlistRepositoryProvider).manageLiveByCategory(group);
});

/// Nº de canales ocultos/borrados por categoría (para señalizar en gestión).
final hiddenCountsProvider = FutureProvider<Map<String, int>>((ref) {
  return ref.watch(playlistRepositoryProvider).liveHiddenCounts();
});

/// Vista en cuadrícula (iconos) vs lista en la pantalla de canales. Persistido.
final channelGridProvider = StateProvider<bool>(
    (ref) => ref.watch(sharedPrefsProvider).getBool('channel_grid') ?? true);

void setChannelGrid(WidgetRef ref, bool value) {
  ref.read(channelGridProvider.notifier).state = value;
  ref.read(sharedPrefsProvider).setBool('channel_grid', value);
}

/// Vista en cuadrícula vs lista en la pantalla de categorías de TV. Persistido.
final categoryGridProvider = StateProvider<bool>(
    (ref) => ref.watch(sharedPrefsProvider).getBool('category_grid') ?? true);

void setCategoryGrid(WidgetRef ref, bool value) {
  ref.read(categoryGridProvider.notifier).state = value;
  ref.read(sharedPrefsProvider).setBool('category_grid', value);
}
