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

  /// Categorías en directo para la pantalla de gestión (incluye ocultos).
  Future<List<Category>> manageCategories() =>
      _db.categoriesByType(ContentType.live, onlyVisible: false);

  /// Todos los canales en directo de una categoría, con su estado.
  Future<List<MediaItem>> manageLiveByCategory(String group) async {
    final all = await _db.manageableByType(ContentType.live);
    return all
        .where((i) => (i.groupTitle ?? 'Sin categoria') == group)
        .toList();
  }
}
