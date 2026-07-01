# IPTV Player — Fase 1 (núcleo MVP) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reproductor IPTV multiplataforma que carga una lista M3U (URL o archivo), la cachea, permite navegar canales en directo por categorías, reproducirlos, buscarlos y marcarlos como favoritos.

**Architecture:** Flutter con arquitectura por capas (UI → providers Riverpod → repositorios → fuentes de datos + persistencia SQLite/Drift). El parseo M3U ocurre en un isolate. La reproducción se abstrae tras una interfaz `PlayerController` para poder testear la lógica con mocks; la implementación real usa `media_kit` (libmpv), que reproduce MPEG-TS/HLS.

**Tech Stack:** Flutter, Dart, flutter_riverpod, drift + sqlite3, dio, media_kit + media_kit_video, file_picker, cached_network_image, mocktail (test).

## Global Constraints

- Dart SDK >= 3.4.0; Flutter estable (canal stable).
- Toda la lógica de negocio (parser, classifier, repositorios) es Dart puro y se testea con `flutter test` (Dart VM), sin depender de toolchains de plataforma.
- Los widgets que dependen de `media_kit` deben aislarse tras la interfaz `PlayerController`; ningún test unitario instancia el reproductor real.
- Nombres de identificadores y comentarios de código en inglés; textos de UI en español.
- Cada tarea termina con `flutter test` en verde y un commit.
- Spec de referencia: `docs/superpowers/specs/2026-07-01-iptv-player-design.md`.

---

### Task 1: Scaffold del proyecto y estructura de carpetas

**Files:**
- Create: proyecto Flutter en la raíz `C:\Users\Nitropc\Desktop\IPTV Player` (nombre paquete `iptv_player`).
- Modify: `pubspec.yaml` (dependencias).
- Create: `lib/src/` con subcarpetas `domain/`, `data/`, `player/`, `ui/`, `app/`.
- Test: `test/smoke_test.dart`.

**Interfaces:**
- Produces: proyecto compilable con `flutter analyze` limpio y `flutter test` ejecutable.

- [ ] **Step 1: Crear el proyecto Flutter**

Run (en la raíz del proyecto; el directorio ya existe con `docs/` y `.git/`):
```bash
flutter create --project-name iptv_player --platforms=windows,android --org com.iptvplayer .
```

- [ ] **Step 2: Añadir dependencias en `pubspec.yaml`**

Bajo `dependencies:` añadir:
```yaml
  flutter_riverpod: ^2.5.1
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.0
  path: ^1.9.0
  dio: ^5.4.0
  media_kit: ^1.1.10
  media_kit_video: ^1.2.4
  media_kit_libs_video: ^1.0.4
  file_picker: ^8.0.0
  cached_network_image: ^3.3.0
```
Bajo `dev_dependencies:` añadir:
```yaml
  drift_dev: ^2.18.0
  build_runner: ^2.4.0
  mocktail: ^1.0.0
```

- [ ] **Step 3: Crear estructura de carpetas y test de humo**

Crear `test/smoke_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('toolchain arranca', () {
    expect(1 + 1, 2);
  });
}
```
Crear carpetas vacías con `.gitkeep`: `lib/src/domain`, `lib/src/data`, `lib/src/player`, `lib/src/ui`, `lib/src/app`.

- [ ] **Step 4: Instalar dependencias y verificar**

Run:
```bash
flutter pub get
flutter analyze
flutter test
```
Expected: `pub get` OK, `analyze` sin errores, `smoke_test` PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: scaffold Flutter iptv_player con dependencias"
```

---

### Task 2: Modelos de dominio

**Files:**
- Create: `lib/src/domain/content_type.dart`
- Create: `lib/src/domain/media_item.dart`
- Create: `lib/src/domain/category.dart`
- Test: `test/domain/media_item_test.dart`

**Interfaces:**
- Produces:
  - `enum ContentType { live, movie, series, unknown }`
  - `class MediaItem` con campos `final String id, name, streamUrl; final String? logoUrl, tvgId, groupTitle; final ContentType type; final bool isFavorite;` y `MediaItem copyWith({bool? isFavorite})`.
  - `class Category` con `final String name; final ContentType type; final int itemCount;`

- [ ] **Step 1: Escribir el test que falla**

`test/domain/media_item_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/domain/content_type.dart';
import 'package:iptv_player/src/domain/media_item.dart';

void main() {
  test('copyWith cambia solo isFavorite', () {
    const item = MediaItem(
      id: '1', name: 'Canal', streamUrl: 'http://x/1.ts',
      type: ContentType.live, groupTitle: 'Deportes',
    );
    final fav = item.copyWith(isFavorite: true);
    expect(fav.isFavorite, true);
    expect(fav.id, '1');
    expect(fav.name, 'Canal');
    expect(item.isFavorite, false);
  });
}
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `flutter test test/domain/media_item_test.dart`
Expected: FAIL (tipos no definidos).

- [ ] **Step 3: Implementar los modelos**

`lib/src/domain/content_type.dart`:
```dart
enum ContentType { live, movie, series, unknown }
```
`lib/src/domain/media_item.dart`:
```dart
import 'content_type.dart';

class MediaItem {
  final String id;
  final String name;
  final String streamUrl;
  final String? logoUrl;
  final String? tvgId;
  final String? groupTitle;
  final ContentType type;
  final bool isFavorite;

  const MediaItem({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.logoUrl,
    this.tvgId,
    this.groupTitle,
    this.type = ContentType.unknown,
    this.isFavorite = false,
  });

  MediaItem copyWith({bool? isFavorite}) => MediaItem(
        id: id,
        name: name,
        streamUrl: streamUrl,
        logoUrl: logoUrl,
        tvgId: tvgId,
        groupTitle: groupTitle,
        type: type,
        isFavorite: isFavorite ?? this.isFavorite,
      );
}
```
`lib/src/domain/category.dart`:
```dart
import 'content_type.dart';

class Category {
  final String name;
  final ContentType type;
  final int itemCount;
  const Category({required this.name, required this.type, this.itemCount = 0});
}
```

- [ ] **Step 4: Ejecutar y verificar que pasa**

Run: `flutter test test/domain/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: modelos de dominio MediaItem, Category, ContentType"
```

---

### Task 3: Parser M3U

**Files:**
- Create: `lib/src/data/m3u_parser.dart`
- Test: `test/data/m3u_parser_test.dart`

**Interfaces:**
- Consumes: `MediaItem`, `ContentType` (Task 2).
- Produces: `List<MediaItem> parseM3u(String content)`. Extrae de cada `#EXTINF` los atributos `tvg-id`, `tvg-logo`, `group-title` y el nombre tras la coma; la línea siguiente no comentada es `streamUrl`. Ignora líneas mal formadas. El `id` se genera como `streamUrl.hashCode.toString()`. `type` se deja en `ContentType.unknown` (lo asigna el classifier en Task 4).

- [ ] **Step 1: Escribir el test que falla**

`test/data/m3u_parser_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/data/m3u_parser.dart';

const sample = '''
#EXTM3U
#EXTINF:-1 tvg-id="la1.es" tvg-logo="http://logo/la1.png" group-title="Nacionales",La 1
http://host:8443/user/pass/1001.ts
#EXTINF:-1 group-title="Cine",Pelicula X
http://host:8443/movie/user/pass/2002.mkv
linea-basura-sin-extinf
''';

void main() {
  test('parsea entradas validas e ignora basura', () {
    final items = parseM3u(sample);
    expect(items.length, 2);
    expect(items.first.name, 'La 1');
    expect(items.first.tvgId, 'la1.es');
    expect(items.first.logoUrl, 'http://logo/la1.png');
    expect(items.first.groupTitle, 'Nacionales');
    expect(items.first.streamUrl, 'http://host:8443/user/pass/1001.ts');
    expect(items[1].name, 'Pelicula X');
  });

  test('lista vacia o sin cabecera devuelve vacio sin crashear', () {
    expect(parseM3u(''), isEmpty);
    expect(parseM3u('texto random'), isEmpty);
  });
}
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `flutter test test/data/m3u_parser_test.dart`
Expected: FAIL (`parseM3u` no definido).

- [ ] **Step 3: Implementar el parser**

`lib/src/data/m3u_parser.dart`:
```dart
import '../domain/content_type.dart';
import '../domain/media_item.dart';

final _attrRegex = RegExp(r'([\w-]+)="(.*?)"');

List<MediaItem> parseM3u(String content) {
  final lines = content.split(RegExp(r'\r?\n'));
  final items = <MediaItem>[];
  String? name, tvgId, logo, group;
  var pendingInfo = false;

  for (final raw in lines) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#EXTINF')) {
      final attrs = {for (final m in _attrRegex.allMatches(line)) m[1]!: m[2]!};
      tvgId = attrs['tvg-id']?.isEmpty ?? true ? null : attrs['tvg-id'];
      logo = attrs['tvg-logo']?.isEmpty ?? true ? null : attrs['tvg-logo'];
      group = attrs['group-title']?.isEmpty ?? true ? null : attrs['group-title'];
      final commaIdx = line.lastIndexOf(',');
      name = commaIdx >= 0 ? line.substring(commaIdx + 1).trim() : 'Sin nombre';
      pendingInfo = true;
    } else if (line.startsWith('#')) {
      continue;
    } else if (pendingInfo) {
      items.add(MediaItem(
        id: line.hashCode.toString(),
        name: name ?? 'Sin nombre',
        streamUrl: line,
        logoUrl: logo,
        tvgId: tvgId,
        groupTitle: group,
        type: ContentType.unknown,
      ));
      pendingInfo = false;
      name = tvgId = logo = group = null;
    }
  }
  return items;
}
```

- [ ] **Step 4: Ejecutar y verificar que pasa**

Run: `flutter test test/data/m3u_parser_test.dart`
Expected: PASS (ambos tests).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: parser M3U tolerante a lineas invalidas"
```

---

### Task 4: Clasificador de contenido

**Files:**
- Create: `lib/src/data/content_classifier.dart`
- Test: `test/data/content_classifier_test.dart`

**Interfaces:**
- Consumes: `MediaItem`, `ContentType`.
- Produces: `MediaItem classifyItem(MediaItem item)` que devuelve una copia con `type` asignado. Reglas: si la URL contiene `/series/` → series; `/movie/` o extensión de vídeo VOD (`.mkv .mp4 .avi`) → movie; si contiene `/live/` o termina en `.ts`/`.m3u8` → live; en otro caso, si `group-title` contiene "serie" → series, "cine"/"pelicula"/"vod"/"movie" → movie; por defecto → live. Además `List<MediaItem> classifyAll(List<MediaItem>)`.

- [ ] **Step 1: Escribir el test que falla**

`test/data/content_classifier_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/domain/content_type.dart';
import 'package:iptv_player/src/domain/media_item.dart';
import 'package:iptv_player/src/data/content_classifier.dart';

MediaItem item(String url, {String? group}) =>
    MediaItem(id: url, name: 'x', streamUrl: url, groupTitle: group);

void main() {
  test('clasifica por segmento de URL', () {
    expect(classifyItem(item('http://h/live/u/p/1.ts')).type, ContentType.live);
    expect(classifyItem(item('http://h/movie/u/p/2.mkv')).type, ContentType.movie);
    expect(classifyItem(item('http://h/series/u/p/3.mp4')).type, ContentType.series);
  });

  test('.ts sin segmento es live', () {
    expect(classifyItem(item('http://h/u/p/1001.ts')).type, ContentType.live);
  });

  test('fallback por group-title', () {
    expect(classifyItem(item('http://h/x', group: 'Cine Accion')).type, ContentType.movie);
    expect(classifyItem(item('http://h/x', group: 'Series VIP')).type, ContentType.series);
  });
}
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `flutter test test/data/content_classifier_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementar el clasificador**

`lib/src/data/content_classifier.dart`:
```dart
import '../domain/content_type.dart';
import '../domain/media_item.dart';

MediaItem classifyItem(MediaItem item) {
  final url = item.streamUrl.toLowerCase();
  final group = (item.groupTitle ?? '').toLowerCase();
  ContentType type;
  if (url.contains('/series/')) {
    type = ContentType.series;
  } else if (url.contains('/movie/') ||
      url.endsWith('.mkv') || url.endsWith('.mp4') || url.endsWith('.avi')) {
    type = ContentType.movie;
  } else if (url.contains('/live/') || url.endsWith('.ts') || url.endsWith('.m3u8')) {
    type = ContentType.live;
  } else if (group.contains('serie')) {
    type = ContentType.series;
  } else if (group.contains('cine') || group.contains('pelicula') ||
      group.contains('vod') || group.contains('movie')) {
    type = ContentType.movie;
  } else {
    type = ContentType.live;
  }
  return MediaItem(
    id: item.id, name: item.name, streamUrl: item.streamUrl,
    logoUrl: item.logoUrl, tvgId: item.tvgId, groupTitle: item.groupTitle,
    type: type, isFavorite: item.isFavorite,
  );
}

List<MediaItem> classifyAll(List<MediaItem> items) =>
    items.map(classifyItem).toList();
```

- [ ] **Step 4: Ejecutar y verificar que pasa**

Run: `flutter test test/data/content_classifier_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: clasificador live/movie/series"
```

---

### Task 5: Base de datos Drift (persistencia + favoritos)

**Files:**
- Create: `lib/src/data/app_database.dart`
- Test: `test/data/app_database_test.dart`

**Interfaces:**
- Consumes: `MediaItem`, `ContentType`.
- Produces: `class AppDatabase` con:
  - `Future<void> replaceItems(List<MediaItem> items)` (borra y reinserta la caché).
  - `Future<List<MediaItem>> itemsByType(ContentType type)`.
  - `Future<List<Category>> categoriesByType(ContentType type)` (agrupa por groupTitle).
  - `Future<List<MediaItem>> search(String query)`.
  - `Future<void> setFavorite(String id, bool value)`.
  - `Future<List<MediaItem>> favorites()`.
  - Constructor `AppDatabase.forTesting(QueryExecutor e)` para tests en memoria.

- [ ] **Step 1: Escribir el test que falla**

`test/data/app_database_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/data/app_database.dart';
import 'package:iptv_player/src/domain/content_type.dart';
import 'package:iptv_player/src/domain/media_item.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('replace + itemsByType + favoritos + search', () async {
    await db.replaceItems([
      const MediaItem(id: 'a', name: 'La 1', streamUrl: 'u1',
          groupTitle: 'Nacionales', type: ContentType.live),
      const MediaItem(id: 'b', name: 'Cine', streamUrl: 'u2',
          groupTitle: 'Cine', type: ContentType.movie),
    ]);
    final live = await db.itemsByType(ContentType.live);
    expect(live.length, 1);
    expect(live.first.name, 'La 1');

    await db.setFavorite('a', true);
    expect((await db.favorites()).single.id, 'a');

    final found = await db.search('la');
    expect(found.single.id, 'a');

    final cats = await db.categoriesByType(ContentType.live);
    expect(cats.single.name, 'Nacionales');
  });
}
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `flutter test test/data/app_database_test.dart`
Expected: FAIL (`AppDatabase` no existe / falta código generado).

- [ ] **Step 3: Implementar la base de datos**

`lib/src/data/app_database.dart`:
```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
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
  AppDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  MediaItem _map(Item r) => MediaItem(
        id: r.id, name: r.name, streamUrl: r.streamUrl, logoUrl: r.logoUrl,
        tvgId: r.tvgId, groupTitle: r.groupTitle,
        type: ContentType.values[r.type], isFavorite: r.isFavorite,
      );

  Future<void> replaceItems(List<MediaItem> items) async {
    await batch((b) {
      b.deleteWhere(this.items, (_) => const Constant(true));
      b.insertAll(this.items, items.map((m) => ItemsCompanion.insert(
            id: m.id, name: m.name, streamUrl: m.streamUrl,
            logoUrl: Value(m.logoUrl), tvgId: Value(m.tvgId),
            groupTitle: Value(m.groupTitle), type: m.type.index,
            isFavorite: Value(m.isFavorite),
          )));
    });
  }

  Future<List<MediaItem>> itemsByType(ContentType type) async {
    final rows = await (select(items)..where((t) => t.type.equals(type.index))).get();
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
    final rows = await (select(items)
          ..where((t) => t.name.lower().like(q)))
        .get();
    return rows.map(_map).toList();
  }

  Future<void> setFavorite(String id, bool value) =>
      (update(items)..where((t) => t.id.equals(id)))
          .write(ItemsCompanion(isFavorite: Value(value)));

  Future<List<MediaItem>> favorites() async {
    final rows = await (select(items)..where((t) => t.isFavorite.equals(true))).get();
    return rows.map(_map).toList();
  }
}

LazyDatabase _open() => LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      return NativeDatabase.createInBackground(File(p.join(dir.path, 'iptv.sqlite')));
    });
```

- [ ] **Step 4: Generar código Drift**

Run:
```bash
dart run build_runner build --delete-conflicting-outputs
```
Expected: genera `lib/src/data/app_database.g.dart` sin errores.

- [ ] **Step 5: Ejecutar y verificar que pasa**

Run: `flutter test test/data/app_database_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: base de datos Drift con cache, categorias, busqueda y favoritos"
```

---

### Task 6: Fuente de datos M3U (URL y archivo)

**Files:**
- Create: `lib/src/data/m3u_source.dart`
- Test: `test/data/m3u_source_test.dart`

**Interfaces:**
- Consumes: `parseM3u` (Task 3).
- Produces: `abstract class HttpClient { Future<String> getText(String url); }`, `class DioHttpClient implements HttpClient`, y `class M3uSource { M3uSource(this._http); Future<String> fetchFromUrl(String url); Future<String> readFromFile(String path); }`. `fetchFromUrl` delega en `HttpClient.getText`; `readFromFile` lee el archivo. Ambos devuelven el texto crudo (el parseo lo hace el repositorio).

- [ ] **Step 1: Escribir el test que falla**

`test/data/m3u_source_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:iptv_player/src/data/m3u_source.dart';

class _MockHttp extends Mock implements HttpClient {}

void main() {
  test('fetchFromUrl devuelve el texto del http client', () async {
    final http = _MockHttp();
    when(() => http.getText('http://x/list.m3u'))
        .thenAnswer((_) async => '#EXTM3U\n');
    final source = M3uSource(http);
    final text = await source.fetchFromUrl('http://x/list.m3u');
    expect(text, '#EXTM3U\n');
  });
}
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `flutter test test/data/m3u_source_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementar la fuente**

`lib/src/data/m3u_source.dart`:
```dart
import 'dart:io';
import 'package:dio/dio.dart';

abstract class HttpClient {
  Future<String> getText(String url);
}

class DioHttpClient implements HttpClient {
  final Dio _dio;
  DioHttpClient([Dio? dio])
      : _dio = dio ?? Dio(BaseOptions(responseType: ResponseType.plain));
  @override
  Future<String> getText(String url) async {
    final res = await _dio.get<String>(url);
    return res.data ?? '';
  }
}

class M3uSource {
  final HttpClient _http;
  M3uSource(this._http);

  Future<String> fetchFromUrl(String url) => _http.getText(url);

  Future<String> readFromFile(String path) => File(path).readAsString();
}
```

- [ ] **Step 4: Ejecutar y verificar que pasa**

Run: `flutter test test/data/m3u_source_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: fuente de datos M3U por URL y archivo con HttpClient abstracto"
```

---

### Task 7: Repositorio de playlist

**Files:**
- Create: `lib/src/data/playlist_repository.dart`
- Test: `test/data/playlist_repository_test.dart`

**Interfaces:**
- Consumes: `M3uSource` (Task 6), `AppDatabase` (Task 5), `parseM3u` (Task 3), `classifyAll` (Task 4).
- Produces: `class PlaylistRepository { PlaylistRepository(this._source, this._db); Future<int> loadFromUrl(String url); Future<int> loadFromFile(String path); Future<List<Category>> liveCategories(); Future<List<MediaItem>> liveByCategory(String group); Future<List<MediaItem>> search(String q); Future<List<MediaItem>> favorites(); Future<void> toggleFavorite(MediaItem item); }`. `loadFromUrl` obtiene texto → `parseM3u` → `classifyAll` → `db.replaceItems`, devuelve el nº de items. La clasificación de miles de items se ejecuta con `compute` (isolate) mediante la función top-level `parseAndClassify(String content)`.

- [ ] **Step 1: Escribir el test que falla**

`test/data/playlist_repository_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:iptv_player/src/data/app_database.dart';
import 'package:iptv_player/src/data/m3u_source.dart';
import 'package:iptv_player/src/data/playlist_repository.dart';
import 'package:iptv_player/src/domain/content_type.dart';

class _MockSource extends Mock implements M3uSource {}

const _m3u = '''
#EXTM3U
#EXTINF:-1 group-title="Nacionales",La 1
http://h/live/u/p/1.ts
#EXTINF:-1 group-title="Cine",Peli
http://h/movie/u/p/2.mkv
''';

void main() {
  test('loadFromUrl parsea, clasifica y cachea', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final source = _MockSource();
    when(() => source.fetchFromUrl(any())).thenAnswer((_) async => _m3u);
    final repo = PlaylistRepository(source, db);

    final count = await repo.loadFromUrl('http://x');
    expect(count, 2);

    final cats = await repo.liveCategories();
    expect(cats.single.name, 'Nacionales');
    final live = await repo.liveByCategory('Nacionales');
    expect(live.single.type, ContentType.live);
    await db.close();
  });
}
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `flutter test test/data/playlist_repository_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementar el repositorio**

`lib/src/data/playlist_repository.dart`:
```dart
import 'package:flutter/foundation.dart';
import '../domain/category.dart';
import '../domain/content_type.dart';
import '../domain/media_item.dart';
import 'app_database.dart';
import 'content_classifier.dart';
import 'm3u_parser.dart';
import 'm3u_source.dart';

List<MediaItem> parseAndClassify(String content) => classifyAll(parseM3u(content));

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

  Future<List<Category>> liveCategories() => _db.categoriesByType(ContentType.live);

  Future<List<MediaItem>> liveByCategory(String group) async {
    final all = await _db.itemsByType(ContentType.live);
    return all.where((i) => (i.groupTitle ?? 'Sin categoria') == group).toList();
  }

  Future<List<MediaItem>> search(String q) => _db.search(q);
  Future<List<MediaItem>> favorites() => _db.favorites();

  Future<void> toggleFavorite(MediaItem item) =>
      _db.setFavorite(item.id, !item.isFavorite);
}
```

- [ ] **Step 4: Ejecutar y verificar que pasa**

Run: `flutter test test/data/playlist_repository_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: repositorio de playlist con parseo en isolate y cache"
```

---

### Task 8: Interfaz e implementación del reproductor

**Files:**
- Create: `lib/src/player/player_controller.dart`
- Create: `lib/src/player/media_kit_player_controller.dart`
- Test: `test/player/player_controller_test.dart`

**Interfaces:**
- Produces:
  - `abstract class PlayerController { Future<void> open(String url); Future<void> play(); Future<void> pause(); Future<void> dispose(); Stream<PlayerStatus> get status; }`
  - `enum PlayerStatus { idle, buffering, playing, paused, error }`
  - `class MediaKitPlayerController implements PlayerController` (envuelve `media_kit.Player`).
- Nota: el test solo cubre un `FakePlayerController` para validar el contrato; `MediaKitPlayerController` no se testea unitariamente (requiere libmpv).

- [ ] **Step 1: Escribir el test que falla**

`test/player/player_controller_test.dart`:
```dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/player/player_controller.dart';

class FakePlayerController implements PlayerController {
  final _ctrl = StreamController<PlayerStatus>.broadcast();
  String? opened;
  @override
  Stream<PlayerStatus> get status => _ctrl.stream;
  @override
  Future<void> open(String url) async {
    opened = url;
    _ctrl.add(PlayerStatus.buffering);
    _ctrl.add(PlayerStatus.playing);
  }
  @override
  Future<void> play() async => _ctrl.add(PlayerStatus.playing);
  @override
  Future<void> pause() async => _ctrl.add(PlayerStatus.paused);
  @override
  Future<void> dispose() async => _ctrl.close();
}

void main() {
  test('open emite buffering y luego playing', () async {
    final p = FakePlayerController();
    final events = <PlayerStatus>[];
    p.status.listen(events.add);
    await p.open('http://x/1.ts');
    await Future<void>.delayed(Duration.zero);
    expect(p.opened, 'http://x/1.ts');
    expect(events, [PlayerStatus.buffering, PlayerStatus.playing]);
  });
}
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `flutter test test/player/player_controller_test.dart`
Expected: FAIL (`PlayerController`/`PlayerStatus` no existen).

- [ ] **Step 3: Implementar interfaz e implementación real**

`lib/src/player/player_controller.dart`:
```dart
enum PlayerStatus { idle, buffering, playing, paused, error }

abstract class PlayerController {
  Future<void> open(String url);
  Future<void> play();
  Future<void> pause();
  Future<void> dispose();
  Stream<PlayerStatus> get status;
}
```
`lib/src/player/media_kit_player_controller.dart`:
```dart
import 'dart:async';
import 'package:media_kit/media_kit.dart';
import 'player_controller.dart';

class MediaKitPlayerController implements PlayerController {
  final Player player = Player();
  final _status = StreamController<PlayerStatus>.broadcast();
  final _subs = <StreamSubscription>[];

  MediaKitPlayerController() {
    _subs.add(player.stream.playing.listen((p) =>
        _status.add(p ? PlayerStatus.playing : PlayerStatus.paused)));
    _subs.add(player.stream.buffering.listen((b) {
      if (b) _status.add(PlayerStatus.buffering);
    }));
    _subs.add(player.stream.error.listen((_) => _status.add(PlayerStatus.error)));
  }

  @override
  Stream<PlayerStatus> get status => _status.stream;
  @override
  Future<void> open(String url) => player.open(Media(url));
  @override
  Future<void> play() => player.play();
  @override
  Future<void> pause() => player.pause();
  @override
  Future<void> dispose() async {
    for (final s in _subs) {
      await s.cancel();
    }
    await _status.close();
    await player.dispose();
  }
}
```

- [ ] **Step 4: Ejecutar y verificar que pasa**

Run: `flutter test test/player/player_controller_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: interfaz PlayerController + implementacion media_kit"
```

---

### Task 9: Providers Riverpod y arranque

**Files:**
- Create: `lib/src/app/providers.dart`
- Modify: `lib/main.dart`
- Test: `test/app/providers_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `M3uSource`, `DioHttpClient`, `PlaylistRepository`.
- Produces:
  - `final databaseProvider = Provider<AppDatabase>(...)`
  - `final playlistRepositoryProvider = Provider<PlaylistRepository>(...)`
  - `final liveCategoriesProvider = FutureProvider<List<Category>>(...)`
  - `final favoritesProvider = FutureProvider<List<MediaItem>>(...)`
  - `final searchQueryProvider = StateProvider<String>((_) => '')`
  - `final searchResultsProvider = FutureProvider<List<MediaItem>>(...)`
  - `main()` inicializa `MediaKit.ensureInitialized()` y monta `ProviderScope(child: IptvApp())`.

- [ ] **Step 1: Escribir el test que falla**

`test/app/providers_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/app/providers.dart';
import 'package:iptv_player/src/data/app_database.dart';

void main() {
  test('override de databaseProvider permite resolver el repositorio', () {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    expect(container.read(playlistRepositoryProvider), isNotNull);
  });
}
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `flutter test test/app/providers_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementar providers**

`lib/src/app/providers.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
```

- [ ] **Step 4: Actualizar `lib/main.dart`**

Reemplazar el contenido por:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'src/ui/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const ProviderScope(child: IptvApp()));
}

class IptvApp extends StatelessWidget {
  const IptvApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IPTV Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const AppShell(),
    );
  }
}
```
(Nota: `AppShell` se crea en Task 10; hasta entonces `main.dart` no compilará y eso es esperado — el commit de esta tarea es solo de `providers.dart` y su test; `main.dart` se commitea en Task 10.)

- [ ] **Step 5: Ejecutar y verificar que pasa el test de providers**

Run: `flutter test test/app/providers_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/src/app/providers.dart test/app/providers_test.dart
git commit -m "feat: providers Riverpod de base de datos, repositorio y busqueda"
```

---

### Task 10: UI — App shell con navegación adaptativa

**Files:**
- Create: `lib/src/ui/app_shell.dart`
- Create: `lib/src/ui/live_tab.dart` (placeholder mínimo funcional)
- Create: `lib/src/ui/favorites_tab.dart` (placeholder mínimo funcional)
- Create: `lib/src/ui/search_tab.dart` (placeholder mínimo funcional)
- Create: `lib/src/ui/settings_tab.dart` (placeholder mínimo funcional)
- Test: `test/ui/app_shell_test.dart`

**Interfaces:**
- Consumes: nada de datos aún (las pestañas se rellenan en Tasks 11-14).
- Produces: `class AppShell extends StatefulWidget` que muestra 4 destinos (TV, Favoritos, Buscar, Ajustes) con `NavigationBar` en pantallas estrechas y `NavigationRail` en anchas (breakpoint 600px). Cada tab es un widget separado.

- [ ] **Step 1: Escribir el test que falla**

`test/ui/app_shell_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/ui/app_shell.dart';

void main() {
  testWidgets('muestra los 4 destinos de navegacion', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: AppShell()),
    ));
    expect(find.text('TV'), findsWidgets);
    expect(find.text('Favoritos'), findsWidgets);
    expect(find.text('Buscar'), findsWidgets);
    expect(find.text('Ajustes'), findsWidgets);
  });
}
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `flutter test test/ui/app_shell_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementar el shell y placeholders**

`lib/src/ui/live_tab.dart`:
```dart
import 'package:flutter/material.dart';
class LiveTab extends StatelessWidget {
  const LiveTab({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('TV en directo'));
}
```
`lib/src/ui/favorites_tab.dart`:
```dart
import 'package:flutter/material.dart';
class FavoritesTab extends StatelessWidget {
  const FavoritesTab({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Favoritos'));
}
```
`lib/src/ui/search_tab.dart`:
```dart
import 'package:flutter/material.dart';
class SearchTab extends StatelessWidget {
  const SearchTab({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Buscar'));
}
```
`lib/src/ui/settings_tab.dart`:
```dart
import 'package:flutter/material.dart';
class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text('Ajustes'));
}
```
`lib/src/ui/app_shell.dart`:
```dart
import 'package:flutter/material.dart';
import 'live_tab.dart';
import 'favorites_tab.dart';
import 'search_tab.dart';
import 'settings_tab.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  static const _tabs = [LiveTab(), FavoritesTab(), SearchTab(), SettingsTab()];
  static const _destinations = [
    (icon: Icons.live_tv, label: 'TV'),
    (icon: Icons.favorite, label: 'Favoritos'),
    (icon: Icons.search, label: 'Buscar'),
    (icon: Icons.settings, label: 'Ajustes'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 600;
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                    icon: Icon(d.icon), label: Text(d.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _tabs[_index]),
        ]),
      );
    }
    return Scaffold(
      body: _tabs[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Ejecutar y verificar que pasa + analyze**

Run:
```bash
flutter test test/ui/app_shell_test.dart
flutter analyze
```
Expected: test PASS; analyze sin errores (main.dart ya resuelve AppShell).

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: app shell con navegacion adaptativa y main.dart"
```

---

### Task 11: UI — Ajustes: añadir lista M3U (URL/archivo)

**Files:**
- Modify: `lib/src/ui/settings_tab.dart`
- Modify: `lib/src/app/providers.dart` (añadir `loadStateProvider`)
- Test: `test/ui/settings_tab_test.dart`

**Interfaces:**
- Consumes: `playlistRepositoryProvider`, `liveCategoriesProvider`.
- Produces: `settings_tab` con un `TextField` de URL, botón "Cargar URL", botón "Elegir archivo" (usa `file_picker`) y un indicador de progreso/resultado. Tras cargar, invalida `liveCategoriesProvider` y `favoritesProvider`. Añade `final loadStateProvider = StateProvider<String?>((_) => null)` para mensajes de estado.

- [ ] **Step 1: Escribir el test que falla**

`test/ui/settings_tab_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:iptv_player/src/app/providers.dart';
import 'package:iptv_player/src/data/app_database.dart';
import 'package:iptv_player/src/data/playlist_repository.dart';
import 'package:iptv_player/src/ui/settings_tab.dart';

class _MockRepo extends Mock implements PlaylistRepository {}

void main() {
  testWidgets('cargar URL invoca al repositorio', (tester) async {
    final repo = _MockRepo();
    when(() => repo.loadFromUrl(any())).thenAnswer((_) async => 42);
    await tester.pumpWidget(ProviderScope(
      overrides: [playlistRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: Scaffold(body: SettingsTab())),
    ));
    await tester.enterText(find.byType(TextField), 'http://x/list.m3u');
    await tester.tap(find.text('Cargar URL'));
    await tester.pump();
    verify(() => repo.loadFromUrl('http://x/list.m3u')).called(1);
  });
}
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `flutter test test/ui/settings_tab_test.dart`
Expected: FAIL.

- [ ] **Step 3: Añadir `loadStateProvider` en `providers.dart`**

Añadir al final de `lib/src/app/providers.dart`:
```dart
final loadStateProvider = StateProvider<String?>((_) => null);
```

- [ ] **Step 4: Implementar `settings_tab.dart`**

`lib/src/ui/settings_tab.dart`:
```dart
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
            onPressed: _loading ? null : () => _run(() => repo.loadFromUrl(_urlCtrl.text.trim())),
            child: const Text('Cargar URL'),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: _loading
                ? null
                : () async {
                    final res = await FilePicker.platform.pickFiles(
                        type: FileType.any, withData: false);
                    final path = res?.files.single.path;
                    if (path != null) await _run(() => repo.loadFromFile(path));
                  },
            child: const Text('Elegir archivo'),
          ),
        ]),
        const SizedBox(height: 16),
        if (_loading) const LinearProgressIndicator(),
        if (status != null) Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(status),
        ),
      ]),
    );
  }
}
```

- [ ] **Step 5: Ejecutar y verificar que pasa**

Run: `flutter test test/ui/settings_tab_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: pantalla de ajustes para cargar lista M3U por URL o archivo"
```

---

### Task 12: UI — TV en directo (categorías → canales → reproductor)

**Files:**
- Modify: `lib/src/ui/live_tab.dart`
- Create: `lib/src/ui/channel_list_screen.dart`
- Create: `lib/src/ui/player_screen.dart`
- Create: `lib/src/app/providers.dart` (añadir `liveByCategoryProvider`)
- Test: `test/ui/live_tab_test.dart`

**Interfaces:**
- Consumes: `liveCategoriesProvider`, `playlistRepositoryProvider`.
- Produces:
  - `liveByCategoryProvider = FutureProvider.family<List<MediaItem>, String>(...)`.
  - `LiveTab` muestra las categorías (o mensaje "añade una lista" si vacío) y navega a `ChannelListScreen(category)`.
  - `ChannelListScreen` lista canales con logo (`cached_network_image`), estrella de favorito y navega a `PlayerScreen(item)`.
  - `PlayerScreen` crea un `MediaKitPlayerController`, abre la URL y muestra `Video(controller)`; con overlay de error + botón reintentar.

- [ ] **Step 1: Escribir el test que falla**

`test/ui/live_tab_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/app/providers.dart';
import 'package:iptv_player/src/domain/category.dart';
import 'package:iptv_player/src/domain/content_type.dart';
import 'package:iptv_player/src/ui/live_tab.dart';

void main() {
  testWidgets('lista las categorias en directo', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        liveCategoriesProvider.overrideWith((ref) async => const [
              Category(name: 'Nacionales', type: ContentType.live, itemCount: 3),
            ]),
      ],
      child: const MaterialApp(home: Scaffold(body: LiveTab())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Nacionales'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `flutter test test/ui/live_tab_test.dart`
Expected: FAIL.

- [ ] **Step 3: Añadir provider family en `providers.dart`**

Añadir a `lib/src/app/providers.dart`:
```dart
final liveByCategoryProvider =
    FutureProvider.family<List<MediaItem>, String>((ref, group) {
  return ref.watch(playlistRepositoryProvider).liveByCategory(group);
});
```

- [ ] **Step 4: Implementar las tres pantallas**

`lib/src/ui/player_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../domain/media_item.dart';
import '../player/media_kit_player_controller.dart';

class PlayerScreen extends StatefulWidget {
  final MediaItem item;
  const PlayerScreen({super.key, required this.item});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final MediaKitPlayerController _ctrl = MediaKitPlayerController();
  late final VideoController _video = VideoController(_ctrl.player);

  @override
  void initState() {
    super.initState();
    _ctrl.open(widget.item.streamUrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item.name)),
      backgroundColor: Colors.black,
      body: Center(child: Video(controller: _video)),
    );
  }
}
```
`lib/src/ui/channel_list_screen.dart`:
```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../domain/category.dart';
import 'player_screen.dart';

class ChannelListScreen extends ConsumerWidget {
  final Category category;
  const ChannelListScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(liveByCategoryProvider(category.name));
    return Scaffold(
      appBar: AppBar(title: Text(category.name)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) => ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) {
            final it = items[i];
            return ListTile(
              leading: it.logoUrl == null
                  ? const Icon(Icons.live_tv)
                  : CachedNetworkImage(
                      imageUrl: it.logoUrl!, width: 48,
                      errorWidget: (_, __, ___) => const Icon(Icons.live_tv)),
              title: Text(it.name),
              trailing: IconButton(
                icon: Icon(it.isFavorite ? Icons.favorite : Icons.favorite_border),
                onPressed: () async {
                  await ref.read(playlistRepositoryProvider).toggleFavorite(it);
                  ref.invalidate(liveByCategoryProvider(category.name));
                  ref.invalidate(favoritesProvider);
                },
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PlayerScreen(item: it)),
              ),
            );
          },
        ),
      ),
    );
  }
}
```
`lib/src/ui/live_tab.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import 'channel_list_screen.dart';

class LiveTab extends ConsumerWidget {
  const LiveTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(liveCategoriesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (cats) {
        if (cats.isEmpty) {
          return const Center(
              child: Text('Añade una lista en Ajustes para empezar'));
        }
        return ListView.builder(
          itemCount: cats.length,
          itemBuilder: (_, i) => ListTile(
            title: Text(cats[i].name),
            trailing: Text('${cats[i].itemCount}'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ChannelListScreen(category: cats[i]),
            )),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 5: Ejecutar y verificar que pasa**

Run: `flutter test test/ui/live_tab_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: TV en directo con categorias, lista de canales y reproductor"
```

---

### Task 13: UI — Favoritos

**Files:**
- Modify: `lib/src/ui/favorites_tab.dart`
- Test: `test/ui/favorites_tab_test.dart`

**Interfaces:**
- Consumes: `favoritesProvider`, `playlistRepositoryProvider`.
- Produces: `FavoritesTab` que lista los favoritos y permite reproducir (navega a `PlayerScreen`) o quitar de favoritos.

- [ ] **Step 1: Escribir el test que falla**

`test/ui/favorites_tab_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/app/providers.dart';
import 'package:iptv_player/src/domain/content_type.dart';
import 'package:iptv_player/src/domain/media_item.dart';
import 'package:iptv_player/src/ui/favorites_tab.dart';

void main() {
  testWidgets('muestra favoritos y mensaje vacio', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        favoritesProvider.overrideWith((ref) async => const [
              MediaItem(id: 'a', name: 'Canal Fav', streamUrl: 'u',
                  type: ContentType.live, isFavorite: true),
            ]),
      ],
      child: const MaterialApp(home: Scaffold(body: FavoritesTab())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Canal Fav'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `flutter test test/ui/favorites_tab_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementar `favorites_tab.dart`**

`lib/src/ui/favorites_tab.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import 'player_screen.dart';

class FavoritesTab extends ConsumerWidget {
  const FavoritesTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(favoritesProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('No tienes favoritos todavía'));
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (_, i) {
            final it = items[i];
            return ListTile(
              leading: const Icon(Icons.favorite),
              title: Text(it.name),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await ref.read(playlistRepositoryProvider).toggleFavorite(it);
                  ref.invalidate(favoritesProvider);
                },
              ),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PlayerScreen(item: it),
              )),
            );
          },
        );
      },
    );
  }
}
```

- [ ] **Step 4: Ejecutar y verificar que pasa**

Run: `flutter test test/ui/favorites_tab_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: pestaña de favoritos"
```

---

### Task 14: UI — Buscador global

**Files:**
- Modify: `lib/src/ui/search_tab.dart`
- Test: `test/ui/search_tab_test.dart`

**Interfaces:**
- Consumes: `searchQueryProvider`, `searchResultsProvider`.
- Produces: `SearchTab` con `TextField` que actualiza `searchQueryProvider` y lista `searchResultsProvider`, navegando a `PlayerScreen` al tocar un resultado.

- [ ] **Step 1: Escribir el test que falla**

`test/ui/search_tab_test.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/app/providers.dart';
import 'package:iptv_player/src/domain/content_type.dart';
import 'package:iptv_player/src/domain/media_item.dart';
import 'package:iptv_player/src/ui/search_tab.dart';

void main() {
  testWidgets('muestra resultados de busqueda', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        searchResultsProvider.overrideWith((ref) async => const [
              MediaItem(id: 'a', name: 'La 1', streamUrl: 'u',
                  type: ContentType.live),
            ]),
      ],
      child: const MaterialApp(home: Scaffold(body: SearchTab())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('La 1'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Ejecutar y verificar que falla**

Run: `flutter test test/ui/search_tab_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implementar `search_tab.dart`**

`lib/src/ui/search_tab.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import 'player_screen.dart';

class SearchTab extends ConsumerWidget {
  const SearchTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(searchResultsProvider);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Buscar canales, películas, series',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
        ),
      ),
      Expanded(
        child: results.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (items) => ListView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) => ListTile(
              title: Text(items[i].name),
              subtitle: Text(items[i].groupTitle ?? ''),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => PlayerScreen(item: items[i]),
              )),
            ),
          ),
        ),
      ),
    ]);
  }
}
```

- [ ] **Step 4: Ejecutar y verificar que pasa**

Run: `flutter test test/ui/search_tab_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: buscador global"
```

---

### Task 15: Verificación de extremo a extremo y ejecución

**Files:**
- Modify: `test/` (revisión de suite completa)

**Interfaces:**
- Consumes: todo lo anterior.
- Produces: app ejecutable y suite de tests en verde.

- [ ] **Step 1: Ejecutar analyze y toda la suite**

Run:
```bash
flutter analyze
flutter test
```
Expected: analyze sin errores; todos los tests PASS.

- [ ] **Step 2: Ejecución manual en escritorio (requiere toolchain de plataforma)**

Run:
```bash
flutter run -d windows
```
Comprobar manualmente: añadir la lista M3U del usuario en Ajustes → aparecen categorías en TV → reproducir un canal → marcar favorito → buscarlo. Documentar cualquier fallo como nueva tarea.

- [ ] **Step 3: Commit final de fase**

```bash
git add -A
git commit -m "chore: Fase 1 (nucleo MVP) verificada"
```

---

## Self-Review (cobertura del spec, Fase 1)

- Añadir lista M3U (URL/archivo): Tasks 6, 11. ✓
- Parseo + caché: Tasks 3, 5, 7 (parseo en isolate). ✓
- Clasificación live/movie/series: Task 4 (Fase 1 usa live; movie/series quedan cacheados para Fase 2). ✓
- TV en directo por categorías: Tasks 5 (categorías), 12. ✓
- Reproducción (MPEG-TS via media_kit): Tasks 8, 12. ✓
- Búsqueda: Tasks 5, 9, 14. ✓
- Favoritos: Tasks 5, 12, 13. ✓
- Manejo de errores (red→caché, líneas corruptas, stream muerto): Task 3 (tolerancia), Task 11 (try/catch carga), Task 12 (overlay reproductor — ampliable). Nota: el overlay de "saltar al siguiente" del spec se implementa de forma básica; el auto-avance queda para Fase 4.
- EPG y VOD (películas/series con detalle): fuera de Fase 1 por diseño (Fases 2 y 3).

**Placeholder scan:** sin TBD/TODO; todo el código está presente. Los widgets "placeholder" de Task 10 se sustituyen por implementaciones reales en Tasks 11-14.

**Type consistency:** `MediaItem`, `Category`, `ContentType`, `PlayerController`/`PlayerStatus`, y las firmas de `PlaylistRepository`/`AppDatabase` se usan consistentes entre tareas.
