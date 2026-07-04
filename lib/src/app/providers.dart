import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'brand.dart';
import 'fav_groups_controller.dart';
import 'playlists_controller.dart';
import 'reminders_controller.dart';
import '../data/app_database.dart';
import '../data/epg_service.dart';
import '../data/m3u_source.dart';
import '../data/playlist_repository.dart';
import '../data/account_service.dart';
import '../data/series_grouper.dart';
import '../data/tmdb_service.dart';
import '../data/update_service.dart';
import '../domain/credit_match.dart';
import '../data/series_info_service.dart';
import '../data/vod_info_service.dart';
import '../data/xmltv_service.dart';
import '../domain/reminder.dart';
import '../domain/adult_filter.dart';
import '../domain/category.dart';
import '../domain/channel_dedupe.dart';
import '../domain/content_type.dart';
import '../domain/media_item.dart';
import '../domain/series_group.dart';
import '../domain/sort_mode.dart';
import 'theme.dart';

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

/// Búsqueda dentro de un tipo concreto (buscadores de Películas y Series).
typedef TypeQuery = ({ContentType type, String query});

final searchByTypeProvider =
    FutureProvider.family<List<MediaItem>, TypeQuery>((ref, k) async {
  final q = k.query.trim();
  if (q.isEmpty) return const [];
  final all = await ref.watch(playlistRepositoryProvider).search(q);
  var items = all.where((i) => i.type == k.type).toList();
  if (ref.watch(parentalHideProvider)) {
    items = items
        .where((i) => !isAdult(i.name) && !isAdult(i.groupTitle))
        .toList();
  }
  // En TV se aplica el mismo filtro de duplicados que en las categorías.
  if (k.type == ContentType.live && ref.watch(hideDuplicatesProvider)) {
    items = dedupeChannels(items);
  }
  return items;
});

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

/// Clave de TMDB: preferencia del usuario > --dart-define=TMDB_API_KEY.
/// Vacía = reparto y fichas de actores desactivados.
final tmdbKeyProvider = StateProvider<String>((ref) =>
    ref.watch(sharedPrefsProvider).getString('tmdb_key') ??
    const String.fromEnvironment('TMDB_API_KEY'));

void setTmdbKey(WidgetRef ref, String value) {
  ref.read(tmdbKeyProvider.notifier).state = value;
  ref.read(sharedPrefsProvider).setString('tmdb_key', value);
}

final tmdbServiceProvider = Provider<TmdbService?>((ref) {
  final key = ref.watch(tmdbKeyProvider).trim();
  return key.isEmpty ? null : TmdbService(credential: key);
});

typedef CastQuery = ({bool isSeries, String title, String? year, String? tmdbId});

/// Reparto con fotos de una película o serie. Best-effort: lista vacía si no
/// hay clave, no hay red o TMDB no encuentra el título.
final castProvider =
    FutureProvider.family<List<TmdbCastMember>, CastQuery>((ref, q) async {
  final svc = ref.watch(tmdbServiceProvider);
  if (svc == null) return const [];
  try {
    final title = cleanMediaTitle(q.title);
    if (title.isEmpty) return const [];
    return q.isSeries
        ? await svc.tvCast(tmdbId: q.tmdbId, title: title, year: q.year)
        : await svc.movieCast(tmdbId: q.tmdbId, title: title, year: q.year);
  } catch (_) {
    return const [];
  }
});

final tmdbPersonProvider =
    FutureProvider.family<TmdbPerson?, int>((ref, id) async {
  final svc = ref.watch(tmdbServiceProvider);
  if (svc == null) return null;
  try {
    return await svc.person(id);
  } catch (_) {
    return null;
  }
});

/// Filmografía de una persona cruzada con el catálogo del usuario: cada
/// crédito lleva el elemento de la lista IPTV que lo reproduce, si existe.
final personCreditsProvider = FutureProvider.family<
    List<({TmdbCredit credit, MediaItem? inCatalog})>, int>((ref, id) async {
  final svc = ref.watch(tmdbServiceProvider);
  if (svc == null) return const [];
  List<TmdbCredit> credits;
  try {
    credits = await svc.personCredits(id);
  } catch (_) {
    return const [];
  }
  final repo = ref.watch(playlistRepositoryProvider);
  final hideAdult = ref.watch(parentalHideProvider);
  final out = <({TmdbCredit credit, MediaItem? inCatalog})>[];
  for (final c in credits.take(80)) {
    MediaItem? match;
    final t = cleanMediaTitle(c.title);
    if (t.length >= 2) {
      try {
        match = pickCatalogMatch(await repo.search(t), c);
      } catch (_) {}
    }
    if (match != null &&
        hideAdult &&
        (isAdult(match.name) || isAdult(match.groupTitle))) {
      match = null;
    }
    out.add((credit: c, inCatalog: match));
  }
  return out;
});

/// Versión instalada (del ejecutable compilado; única fuente: pubspec.yaml).
final appVersionProvider = FutureProvider<String>(
    (ref) async => (await PackageInfo.fromPlatform()).version);

final updateServiceProvider =
    Provider((ref) => UpdateService(feedUrl: Brand.updateFeed));

/// Versión nueva disponible, o null (al día, feed desactivado o sin red).
/// Silencioso: los errores de red no se propagan.
final updateInfoProvider = FutureProvider<UpdateInfo?>((ref) async {
  try {
    final current = await ref.watch(appVersionProvider.future);
    return await ref.watch(updateServiceProvider).check(current);
  } catch (_) {
    return null;
  }
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

/// Índice del color de acento elegido (ver [kAccentChoices]). Persistido.
final accentIndexProvider = StateProvider<int>((ref) =>
    (ref.watch(sharedPrefsProvider).getInt('accent_color') ?? 0)
        .clamp(0, kAccentChoices.length - 1));

/// Cambia el acento: actualiza el color global y reconstruye el tema.
void setAccentIndex(WidgetRef ref, int index) {
  kAccent = kAccentChoices[index].$2;
  ref.read(accentIndexProvider.notifier).state = index;
  ref.read(sharedPrefsProvider).setInt('accent_color', index);
}

/// Estilo global de la interfaz (índice en kThemeStyles). Persistido.
final themeStyleProvider = StateProvider<int>((ref) =>
    (ref.watch(sharedPrefsProvider).getInt('theme_style') ?? 0)
        .clamp(0, kThemeStyles.length - 1));

/// Cambia el estilo: actualiza la paleta global y reconstruye el tema.
void setThemeStyle(WidgetRef ref, int index) {
  applyThemeStyle(index);
  ref.read(themeStyleProvider.notifier).state = index;
  ref.read(sharedPrefsProvider).setInt('theme_style', index);
}

/// Recargar la lista activa automáticamente al arrancar la app. Persistido.
final autoRefreshProvider = StateProvider<bool>(
    (ref) => ref.watch(sharedPrefsProvider).getBool('auto_refresh') ?? true);

void setAutoRefresh(WidgetRef ref, bool value) {
  ref.read(autoRefreshProvider.notifier).state = value;
  ref.read(sharedPrefsProvider).setBool('auto_refresh', value);
}

/// Idioma de audio preferido ('' = automático). El reproductor elige la pista
/// de este idioma al abrir el contenido, si existe. Persistido.
final preferredAudioLangProvider = StateProvider<String>(
    (ref) => ref.watch(sharedPrefsProvider).getString('pref_audio_lang') ?? '');

void setPreferredAudioLang(WidgetRef ref, String value) {
  ref.read(preferredAudioLangProvider.notifier).state = value;
  ref.read(sharedPrefsProvider).setString('pref_audio_lang', value);
}

/// Subtítulos preferidos: '' = automático (no tocar), 'off' = desactivados
/// siempre, o un código de idioma. Persistido.
final preferredSubLangProvider = StateProvider<String>(
    (ref) => ref.watch(sharedPrefsProvider).getString('pref_sub_lang') ?? '');

void setPreferredSubLang(WidgetRef ref, String value) {
  ref.read(preferredSubLangProvider.notifier).state = value;
  ref.read(sharedPrefsProvider).setString('pref_sub_lang', value);
}

/// Arrancar la app directamente en el último canal visto. Persistido.
final startLastChannelProvider = StateProvider<bool>((ref) =>
    ref.watch(sharedPrefsProvider).getBool('start_last_channel') ?? false);

void setStartLastChannel(WidgetRef ref, bool value) {
  ref.read(startLastChannelProvider.notifier).state = value;
  ref.read(sharedPrefsProvider).setBool('start_last_channel', value);
}

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

/// Ocultar canales duplicados (mismo nombre) dentro de una categoría.
/// Muchas listas repiten el mismo canal varias veces (feeds de respaldo).
/// Persistido; por defecto activado.
final hideDuplicatesProvider = StateProvider<bool>((ref) =>
    ref.watch(sharedPrefsProvider).getBool('hide_duplicates') ?? true);

void setHideDuplicates(WidgetRef ref, bool value) {
  ref.read(hideDuplicatesProvider.notifier).state = value;
  ref.read(sharedPrefsProvider).setBool('hide_duplicates', value);
}

final liveByCategoryProvider =
    FutureProvider.family<List<MediaItem>, String>((ref, group) async {
  final items =
      await ref.watch(playlistRepositoryProvider).liveByCategory(group);
  return ref.watch(hideDuplicatesProvider) ? dedupeChannels(items) : items;
});

/// Primeros logos/carátulas de cada categoría de un tipo (collages).
final categoryLogosProvider =
    FutureProvider.family<Map<String, List<String>>, ContentType>((ref, type) {
  return ref.watch(playlistRepositoryProvider).logosByCategory(type);
});

/// Vista cuadrícula vs lista para las categorías de Películas y Series.
final vodCategoryGridProvider = StateProvider<bool>((ref) =>
    ref.watch(sharedPrefsProvider).getBool('vod_category_grid') ?? true);

void setVodCategoryGrid(WidgetRef ref, bool value) {
  ref.read(vodCategoryGridProvider.notifier).state = value;
  ref.read(sharedPrefsProvider).setBool('vod_category_grid', value);
}

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

/// Servicio de fichas de series (get_series / get_series_info).
final seriesInfoServiceProvider =
    Provider<SeriesInfoService>((_) => SeriesInfoService());

/// Clave de ficha de serie: URL de un episodio (credenciales) + título.
typedef SeriesInfoKey = ({String streamUrl, String title});

/// Ficha de una serie: sinopsis, rating e imágenes/títulos de episodios.
/// Best-effort: null si la API no responde o la serie no casa en el catálogo.
final seriesInfoProvider =
    FutureProvider.family<SeriesApiInfo?, SeriesInfoKey>((ref, k) {
  return ref
      .watch(seriesInfoServiceProvider)
      .fetchForSeries(k.streamUrl, k.title);
});

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

/// Servicio del EPG completo XMLTV (una descarga por sesión, cacheada).
final xmltvServiceProvider = Provider<XmltvService>((_) => XmltvService());

/// Guía XMLTV completa del servidor de la lista activa. Best-effort: null si
/// el servidor no la expone o no hay lista.
final xmltvGuideProvider = FutureProvider<XmltvGuide?>((ref) async {
  final active = ref.watch(playlistsProvider).active?.url ??
      await ref.watch(loadedListUrlProvider.future);
  if (active == null) return null;
  return ref.watch(xmltvServiceProvider).fetchFromListUrl(active);
});

/// Recordatorios de programas (persistidos).
final remindersProvider =
    StateNotifierProvider<RemindersNotifier, List<Reminder>>(
        (ref) => RemindersNotifier(ref.watch(sharedPrefsProvider)));

/// Grupos de favoritos personalizados (persistidos).
final favGroupsProvider =
    StateNotifierProvider<FavGroupsNotifier, Map<String, List<String>>>(
        (ref) => FavGroupsNotifier(ref.watch(sharedPrefsProvider)));

/// Historial de reproducción (más recientes primero).
final historyProvider = FutureProvider<List<MediaItem>>((ref) {
  return ref.watch(playlistRepositoryProvider).history();
});

/// Qué emiten ahora mismo los canales favoritos (máx. 12), para el rail
/// "Ahora en tus canales" del Inicio. Best-effort: canales sin EPG se omiten.
final nowOnFavoritesProvider =
    FutureProvider<List<({MediaItem channel, EpgEntry entry})>>((ref) async {
  final favs = (await ref.watch(favoritesProvider.future))
      .where((i) => i.type == ContentType.live)
      .take(12)
      .toList();
  if (favs.isEmpty) return const [];
  final epg = ref.watch(epgServiceProvider);
  final now = DateTime.now();
  final results = await Future.wait(favs.map((c) async {
    final entries = await epg.shortEpg(c.streamUrl);
    for (final e in entries) {
      if (!now.isBefore(e.start) && now.isBefore(e.end)) {
        return (channel: c, entry: e);
      }
    }
    return null;
  }));
  return [for (final r in results) ?r];
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


/// Orden personalizado de canales por categoría (drag & drop): nombre de la
/// categoría -> lista de ids en el orden elegido. Persistido.
final channelOrderProvider =
    StateProvider<Map<String, List<String>>>((ref) {
  final raw = ref.watch(sharedPrefsProvider).getString('channel_order');
  if (raw == null || raw.isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final e in decoded.entries)
        if (e.value is List)
          e.key: [for (final id in e.value as List) '$id'],
    };
  } catch (_) {
    return const {};
  }
});

void setChannelOrder(WidgetRef ref, String category, List<String> ids) {
  final next = {...ref.read(channelOrderProvider), category: ids};
  ref.read(channelOrderProvider.notifier).state = next;
  ref.read(sharedPrefsProvider).setString('channel_order', jsonEncode(next));
}

/// Tamaño de los tiles de la cuadrícula de canales (0=compacto, 1=medio,
/// 2=grande). Persistido.
final channelTileSizeProvider = StateProvider<int>((ref) =>
    (ref.watch(sharedPrefsProvider).getInt('channel_tile_size') ?? 1)
        .clamp(0, 2));

void setChannelTileSize(WidgetRef ref, int value) {
  ref.read(channelTileSizeProvider.notifier).state = value;
  ref.read(sharedPrefsProvider).setInt('channel_tile_size', value);
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
