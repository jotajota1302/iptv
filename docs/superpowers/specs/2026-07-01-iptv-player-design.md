# Diseño: Reproductor de listas IPTV (multiplataforma)

- **Fecha:** 2026-07-01
- **Estado:** Aprobado (pendiente de revisión del usuario sobre el documento)
- **Plataformas objetivo:** Android, iOS, Windows (móvil + escritorio con una sola base de código)

## 1. Resumen

App multiplataforma para cargar listas IPTV en formato **M3U / M3U8** (por URL o archivo
local) y reproducir TV en directo, películas (VOD) y series. Incluye buscador global,
favoritos y guía de programación (EPG) opcional.

La lista de referencia del usuario es de tipo `m3u_plus` con `output=ts` (streams
MPEG-TS servidos por un backend Xtream mediante `get.php`), que mezcla en un mismo archivo
canales en directo, películas y series.

## 2. Stack tecnológico

- **Framework:** Flutter (una base de código para móvil y escritorio).
- **Reproductor:** `media_kit` + `media_kit_video` (motor libmpv). Reproduce MPEG-TS/HLS
  y prácticamente cualquier códec, lo cual es crítico dado el `output=ts` de la lista.
- **Estado:** `flutter_riverpod`.
- **Persistencia:** `drift` (SQLite) — búsqueda indexada sobre listas de miles de entradas.
- **Red:** `dio`.
- **EPG:** `xml` (parseo XMLTV, con soporte gzip).
- **Otros:** `file_picker`, `flutter_secure_storage` (credenciales de la URL),
  `cached_network_image` (logos/carátulas).

### Enfoques considerados

| Enfoque | Ventaja | Inconveniente |
|---|---|---|
| **A. Capas + Riverpod + SQLite (elegido)** | Separación limpia, búsqueda rápida, testeable | Más andamiaje inicial |
| B. Widgets + setState | Rápido de arrancar | No escala a EPG/VOD/miles de ítems; poco testeable |
| C. Bloc en vez de Riverpod | Muy estructurado | Más verboso para este tamaño |

## 3. Arquitectura por capas

```
UI (pantallas + widgets, layout adaptativo móvil/escritorio)
        ^ Riverpod providers
Dominio (Channel, Movie, Series, Episode, Category, EpgProgram)
        ^
Repositorios (Playlist, Favorites, Epg, Player)
        ^
Fuentes de datos            Persistencia (Drift/SQLite)
- M3uSource (URL/archivo)    - cache de canales, favoritos,
- XmltvSource (EPG)            posicion de reproduccion, config
- Almacenamiento seguro (credenciales de la URL)
```

### Módulos (una sola responsabilidad, testeables por separado)

- **`m3u_parser`**: texto M3U -> entradas (`tvg-id`, `tvg-name`, `tvg-logo`,
  `group-title`, url, nombre). Tolerante a líneas mal formadas (las ignora y registra).
- **`content_classifier`**: clasifica cada entrada en **Live / Película / Serie** usando el
  segmento de la URL Xtream (`/live/`, `/movie/`, `/series/`) y el `group-title`.
- **`series_grouper`**: agrupa episodios por patrón `SxxEyy` en Serie -> Temporadas ->
  Episodios.
- **`xmltv_parser`**: descarga y parsea EPG (XMLTV, soporta gzip) y lo enlaza a canales por
  `tvg-id`.
- **`player_controller`**: envuelve media_kit (play/pause/seek, pistas de audio/subtítulos,
  reintento). Live = sin barra de tiempo; VOD = controles completos + reanudar posición.

## 4. Modelo de dominio (borrador)

- `Playlist` — id, nombre, url o ruta de archivo, url de EPG opcional, fecha de refresco.
- `Category` — id, nombre, tipo (live/movie/series).
- `Channel` — id, nombre, logo, tvgId, url, categoría, favorito.
- `Movie` — id, título, carátula, url, categoría, posición de reproducción.
- `Series` / `Season` / `Episode` — jerarquía; el episodio lleva url y posición.
- `EpgProgram` — tvgId, título, inicio, fin, descripción.

## 5. Flujo de datos

1. El usuario añade una playlist (URL o archivo) -> `M3uSource` descarga con Dio.
2. Parseo **en un isolate** (evita congelar la UI con miles de líneas) -> clasificación ->
   agrupado de series.
3. Se cachea en SQLite (Drift). Aperturas siguientes = instantáneas desde caché; refresco
   manual o periódico.
4. La UI lee vía providers. Búsqueda y favoritos consultan SQLite (indexado).
5. Al reproducir, `player_controller` recibe la URL del stream; overlay muestra
   "ahora/después" si hay EPG.

## 6. Pantallas

Navegación adaptativa: `NavigationBar` en móvil, `NavigationRail` en escritorio.

- **Onboarding / Añadir lista**: campo URL, selector de archivo, URL de EPG opcional.
- **TV en directo**: categorías -> lista de canales (logo + nombre + ahora/después) ->
  reproductor.
- **Películas**: categorías -> grid de carátulas -> detalle -> reproductor con reanudar.
- **Series**: grid -> detalle con temporadas/episodios -> reproductor.
- **Favoritos**.
- **Buscador global** (canales + películas + series).
- **Ajustes**: gestionar listas, URL de EPG, preferencias de reproductor, refrescar.

## 7. Manejo de errores

- Fallo de red al cargar lista -> usar caché + banner de aviso.
- Stream muerto (frecuente en IPTV) -> overlay con **reintentar** y opción de "saltar al
  siguiente".
- Líneas M3U corruptas -> se ignoran y se registran, sin crashear.
- Logos/carátulas -> carga perezosa con placeholder.

## 8. EPG

El M3U no incluye la guía, solo referencias `tvg-id`. La EPG se trae de un XMLTV aparte.
En proveedores Xtream suele estar en `.../xmltv.php?username=...&password=...` (misma base
que `get.php`). La app **deriva automáticamente** esa URL a partir de la de la lista; si no
responde, la app funciona igual sin guía. El usuario también puede indicar una URL de EPG
manualmente en Ajustes.

## 9. Seguridad y privacidad

- Las credenciales incrustadas en la URL de la lista se guardan con `flutter_secure_storage`.
- Todo el procesamiento es local; no se envían datos a terceros.

## 10. Pruebas

- Unitarias: `m3u_parser`, `content_classifier`, `series_grouper`, `xmltv_parser` (casos
  límite reales de listas `m3u_plus`).
- Repositorios: con fuentes de datos simuladas.
- Widget tests: pantallas principales.
- El reproductor (media_kit) se aísla tras una interfaz para poder testear la lógica del
  controlador con mocks.

## 11. Plan por fases

El diseño contempla todo; la construcción es incremental.

- **Fase 1 - Núcleo MVP**: añadir lista M3U (URL/archivo), parseo + caché, TV en directo por
  categorías, reproducción, búsqueda, favoritos.
- **Fase 2 - VOD**: películas y series (agrupado, detalle, reanudar).
- **Fase 3 - EPG**: XMLTV, ahora/después y guía.
- **Fase 4 - Pulido**: multi-lista, selección de pistas de audio/subtítulos, layout de
  escritorio refinado.

## 12. Fuera de alcance (por ahora)

- Xtream Codes API nativa (login estructurado) — se usa solo el M3U que expone.
- Portales Stalker / MAC.
- Grabación (DVR) y catch-up.
- Casting (Chromecast/AirPlay).
