# IPTV Player — Fase 3: VOD (Películas y Series)

**Goal:** Añadir Películas y Series como dos pestañas separadas, con series
agrupadas en Serie → Temporadas → Episodios, y reanudar reproducción (guardar
posición) en el contenido VOD.

**Estado decidido (aprobado por el usuario):**
- Dos pestañas separadas: Películas y Series.
- Series agrupadas (parseo SxxEyy / NxM).
- Reanudar reproducción: sí (guardar posición y continuar).

## Global Constraints
- Mismos que fases anteriores. `flutter test` en verde + commit por tarea.
- Migración Drift sin pérdida de datos. Tras cada build de Windows: `bash
  tool/patch_libmpv.sh`.
- Las consultas por tipo ya excluyen ocultos/borrados (reutilizar).

---

### Task 1: BD — posición de reproducción (reanudar) + migración v2→v3
**Files:** Modify `lib/src/data/app_database.dart`; Test `test/data/app_database_test.dart`.
- Añadir columna `positionSeconds` (int, default 0). `schemaVersion = 3`;
  `onUpgrade`: si `from < 3` → `m.addColumn(items, items.positionSeconds)`.
- `replaceItems`: preservar también `positionSeconds` por id (junto a los flags).
- Métodos: `setPosition(String id, int seconds)`, `getPosition(String id)`.
- `_map` incluye `positionSeconds` en `MediaItem`.
- Ampliar `MediaItem` con `final int positionSeconds` (default 0) y en `copyWith`.
- Tests: setPosition/getPosition; preservación de positionSeconds al recargar.

### Task 2: Modelo y agrupador de series
**Files:** Create `lib/src/domain/series_group.dart`, `lib/src/data/series_grouper.dart`; Test `test/data/series_grouper_test.dart`.
- `class Episode { final MediaItem item; final int season; final int episode; }`
- `class SeriesGroup { final String title; final String? poster; final Map<int, List<Episode>> seasons; }` con getter `sortedSeasons`.
- `List<SeriesGroup> groupSeries(List<MediaItem> items)`:
  - Regex `S(\d{1,3})\s*E(\d{1,3})` y `(\d{1,2})x(\d{1,3})` (case-insensitive).
  - title = nombre recortado antes del patrón (trim de separadores `-`, `:`).
  - Sin patrón → season 0 (episodio suelto), título = nombre completo.
  - Agrupa por title (normalizado), luego por season; poster = primer logo no nulo.
  - Ordena series por título y episodios por número.
- Tests: agrupa 3 episodios de 2 temporadas de una serie; formato `1x02`; sin patrón.

### Task 3: Providers de VOD
**Files:** Modify `lib/src/app/providers.dart`.
- `movieCategoriesProvider` = categoriesByType(movie).
- `moviesByCategoryProvider.family(group)` = items movie de esa categoría.
- `seriesCategoriesProvider` = categoriesByType(series).
- `seriesGroupsByCategoryProvider.family(group)` = groupSeries(items series de la
  categoría) (deriva del repo).
- Repo: `movieCategories()`, `moviesByCategory(group)`, `seriesCategories()`,
  `seriesByCategory(group)`; añadir `saveProgress(id, seconds)` /
  `progress(id)`.

### Task 4: PlayerScreen con reanudar
**Files:** Modify `lib/src/ui/player_screen.dart`.
- Añadir `final bool resume;` (default false). TV pasa false; VOD true.
- Si `resume` y hay posición guardada > 5s y < (duración - 30s): al empezar,
  `player.seek(Duration(seconds: pos))`.
- Suscribirse a `player.stream.position`; guardar cada ~10s (throttle) y en
  `dispose` la última posición vía `repo.saveProgress(item.id, seconds)`.
- No romper el uso actual (preview y TV siguen con resume=false).

### Task 5: Pestaña Películas
**Files:** Create `lib/src/ui/movies_tab.dart`, `lib/src/ui/movie_grid_screen.dart`; Test `test/ui/movies_tab_test.dart`.
- `MoviesTab`: categorías (reutiliza estilo cuadrícula/lista) →
  `MovieGridScreen(category)`.
- `MovieGridScreen`: cuadrícula de carátulas (poster 2:3 desde `logoUrl`,
  fallback icono), tocar → `PlayerScreen(item, resume: true)`.
- Test: muestra una categoría de películas.

### Task 6: Pestaña Series (detalle temporadas/episodios)
**Files:** Create `lib/src/ui/series_tab.dart`, `lib/src/ui/series_grid_screen.dart`, `lib/src/ui/series_detail_screen.dart`; Test `test/ui/series_detail_test.dart`.
- `SeriesTab`: categorías → `SeriesGridScreen(category)`.
- `SeriesGridScreen`: cuadrícula de series (carátula + título) → `SeriesDetailScreen(series)`.
- `SeriesDetailScreen`: `ExpansionTile` por temporada con lista de episodios →
  tocar episodio → `PlayerScreen(item, resume: true)`.
- Test: el detalle muestra temporadas y episodios de un SeriesGroup.

### Task 7: Integrar en la barra de navegación
**Files:** Modify `lib/src/ui/app_shell.dart`; Test `test/ui/app_shell_test.dart`.
- Destinos: TV, Películas, Series, Favoritos, Buscar, Ajustes (iconos:
  live_tv, movie, theaters, favorite, search, settings).
- Test: aparecen los 6 destinos.

### Task 8: Verificación
- `flutter analyze` limpio + `flutter test` en verde. Rebuild Release + parche
  libmpv. Commit de cierre de fase.

## Self-review
- Menús separados: Task 5,6,7. Series agrupadas: Task 2,6. Reanudar: Task 1,4.
- Ocultos/borrados en VOD: fuera de alcance de esta fase (queda para iteración).
