import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../domain/category.dart';
import '../domain/content_type.dart';
import '../domain/media_item.dart';

part 'app_database.g.dart';

class Items extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get streamUrl => text()();
  TextColumn get logoUrl => text().nullable()();
  TextColumn get tvgId => text().nullable()();
  TextColumn get groupTitle => text().nullable()();
  IntColumn get type => integer()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isHidden => boolean().withDefault(const Constant(false))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Items])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(items, items.isHidden);
            await m.addColumn(items, items.isDeleted);
          }
        },
      );

  MediaItem _map(Item r) => MediaItem(
        id: r.id,
        name: r.name,
        streamUrl: r.streamUrl,
        logoUrl: r.logoUrl,
        tvgId: r.tvgId,
        groupTitle: r.groupTitle,
        type: ContentType.values[r.type],
        isFavorite: r.isFavorite,
        isHidden: r.isHidden,
        isDeleted: r.isDeleted,
      );

  /// Reemplaza la caché preservando los flags de usuario (favorito/oculto/
  /// borrado) de los items que ya existían, identificados por [id].
  Future<void> replaceItems(List<MediaItem> newItems) async {
    final existing = await select(items).get();
    final flags = {
      for (final r in existing)
        r.id: (fav: r.isFavorite, hidden: r.isHidden, deleted: r.isDeleted),
    };
    await batch((b) {
      b.deleteWhere(items, (_) => const Constant(true));
      b.insertAll(
        items,
        newItems.map((m) {
          final f = flags[m.id];
          return ItemsCompanion.insert(
            id: m.id,
            name: m.name,
            streamUrl: m.streamUrl,
            logoUrl: Value(m.logoUrl),
            tvgId: Value(m.tvgId),
            groupTitle: Value(m.groupTitle),
            type: m.type.index,
            isFavorite: Value(f?.fav ?? m.isFavorite),
            isHidden: Value(f?.hidden ?? m.isHidden),
            isDeleted: Value(f?.deleted ?? m.isDeleted),
          );
        }),
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Expression<bool> _visible($ItemsTable t) =>
      t.isHidden.not() & t.isDeleted.not();

  /// Items visibles (no ocultos ni borrados) de un tipo.
  Future<List<MediaItem>> itemsByType(ContentType type) async {
    final rows = await (select(items)
          ..where((t) => t.type.equals(type.index) & _visible(t)))
        .get();
    return rows.map(_map).toList();
  }

  /// Todos los items de un tipo, incluidos ocultos y borrados (para gestión).
  Future<List<MediaItem>> manageableByType(ContentType type) async {
    final rows =
        await (select(items)..where((t) => t.type.equals(type.index))).get();
    return rows.map(_map).toList();
  }

  Future<List<Category>> categoriesByType(ContentType type,
      {bool onlyVisible = true}) async {
    final rows =
        onlyVisible ? await itemsByType(type) : await manageableByType(type);
    final counts = <String, int>{};
    for (final r in rows) {
      final g = r.groupTitle ?? 'Sin categoria';
      counts[g] = (counts[g] ?? 0) + 1;
    }
    return counts.entries
        .map((e) => Category(name: e.key, type: type, itemCount: e.value))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  Future<List<MediaItem>> search(String query) async {
    final q = '%${query.toLowerCase()}%';
    final rows = await (select(items)
          ..where((t) => t.name.lower().like(q) & _visible(t)))
        .get();
    return rows.map(_map).toList();
  }

  Future<void> setFavorite(String id, bool value) =>
      (update(items)..where((t) => t.id.equals(id)))
          .write(ItemsCompanion(isFavorite: Value(value)));

  Future<void> setHidden(String id, bool value) =>
      (update(items)..where((t) => t.id.equals(id)))
          .write(ItemsCompanion(isHidden: Value(value)));

  Future<void> setDeleted(String id, bool value) =>
      (update(items)..where((t) => t.id.equals(id)))
          .write(ItemsCompanion(isDeleted: Value(value)));

  /// Restaura un item: deja de estar oculto y borrado.
  Future<void> restore(String id) =>
      (update(items)..where((t) => t.id.equals(id))).write(
          const ItemsCompanion(
              isHidden: Value(false), isDeleted: Value(false)));

  Expression<bool> _inCategory($ItemsTable t, ContentType type, String group) {
    final base = t.type.equals(type.index);
    // 'Sin categoria' representa groupTitle NULL.
    return group == 'Sin categoria'
        ? base & t.groupTitle.isNull()
        : base & t.groupTitle.equals(group);
  }

  /// Oculta todos los canales de una categoría.
  Future<void> hideCategory(ContentType type, String group) =>
      (update(items)..where((t) => _inCategory(t, type, group)))
          .write(const ItemsCompanion(isHidden: Value(true)));

  /// Restaura (muestra) todos los canales de una categoría.
  Future<void> restoreCategory(ContentType type, String group) =>
      (update(items)..where((t) => _inCategory(t, type, group))).write(
          const ItemsCompanion(
              isHidden: Value(false), isDeleted: Value(false)));

  Future<List<MediaItem>> favorites() async {
    final rows = await (select(items)
          ..where((t) => t.isFavorite.equals(true) & _visible(t)))
        .get();
    return rows.map(_map).toList();
  }
}

LazyDatabase _open() => LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      return NativeDatabase.createInBackground(
          File(p.join(dir.path, 'iptv.sqlite')));
    });
