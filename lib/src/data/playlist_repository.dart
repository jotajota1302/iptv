import 'package:flutter/foundation.dart' show compute;
import '../domain/category.dart';
import '../domain/content_type.dart';
import '../domain/media_item.dart';
import 'app_database.dart';
import 'content_classifier.dart';
import 'm3u_parser.dart';
import 'm3u_source.dart';

List<MediaItem> parseAndClassify(String content) =>
    classifyAll(parseM3u(content));

class PlaylistRepository {
  final M3uSource _source;
  final AppDatabase _db;
  PlaylistRepository(this._source, this._db);

  Future<int> loadFromUrl(String url) async {
    final text = await _source.fetchFromUrl(url);
    return _ingest(text);
  }

  Future<int> loadFromFile(String path) async {
    final text = await _source.readFromFile(path);
    return _ingest(text);
  }

  Future<int> _ingest(String text) async {
    final items = await compute(parseAndClassify, text);
    await _db.replaceItems(items);
    return items.length;
  }

  Future<List<Category>> liveCategories() =>
      _db.categoriesByType(ContentType.live);

  Future<List<MediaItem>> liveByCategory(String group) async {
    final all = await _db.itemsByType(ContentType.live);
    return all
        .where((i) => (i.groupTitle ?? 'Sin categoria') == group)
        .toList();
  }

  Future<List<MediaItem>> search(String q) => _db.search(q);

  Future<List<MediaItem>> favorites() => _db.favorites();

  Future<void> toggleFavorite(MediaItem item) =>
      _db.setFavorite(item.id, !item.isFavorite);

  // --- Gestión de canales ---

  Future<void> hideItem(MediaItem item) => _db.setHidden(item.id, true);

  Future<void> deleteItem(MediaItem item) => _db.setDeleted(item.id, true);

  Future<void> restoreItem(MediaItem item) => _db.restore(item.id);

  /// Oculta la categoría en directo completa.
  Future<void> hideCategory(String group) =>
      _db.hideCategory(ContentType.live, group);

  /// Restaura (muestra) la categoría en directo completa.
  Future<void> restoreCategory(String group) =>
      _db.restoreCategory(ContentType.live, group);

  /// Categorías en directo para la pantalla de gestión (incluye ocultos).
  Future<List<Category>> manageCategories() =>
      _db.categoriesByType(ContentType.live, onlyVisible: false);

  /// Nº de canales ocultos/borrados por categoría en directo.
  Future<Map<String, int>> liveHiddenCounts() =>
      _db.hiddenCountByCategory(ContentType.live);

  /// Todos los canales en directo de una categoría, con su estado.
  Future<List<MediaItem>> manageLiveByCategory(String group) async {
    final all = await _db.manageableByType(ContentType.live);
    return all
        .where((i) => (i.groupTitle ?? 'Sin categoria') == group)
        .toList();
  }

  // --- VOD (películas y series) ---

  Future<List<Category>> movieCategories() =>
      _db.categoriesByType(ContentType.movie);

  Future<List<MediaItem>> moviesByCategory(String group) async {
    final all = await _db.itemsByType(ContentType.movie);
    return all
        .where((i) => (i.groupTitle ?? 'Sin categoria') == group)
        .toList();
  }

  Future<List<Category>> seriesCategories() =>
      _db.categoriesByType(ContentType.series);

  Future<List<MediaItem>> seriesByCategory(String group) async {
    final all = await _db.itemsByType(ContentType.series);
    return all
        .where((i) => (i.groupTitle ?? 'Sin categoria') == group)
        .toList();
  }

  /// Guarda el progreso (posición + duración) para reanudar y "Continuar viendo".
  Future<void> saveProgress(String id, int seconds, {int duration = 0}) => _db
      .setProgress(id, seconds, duration, DateTime.now().millisecondsSinceEpoch);

  /// Posición de reproducción guardada (segundos) de un item.
  Future<int> progress(String id) => _db.getPosition(id);

  /// URL de un stream cargado (para reconstruir la lista si se cargó sin guardar).
  Future<String?> sampleStreamUrl() => _db.sampleStreamUrl();

  /// Películas/series empezadas y sin terminar (más recientes primero).
  Future<List<MediaItem>> continueWatching() => _db.itemsInProgress();

  /// Novedades de películas (recién añadidas).
  Future<List<MediaItem>> recentMovies({int limit = 30}) =>
      _db.recentByType(ContentType.movie, limit: limit);

  /// Novedades de series: episodios recientes (para agrupar en el Inicio).
  Future<List<MediaItem>> recentSeriesItems({int limit = 120}) =>
      _db.recentByType(ContentType.series, limit: limit);

  // --- Gestión VOD (ocultar/borrar por tipo, igual que en TV) ---

  Future<void> hideCategoryOf(ContentType type, String group) =>
      _db.hideCategory(type, group);

  Future<void> restoreCategoryOf(ContentType type, String group) =>
      _db.restoreCategory(type, group);

  /// Categorías de un tipo para gestión (incluye ocultas).
  Future<List<Category>> manageCategoriesOf(ContentType type) =>
      _db.categoriesByType(type, onlyVisible: false);

  /// Nº de items ocultos/borrados por categoría de un tipo.
  Future<Map<String, int>> hiddenCountsOf(ContentType type) =>
      _db.hiddenCountByCategory(type);

  /// Todos los items de una categoría de un tipo, con su estado (para gestión).
  Future<List<MediaItem>> manageByCategory(
      ContentType type, String group) async {
    final all = await _db.manageableByType(type);
    return all
        .where((i) => (i.groupTitle ?? 'Sin categoria') == group)
        .toList();
  }
}
