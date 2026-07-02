import 'package:dio/dio.dart';

/// Cliente de la API de TMDB (themoviedb.org) para reparto y fichas de
/// actores. Uso no comercial con atribución; para la versión de pago hará
/// falta su licencia business (ver docs/RELEASING.md y memoria comercial).
const _imgBase = 'https://image.tmdb.org/t/p';

String? _img(String? path, String size) =>
    (path == null || path.isEmpty) ? null : '$_imgBase/$size$path';

/// Miembro del reparto de una película/serie.
class TmdbCastMember {
  final int id;
  final String name;
  final String? character;
  final String? profileUrl;
  const TmdbCastMember({
    required this.id,
    required this.name,
    this.character,
    this.profileUrl,
  });
}

/// Ficha de una persona (actor/actriz, director...).
class TmdbPerson {
  final int id;
  final String name;
  final String? biography;
  final String? birthday; // 'YYYY-MM-DD'
  final String? deathday;
  final String? placeOfBirth;
  final String? profileUrl;
  const TmdbPerson({
    required this.id,
    required this.name,
    this.biography,
    this.birthday,
    this.deathday,
    this.placeOfBirth,
    this.profileUrl,
  });
}

/// Título de la filmografía de una persona.
class TmdbCredit {
  final int id;
  final String title;
  final String mediaType; // 'movie' | 'tv'
  final String? year;
  final String? character;
  final String? posterUrl;
  final double popularity;
  const TmdbCredit({
    required this.id,
    required this.title,
    required this.mediaType,
    this.year,
    this.character,
    this.posterUrl,
    this.popularity = 0,
  });
}

/// Quita del nombre del proveedor los adornos que rompen la búsqueda en TMDB:
/// prefijos de país ("ES| "), etiquetas ("[4K]"), año entre paréntesis y
/// marcas de calidad/idioma sueltas.
String cleanMediaTitle(String raw) {
  var s = raw;
  s = s.replaceAll(RegExp(r'\[[^\]]*\]'), ' ');
  s = s.replaceFirst(RegExp(r'^\s*[A-Z]{2,4}\s*[|:\-]\s*'), '');
  s = s.replaceAll(RegExp(r'\((19|20)\d{2}\)'), ' ');
  s = s.replaceAll(
      RegExp(r'\b(4K|UHD|FHD|HD|SD|HDR|H26[45]|X26[45]|MULTI|MULTiSUBS?|LATINO|CASTELLANO|VOSE|DUAL|SUBS?)\b',
          caseSensitive: false),
      ' ');
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Año que el proveedor mete en el propio nombre ("Película (2023)").
String? yearFromName(String raw) =>
    RegExp(r'\(((19|20)\d{2})\)').firstMatch(raw)?.group(1);

List<TmdbCastMember> parseCast(dynamic json) {
  final cast = json is Map ? json['cast'] : null;
  if (cast is! List) return const [];
  final out = <TmdbCastMember>[];
  for (final c in cast) {
    if (c is! Map) continue;
    final id = c['id'];
    final name = '${c['name'] ?? ''}';
    if (id is! int || name.isEmpty) continue;
    // En películas viene 'character'; en series (aggregate_credits) viene
    // una lista 'roles' con los personajes por temporada.
    var character = '${c['character'] ?? ''}';
    if (character.isEmpty) {
      final roles = c['roles'];
      if (roles is List && roles.isNotEmpty && roles.first is Map) {
        character = '${(roles.first as Map)['character'] ?? ''}';
      }
    }
    out.add(TmdbCastMember(
      id: id,
      name: name,
      character: character.isEmpty ? null : character,
      profileUrl: _img(c['profile_path'] as String?, 'w185'),
    ));
  }
  return out;
}

TmdbPerson? parsePerson(dynamic json) {
  if (json is! Map) return null;
  final id = json['id'];
  final name = '${json['name'] ?? ''}';
  if (id is! int || name.isEmpty) return null;
  String? str(String k) {
    final s = '${json[k] ?? ''}'.trim();
    return s.isEmpty ? null : s;
  }

  return TmdbPerson(
    id: id,
    name: name,
    biography: str('biography'),
    birthday: str('birthday'),
    deathday: str('deathday'),
    placeOfBirth: str('place_of_birth'),
    profileUrl: _img(json['profile_path'] as String?, 'w342'),
  );
}

/// Filmografía de `combined_credits`: sin duplicados, ordenada de más nueva
/// a más vieja (sin fecha al final).
List<TmdbCredit> parseCombinedCredits(dynamic json) {
  final cast = json is Map ? json['cast'] : null;
  if (cast is! List) return const [];
  final seen = <String>{};
  final out = <TmdbCredit>[];
  for (final c in cast) {
    if (c is! Map) continue;
    final id = c['id'];
    final type = '${c['media_type'] ?? ''}';
    if (id is! int || (type != 'movie' && type != 'tv')) continue;
    if (!seen.add('$type:$id')) continue;
    final title = '${(type == 'movie' ? c['title'] : c['name']) ?? ''}';
    if (title.isEmpty) continue;
    final date =
        '${(type == 'movie' ? c['release_date'] : c['first_air_date']) ?? ''}';
    final character = '${c['character'] ?? ''}';
    out.add(TmdbCredit(
      id: id,
      title: title,
      mediaType: type,
      year: date.length >= 4 ? date.substring(0, 4) : null,
      character: character.isEmpty ? null : character,
      posterUrl: _img(c['poster_path'] as String?, 'w342'),
      popularity: (c['popularity'] as num?)?.toDouble() ?? 0,
    ));
  }
  out.sort((a, b) => (b.year ?? '').compareTo(a.year ?? ''));
  return out;
}

class TmdbService {
  /// API key v3 (hex corto) o Read Access Token v4 (JWT con puntos).
  final String credential;
  final Dio _dio;

  TmdbService({required this.credential, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: 'https://api.themoviedb.org/3',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ));

  Future<dynamic> _get(String path, Map<String, String> params) async {
    final isV4 = credential.contains('.');
    final resp = await _dio.get<dynamic>(
      path,
      queryParameters: {if (!isV4) 'api_key': credential, ...params},
      options: isV4
          ? Options(headers: {'Authorization': 'Bearer $credential'})
          : null,
    );
    return resp.data;
  }

  Future<int?> _searchId(String kind, String title, String? year) async {
    final data = await _get('/search/$kind', {
      'query': title,
      'language': 'es-ES',
      (kind == 'movie' ? 'year' : 'first_air_date_year'): ?year,
    });
    final results = data is Map ? data['results'] : null;
    if (results is! List || results.isEmpty) return null;
    final first = results.first;
    return first is Map && first['id'] is int ? first['id'] as int : null;
  }

  /// Reparto de una película. Con [tmdbId] del proveedor se ahorra la
  /// búsqueda; si no, busca por título limpio (+año si se conoce).
  Future<List<TmdbCastMember>> movieCast(
      {String? tmdbId, required String title, String? year}) async {
    var id = int.tryParse(tmdbId ?? '');
    id ??= await _searchId('movie', title, year);
    if (id == null) return const [];
    return parseCast(await _get('/movie/$id/credits', {'language': 'es-ES'}));
  }

  /// Reparto de una serie (créditos agregados de todas las temporadas).
  Future<List<TmdbCastMember>> tvCast(
      {String? tmdbId, required String title, String? year}) async {
    var id = int.tryParse(tmdbId ?? '');
    id ??= await _searchId('tv', title, year);
    if (id == null) return const [];
    return parseCast(
        await _get('/tv/$id/aggregate_credits', {'language': 'es-ES'}));
  }

  /// Ficha de la persona en español; si la bio en español está vacía, cae a
  /// la bio en inglés (mejor algo que nada).
  Future<TmdbPerson?> person(int id) async {
    final es = parsePerson(await _get('/person/$id', {'language': 'es-ES'}));
    if (es == null || (es.biography ?? '').isNotEmpty) return es;
    final en = parsePerson(await _get('/person/$id', {'language': 'en-US'}));
    return en == null
        ? es
        : TmdbPerson(
            id: es.id,
            name: es.name,
            biography: en.biography,
            birthday: es.birthday,
            deathday: es.deathday,
            placeOfBirth: es.placeOfBirth,
            profileUrl: es.profileUrl,
          );
  }

  Future<List<TmdbCredit>> personCredits(int id) async {
    return parseCombinedCredits(
        await _get('/person/$id/combined_credits', {'language': 'es-ES'}));
  }
}
