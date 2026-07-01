# IPTV Player — Fase 2: Gestión de canales (ocultar/borrar)

**Goal:** Permitir ocultar y borrar canales (ambos persistentes, sobreviven al
refresco de la lista) con una pantalla de Gestión para restaurarlos. De paso,
preservar los flags de usuario (favorito/oculto/borrado) al recargar la lista.

**Arquitectura:** Se añaden dos flags persistidos (`isHidden`, `isDeleted`) al
modelo y a la tabla Drift (migración v1→v2). Las consultas de navegación
excluyen ocultos y borrados; la pantalla de Gestión los muestra para restaurar.
Al recargar la lista, `replaceItems` preserva los flags de los items existentes
por `id`.

## Global Constraints

- Mismos que Fase 1. `flutter test` en verde y commit por tarea.
- Migración Drift sin pérdida de datos (los flags nuevos por defecto a false).

---

### Task 1: Flags isHidden/isDeleted en el modelo

**Files:** Modify `lib/src/domain/media_item.dart`; Test `test/domain/media_item_test.dart`.

- Añadir `final bool isHidden; final bool isDeleted;` (default false) y ampliar
  `copyWith({bool? isFavorite, bool? isHidden, bool? isDeleted})`.
- Test: `copyWith(isHidden: true)` cambia solo ese flag.

### Task 2: Columnas y migración en Drift + preservación de flags

**Files:** Modify `lib/src/data/app_database.dart`; Test `test/data/app_database_test.dart`.

- Añadir columnas `isHidden`, `isDeleted` (bool, default false). `schemaVersion`
  = 2 con `MigrationStrategy.onUpgrade` que hace `m.addColumn`.
- `replaceItems`: antes de borrar, leer `{id: (isFavorite,isHidden,isDeleted)}`
  de los items actuales y reaplicarlos a los nuevos con el mismo id.
- Consultas de navegación (`itemsByType`, `categoriesByType`, `search`,
  `favorites`) excluyen `isHidden=true` y `isDeleted=true`.
- Nuevos métodos: `setHidden(id,bool)`, `setDeleted(id,bool)`,
  `restore(id)` (hidden=false,deleted=false),
  `manageableByType(type)` (todos, con flags),
  `categoriesByType(type, {onlyVisible})`.
- Tests: ocultar excluye de itemsByType; borrar excluye; manageableByType los
  incluye; replaceItems preserva favorito/oculto/borrado por id.

### Task 3: Métodos de gestión en el repositorio

**Files:** Modify `lib/src/data/playlist_repository.dart`; Test `test/data/playlist_repository_test.dart`.

- `hideItem(item)`, `deleteItem(item)`, `restoreItem(item)`.
- `manageCategories()` (live, incluye ocultos), `manageLiveByCategory(group)`
  (todos los de la categoría con su estado).
- Test: hideItem oculta y desaparece de liveByCategory pero sigue en
  manageLiveByCategory con isHidden=true.

### Task 4: Providers de gestión

**Files:** Modify `lib/src/app/providers.dart`.

- `manageCategoriesProvider`, `manageLiveByCategoryProvider.family`.

### Task 5: Acciones ocultar/borrar en las listas

**Files:** Modify `lib/src/ui/channel_list_screen.dart`; Test `test/ui/channel_list_actions_test.dart`.

- Menú contextual (PopupMenuButton) por canal: "Ocultar" y "Borrar", que llaman
  al repositorio e invalidan los providers de navegación.
- Test: pulsar "Ocultar" invoca `hideItem`.

### Task 6: Pantalla de Gestión

**Files:** Create `lib/src/ui/management_screen.dart`; Modify `lib/src/ui/settings_tab.dart`; Test `test/ui/management_screen_test.dart`.

- `ManagementScreen`: categorías → canales con chip de estado
  (Visible/Oculto/Borrado) y acciones (Ocultar/Borrar/Restaurar).
- Botón "Gestionar canales" en Ajustes que abre la pantalla.
- Test: muestra un canal oculto con su estado y permite restaurarlo.

### Task 7: Verificación

- `flutter analyze` limpio + `flutter test` en verde. Rebuild Release + parche
  libmpv. Commit de cierre de fase.
