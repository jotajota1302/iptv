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

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Items])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  MediaItem _map(Item r) => MediaItem(
        id: r.id,
        name: r.name,
        streamUrl: r.streamUrl,
        logoUrl: r.logoUrl,
        tvgId: r.tvgId,
        groupTitle: r.groupTitle,
        type: ContentType.values[r.type],
        isFavorite: r.isFavorite,
      );

  Future<void> replaceItems(List<MediaItem> newItems) async {
    await batch((b) {
      b.deleteWhere(items, (_) => const Constant(true));
      b.insertAll(
        items,
        newItems.map((m) => ItemsCompanion.insert(
              id: m.id,
              name: m.name,
              streamUrl: m.streamUrl,
              logoUrl: Value(m.logoUrl),
              tvgId: Value(m.tvgId),
              groupTitle: Value(m.groupTitle),
              type: m.type.index,
              isFavorite: Value(m.isFavorite),
            )),
        mode: InsertMode.insertOrReplace,
      );
    });
  }

  Future<List<MediaItem>> itemsByType(ContentType type) async {
    final rows =
        await (select(items)..where((t) => t.type.equals(type.index))).get();
    return rows.map(_map).toList();
  }

  Future<List<Category>> categoriesByType(ContentType type) async {
    final rows = await itemsByType(type);
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
    final rows =
        await (select(items)..where((t) => t.name.lower().like(q))).get();
    return rows.map(_map).toList();
  }

  Future<void> setFavorite(String id, bool value) =>
      (update(items)..where((t) => t.id.equals(id)))
          .write(ItemsCompanion(isFavorite: Value(value)));

  Future<List<MediaItem>> favorites() async {
    final rows =
        await (select(items)..where((t) => t.isFavorite.equals(true))).get();
    return rows.map(_map).toList();
  }
}

LazyDatabase _open() => LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      return NativeDatabase.createInBackground(
          File(p.join(dir.path, 'iptv.sqlite')));
    });
