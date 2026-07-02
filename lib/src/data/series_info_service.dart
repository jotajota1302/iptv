import 'dart:convert';
import 'package:dio/dio.dart';

/// Entrada del catálogo de series de la API Xtream (`get_series`).
class SeriesCatalogEntry {
  final String id;
  final String name;
  const SeriesCatalogEntry({required this.id, required this.name});
}

/// Un episodio según la API (`get_series_info`): imagen propia, título,
/// sinopsis y duración. Se indexa por el id del stream, que coincide con el
/// id que llevan las URLs de episodio del M3U.
class SeriesApiEpisode {
  final String id;
  final String? title;
  final String? plot;
  final String? image;
  final String? durationText;
  final int season;
  final int episodeNum;
  const SeriesApiEpisode({
    required this.id,
    this.title,
    this.plot,
    this.image,
    this.durationText,
    this.season = 0,
    this.episodeNum = 0,
  });
}

/// Ficha completa de una serie (`get_series_info`): metadatos + episodios.
class SeriesApiInfo {
  final String? plot;
  final String? cast;
  final String? director;
  final String? genre;
  final String? releaseDate;
  final String? rating;
  final String? cover;
  final String? backdrop;
  final Map<String, SeriesApiEpisode> episodesById;
  const SeriesApiInfo({
    this.plot,
    this.cast,
    this.director,
    this.genre,
    this.releaseDate,
    this.rating,
    this.cover,
    this.backdrop,
    this.episodesById = const {},
  });

  /// Año extraído de releaseDate (primer grupo de 4 dígitos plausible).
  String? get year {
    final m = RegExp(r'(19|20)\d{2}').firstMatch(releaseDate ?? '');
    return m?.group(0);
  }
}

/// Credenciales derivadas de una URL de stream Xtream
/// (`scheme://host:port/series/user/pass/id.ext`). Null si no encaja.
({Uri base, String user, String pass, String id})? _creds(String streamUrl) {
  final s = Uri.tryParse(streamUrl);
  if (s == null) return null;
  final segs = s.pathSegments;
  if (segs.length < 3) return null;
  final id = segs.last.split('.').first;
  final pass = segs[segs.length - 2];
  final user = segs[segs.length - 3];
  if (id.isEmpty || user.isEmpty || pass.isEmpty) return null;
  return (base: s, user: user, pass: pass, id: id);
}

/// URL del catálogo de series (`action=get_series`), derivada de la URL del
/// stream de cualquier episodio.
Uri? buildSeriesCatalogUrl(String streamUrl) {
  final c = _creds(streamUrl);
  if (c == null) return null;
  return Uri(
    scheme: c.base.scheme,
    host: c.base.host,
    port: c.base.hasPort ? c.base.port : null,
    path: '/player_api.php',
    queryParameters: {
      'username': c.user,
      'password': c.pass,
      'action': 'get_series',
    },
  );
}

/// URL de la ficha de una serie (`action=get_series_info&series_id=`).
Uri? buildSeriesInfoUrl(String streamUrl, String seriesId) {
  final c = _creds(streamUrl);
  if (c == null) return null;
  return Uri(
    scheme: c.base.scheme,
    host: c.base.host,
    port: c.base.hasPort ? c.base.port : null,
    path: '/player_api.php',
    queryParameters: {
      'username': c.user,
      'password': c.pass,
      'action': 'get_series_info',
      'series_id': seriesId,
    },
  );
}

/// Id del episodio a partir de su URL de stream (último segmento sin
/// extensión). Cadena vacía si la URL no es válida.
String episodeIdFromUrl(String streamUrl) {
  final s = Uri.tryParse(streamUrl);
  if (s == null || s.pathSegments.isEmpty) return '';
  return s.pathSegments.last.split('.').first;
}

String _normalizeTitle(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9áéíóúüñ]+'), ' ').trim();

/// Busca el `series_id` cuyo nombre casa con [title]: primero igualdad
/// normalizada, después un único candidato por prefijo (el catálogo suele
/// añadir sufijos tipo "(ES)" o el año).
String? matchSeriesId(List<SeriesCatalogEntry> catalog, String title) {
  final t = _normalizeTitle(title);
  if (t.isEmpty) return null;
  for (final e in catalog) {
    if (_normalizeTitle(e.name) == t) return e.id;
  }
  final byPrefix = catalog
      .where((e) =>
          _normalizeTitle(e.name).startsWith('$t ') ||
          t.startsWith('${_normalizeTitle(e.name)} '))
      .toList();
  if (byPrefix.length == 1) return byPrefix.first.id;
  return null;
}

/// Parsea la respuesta de `get_series` (lista de series con id y nombre).
List<SeriesCatalogEntry> parseSeriesCatalog(dynamic json) {
  if (json is! List) return const [];
  final out = <SeriesCatalogEntry>[];
  for (final e in json) {
    if (e is! Map) continue;
    final id = '${e['series_id'] ?? ''}';
    final name = '${e['name'] ?? ''}';
    if (id.isEmpty || name.isEmpty) continue;
    out.add(SeriesCatalogEntry(id: id, name: name));
  }
  return out;
}

String? _str(Map info, String k) {
  final v = info[k];
  if (v == null) return null;
  final s = v is List ? (v.isEmpty ? '' : '${v.first}') : '$v';
  return s.trim().isEmpty ? null : s.trim();
}

int _asInt(dynamic v) => v is int ? v : (int.tryParse('${v ?? ''}') ?? 0);

/// Parsea la respuesta de `get_series_info`: ficha (`info`) y episodios
/// (`episodes`, que puede venir como mapa temporada→lista o lista de listas).
SeriesApiInfo? parseSeriesInfo(Map<String, dynamic> json) {
  final info = json['info'];
  final i = info is Map ? info : const {};

  final episodes = <String, SeriesApiEpisode>{};
  final rawEpisodes = json['episodes'];
  final seasonLists = rawEpisodes is Map
      ? rawEpisodes.values
      : (rawEpisodes is List ? rawEpisodes : const []);
  for (final list in seasonLists) {
    if (list is! List) continue;
    for (final e in list) {
      if (e is! Map) continue;
      final id = '${e['id'] ?? ''}';
      if (id.isEmpty) continue;
      final ei = e['info'];
      final eInfo = ei is Map ? ei : const {};
      episodes[id] = SeriesApiEpisode(
        id: id,
        title: _str(e, 'title'),
        plot: _str(eInfo, 'plot'),
        image: _str(eInfo, 'movie_image'),
        durationText: _str(eInfo, 'duration'),
        season: _asInt(e['season']),
        episodeNum: _asInt(e['episode_num']),
      );
    }
  }

  return SeriesApiInfo(
    plot: _str(i, 'plot') ?? _str(i, 'description'),
    cast: _str(i, 'cast') ?? _str(i, 'actors'),
    director: _str(i, 'director'),
    genre: _str(i, 'genre'),
    releaseDate: _str(i, 'releaseDate') ?? _str(i, 'release_date'),
    rating: _str(i, 'rating'),
    cover: _str(i, 'cover'),
    backdrop: _str(i, 'backdrop_path'),
    episodesById: episodes,
  );
}

/// Convierte la duración `HH:MM:SS` de la API a texto legible ("58 min",
/// "1 h 30 min"). Null si el formato no encaja.
String? formatEpisodeDuration(String? durationText) {
  if (durationText == null) return null;
  final m = RegExp(r'^(\d{1,2}):(\d{2}):(\d{2})$').firstMatch(durationText);
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  if (h <= 0 && min <= 0) return null;
  if (h <= 0) return '$min min';
  return min > 0 ? '$h h $min min' : '$h h';
}

/// Obtiene la ficha de una serie casando su título contra el catálogo
/// `get_series` (cacheado por credenciales) y pidiendo `get_series_info`.
/// Best-effort: null ante cualquier error de red o si no hay match.
class SeriesInfoService {
  final Dio _dio;
  final Map<String, Future<List<SeriesCatalogEntry>>> _catalogCache = {};

  SeriesInfoService([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
            ));

  Future<SeriesApiInfo?> fetchForSeries(
      String episodeStreamUrl, String seriesTitle) async {
    try {
      final catalogUrl = buildSeriesCatalogUrl(episodeStreamUrl);
      if (catalogUrl == null) return null;
      final catalog = await _catalog(catalogUrl);
      final seriesId = matchSeriesId(catalog, seriesTitle);
      if (seriesId == null) return null;
      final infoUrl = buildSeriesInfoUrl(episodeStreamUrl, seriesId);
      if (infoUrl == null) return null;
      final map = await _getJson(infoUrl);
      if (map is! Map<String, dynamic>) return null;
      return parseSeriesInfo(map);
    } catch (_) {
      return null;
    }
  }

  /// Catálogo por credenciales, cacheado en memoria (una petición por sesión
  /// y servidor). Si la petición falla, se limpia para reintentar después.
  Future<List<SeriesCatalogEntry>> _catalog(Uri url) {
    final key = url.replace(queryParameters: {
      'username': url.queryParameters['username'] ?? '',
    }).toString();
    return _catalogCache[key] ??= _getJson(url).then((data) {
      return parseSeriesCatalog(data);
    }).catchError((Object _) {
      _catalogCache.remove(key);
      return const <SeriesCatalogEntry>[];
    });
  }

  Future<dynamic> _getJson(Uri url) async {
    final resp = await _dio.getUri<dynamic>(url);
    final data = resp.data;
    if (data is String && data.isNotEmpty) return jsonDecode(data);
    return data;
  }
}
