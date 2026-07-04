# Ordenación por nombre y año (asc/desc) en agrupaciones VOD

Fecha: 2026-07-04

## Problema

En las agrupaciones de películas y series, el usuario no puede ordenar por
fecha, y el modo "Recién añadido" no ordena de forma útil.

Causa raíz investigada:

1. **`addedAt` no es una fecha de estreno.** Es el instante en que la app
   cacheó el item en la BD local (`app_database.dart:80`), calculado **una sola
   vez por importación**. En la primera importación de una lista, todos los
   items reciben el mismo timestamp → al ordenar por "Recién añadido" todo queda
   empatado y no se mueve nada.
2. **La lista M3U no trae fecha real.** Se descarga como texto
   (`get.php?type=m3u_plus`) y el parser solo lee `tvg-id` y `tvg-logo`
   (`m3u_parser.dart`). No hay fecha de estreno ni de alta en el catálogo.
3. **Las series no tienen fecha.** `SeriesGroup` (`series_group.dart`) no guarda
   ninguna marca temporal; la cuadrícula de series solo ordena por nombre.

## Decisiones tomadas

- "Ordenar por fecha" = **fecha de estreno real**, obtenida del **año presente
  en el propio título** del proveedor (p. ej. `Oppenheimer (2023)`). Es la única
  fuente que permite ordenar una categoría entera al instante y sin red. Xtream
  `get_vod_info` y TMDB dan la fecha real exacta pero son una petición por
  película → inviable para ordenar la cuadrícula completa.
- Los items **sin año** en el título se ordenan **al final**, en ambos sentidos.
- Se **elimina** "Recién añadido" de las agrupaciones VOD. Solo quedan **Nombre**
  y **Año**, ambos ascendente y descendente.
- Los canales (Live TV) **no se tocan**: conservan sus modos actuales
  (Recién añadido, Favoritos primero, Personalizado).

## Diseño

### 1. Origen del año (sin migración de BD)

El año se deriva del título con la misma regex que ya existe
(`yearFromName` en `tmdb_service.dart:82`). Se expone como getter en el dominio:

```dart
// domain/media_item.dart
/// Año de estreno tomado del título del proveedor ("Peli (2023)").
/// 0 = desconocido.
int get releaseYear { ... } // RegExp(r'\(((19|20)\d{2})\)')
```

No se añade columna a la BD ni migración: es parseo puro de string, instantáneo
sobre miles de items al ordenar.

### 2. Modo de orden VOD aislado del de canales

El modo de orden actual (`sortModeProvider`) es **global y compartido** con la
pantalla de canales. Para no ensuciar esa pantalla, se crea un provider
**propio para VOD**, compartido por películas y series:

```dart
// app/providers.dart
final vodSortModeProvider = StateProvider<SortMode>((ref) {
  final i = ref.watch(sharedPrefsProvider).getInt('vod_sort_mode') ?? 0;
  return SortMode.values[i.clamp(0, SortMode.values.length - 1)];
});
void setVodSortMode(WidgetRef ref, SortMode mode) { ... } // persiste 'vod_sort_mode'
```

Los canales siguen usando `sortModeProvider` sin cambios.

### 3. Enum y helpers de orden

```dart
// domain/sort_mode.dart
enum SortMode {
  nameAsc('Nombre A-Z'),
  nameDesc('Nombre Z-A'),
  yearDesc('Año — nuevas primero'),   // NUEVO
  yearAsc('Año — antiguas primero'),  // NUEVO
  recent('Recién añadido'),
  favFirst('Favoritos primero'),
  custom('Personalizado');
  ...
}
```

- `sortItems(...)` gana los casos `yearDesc`/`yearAsc`. Regla de desconocidos:
  un item con `releaseYear == 0` va **siempre al final**, independientemente del
  sentido (no se cuela al principio en ascendente).
- Nuevo helper `sortSeriesGroups(List<SeriesGroup>, SortMode)` con la misma
  lógica (nombre y año, desconocido al final), para unificar el orden de series.

### 4. SeriesGroup con año

```dart
// domain/series_group.dart
/// Año de estreno de la serie: el mayor entre los años de sus episodios.
/// 0 = desconocido.
int get year { ... } // max de releaseYear de los episodios; 0 si ninguno
```

### 5. Menú de orden contextual

`SortMenu` se generaliza para aceptar **qué modos mostrar** y **sobre qué
provider** actuar, en vez de asumir el provider global y filtrar solo `custom`:

- Pelis/series: modos `[nameAsc, nameDesc, yearDesc, yearAsc]`, sobre
  `vodSortModeProvider`.
- Canales: sus modos actuales, sobre `sortModeProvider` (comportamiento intacto).

### 6. Pantallas

- `movie_grid_screen.dart`: leer `vodSortModeProvider`, ordenar con `sortItems`,
  usar el `SortMenu` configurado para VOD.
- `series_grid_screen.dart`: reemplazar el orden inline (solo nombre) por
  `sortSeriesGroups(...)` con `vodSortModeProvider` y el `SortMenu` VOD.

## Archivos afectados

- `lib/src/domain/media_item.dart` — getter `releaseYear`.
- `lib/src/domain/series_group.dart` — getter `year`.
- `lib/src/domain/sort_mode.dart` — `yearDesc`/`yearAsc`, desconocido al final,
  `sortSeriesGroups`.
- `lib/src/app/providers.dart` — `vodSortModeProvider` + `setVodSortMode`.
- `lib/src/ui/sort_menu.dart` — modos y provider configurables.
- `lib/src/ui/movie_grid_screen.dart` — usar orden/menú VOD.
- `lib/src/ui/series_grid_screen.dart` — usar `sortSeriesGroups` y menú VOD.

## Fuera de alcance

- Enriquecer con fecha real de Xtream/TMDB para los items sin año en el título.
- El bug del responsive del título en el detalle de película (tarea aparte).
- Cambiar el comportamiento del orden de canales.

## Pruebas

- Unit test de `releaseYear`: títulos con `(2023)`, sin año, con corchetes/
  prefijos de país → año correcto o 0.
- Unit test de `sortItems` en `yearDesc`/`yearAsc`: orden correcto y items con
  año 0 siempre al final en ambos sentidos.
- Unit test de `SeriesGroup.year` y `sortSeriesGroups`.
