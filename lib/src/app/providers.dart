import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'playlists_controller.dart';
import '../data/app_database.dart';
import '../data/epg_service.dart';
import '../data/m3u_source.dart';
import '../data/playlist_repository.dart';
import '../data/account_service.dart';
import '../data/series_grouper.dart';
import '../data/vod_info_service.dart';
import '../domain/adult_filter.dart';
import '../domain/category.dart';
import '../domain/content_type.dart';
import '../domain/media_item.dart';
import '../domain/series_group.dart';
import '../domain/sort_mode.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return PlaylistRepository(M3uSource(DioHttpClient()), db);
});

/// Oculta categorías/contenido para adultos (+18). Persistido, por defecto ON.
final parentalHideProvider = StateProvider<bool>(
    (ref) => ref.watch(sharedPrefsProvider).getBool('parental_hide') ?? true);

/// PIN opcional para desactivar el control parental ('' = sin PIN).
final parentalPinProvider = StateProvider<String>(
    (ref) => ref.watch(sharedPrefsProvider).getString('parental_pin') ?? '');

void setParentalHide(WidgetRef ref, bool value) {
  ref.read(parentalHideProvider.notifier).state = value;
  ref.read(sharedPrefsProvider).setBool('parental_hide', value);
}

void setParentalPin(WidgetRef ref, String value) {
  ref.read(parentalPinProvider.notifier).state = value;
  ref.read(sharedPrefsProvider).setString('parental_pin', value);
}

/// Filtra categorías para adultos si el control parental está activo.
List<Category> _filterAdultCats(Ref ref, List<Category> cats) {
  if (!ref.watch(parentalHideProvider)) return cats;
  return cats.where((c) => !isAdult(c.name)).toList();
}

final liveCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  return _filterAdultCats(
      ref, await ref.watch(playlistRepositoryProvider).liveCategories());
});

final favoritesProvider = FutureProvider<List<MediaItem>>((ref) {
  return ref.watch(playlistRepositoryProvider).favorites();
});

/// Índice de la pestaña activa del AppShell (para navegar desde el Inicio).
final selectedTabProvider = StateProvider<int>((_) => 0);

final searchQueryProvider = StateProvider<String>((_) => '');

/// Filtro de tipo en la búsqueda (null = todos).
final searchFilterProvider = StateProvider<ContentType?>((_) => null);

final searchResultsProvider = FutureProvider<List<MediaItem>>((ref) async {
  final q = ref.watch(searchQueryProvider);
  if (q.trim().isEmpty) return <MediaItem>[];
  final results = await ref.watch(playlistRepositoryProvider).search(q);
  if (!ref.watch(parentalHideProvider)) return results;
  return results
      .where((i) => !isAdult(i.name) && !isAdult(i.groupTitle))
      .toList();
});

final loadStateProvider = StateProvider<String?>((_) => null);

/// Listas IPTV guardadas y cuál está activa (persistidas en prefs).
final playlistsProvider =
    StateNotifierProvider<PlaylistsNotifier, PlaylistsState>((ref) {
  return PlaylistsNotifier(ref.watch(sharedPrefsProvider));
});

/// Estado de cuenta Xtream (activa, caducidad, conexiones) de una lista.
final accountServiceProvider = Provider<AccountService>((_) => AccountService());

final accountInfoProvider =
    FutureProvider.family<AccountInfo?, String>((ref, listUrl) {
  return ref.watch(accountServiceProvider).fetch(listUrl);
});

/// URL de la lista actualmente cargada, reconstruida desde la BD (para
/// recuperar listas cargadas antes de la gestión de listas).
final loadedListUrlProvider = FutureProvider<String?>((ref) async {
  final sample =
      await ref.watch(playlistRepositoryProvider).sampleStreamUrl();
  if (sample == null) return null;
  return deriveListUrlFromStream(sample);
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

// --- VOD: películas y series ---

final movieCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  return _filterAdultCats(
      ref, await ref.watch(playlistRepositoryProvider).movieCategories());
});

final moviesByCategoryProvider =
    FutureProvider.family<List<MediaItem>, String>((ref, group) {
  return ref.watch(playlistRepositoryProvider).moviesByCategory(group);
});

final seriesCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  return _filterAdultCats(
      ref, await ref.watch(playlistRepositoryProvider).seriesCategories());
});

/// Series de una categoría ya agrupadas (Serie → Temporadas → Episodios).
final seriesGroupsByCategoryProvider =
    FutureProvider.family<List<SeriesGroup>, String>((ref, group) async {
  final items =
      await ref.watch(playlistRepositoryProvider).seriesByCategory(group);
  return groupSeries(items);
});

/// Servicio de guía de programación (EPG) via API Xtream.
final epgServiceProvider = Provider<EpgService>((_) => EpgService());

/// Servicio de fichas de películas (metadatos) via API Xtream.
final vodInfoServiceProvider = Provider<VodInfoService>((_) => VodInfoService());

/// Ficha (sinopsis, año, valoración...) de la película cuyo streamUrl se pasa.
final vodInfoProvider =
    FutureProvider.family<VodInfo?, String>((ref, streamUrl) {
  return ref.watch(vodInfoServiceProvider).fetch(streamUrl);
});

/// Programación corta (actual y siguientes) del canal cuyo streamUrl se pasa.
/// Las credenciales se derivan de la propia URL del stream. Best-effort.
final previewEpgProvider =
    FutureProvider.family<List<EpgEntry>, String>((ref, streamUrl) {
  return ref.watch(epgServiceProvider).shortEpg(streamUrl);
});

/// Guía completa (todo el EPG disponible) del canal. Best-effort.
final channelGuideProvider =
    FutureProvider.family<List<EpgEntry>, String>((ref, streamUrl) {
  return ref.watch(epgServiceProvider).fullEpg(streamUrl);
});

/// Clave para gestión por categoría: tipo de contenido + nombre de la categoría.
typedef ManageKey = ({ContentType type, String group});

/// Categorías de un tipo para la pantalla de gestión (incluye ocultos).
final manageCategoriesByTypeProvider =
    FutureProvider.family<List<Category>, ContentType>((ref, type) {
  return ref.watch(playlistRepositoryProvider).manageCategoriesOf(type);
});

/// Todos los items de una categoría (con su estado) para gestión, por tipo.
final manageByCategoryProvider =
    FutureProvider.family<List<MediaItem>, ManageKey>((ref, k) {
  return ref.watch(playlistRepositoryProvider).manageByCategory(k.type, k.group);
});

/// Nº de items ocultos/borrados por categoría de un tipo (señalizar gestión).
final hiddenCountsByTypeProvider =
    FutureProvider.family<Map<String, int>, ContentType>((ref, type) {
  return ref.watch(playlistRepositoryProvider).hiddenCountsOf(type);
});

/// Películas/series empezadas y sin terminar ("Continuar viendo").
final continueWatchingProvider = FutureProvider<List<MediaItem>>((ref) {
  return ref.watch(playlistRepositoryProvider).continueWatching();
});

/// Novedades de películas (para el Inicio). Respeta el control parental.
final recentMoviesProvider = FutureProvider<List<MediaItem>>((ref) async {
  final list = await ref.watch(playlistRepositoryProvider).recentMovies();
  if (!ref.watch(parentalHideProvider)) return list;
  return list
      .where((i) => !isAdult(i.name) && !isAdult(i.groupTitle))
      .toList();
});

/// Novedades de series agrupadas (para el Inicio). Respeta el control parental.
final recentSeriesProvider = FutureProvider<List<SeriesGroup>>((ref) async {
  var list = await ref.watch(playlistRepositoryProvider).recentSeriesItems();
  if (ref.watch(parentalHideProvider)) {
    list = list
        .where((i) => !isAdult(i.name) && !isAdult(i.groupTitle))
        .toList();
  }
  return groupSeries(list);
});

/// Modo de ordenación del contenido dentro de una categoría. Persistido.
final sortModeProvider = StateProvider<SortMode>((ref) {
  final i = ref.watch(sharedPrefsProvider).getInt('sort_mode') ?? 0;
  return SortMode.values[i.clamp(0, SortMode.values.length - 1)];
});

void setSortMode(WidgetRef ref, SortMode mode) {
  ref.read(sortModeProvider.notifier).state = mode;
  ref.read(sharedPrefsProvider).setInt('sort_mode', mode.index);
}

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
