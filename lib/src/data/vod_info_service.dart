import 'dart:convert';
import 'package:dio/dio.dart';

/// Ficha de una película (metadatos de la API Xtream `get_vod_info`).
class VodInfo {
  final String? plot;
  final String? cast;
  final String? director;
  final String? genre;
  final String? releaseDate;
  final String? rating;
  final String? durationText;
  final String? cover;
  final String? backdrop;
  final String? youtubeTrailer;
  const VodInfo({
    this.plot,
    this.cast,
    this.director,
    this.genre,
    this.releaseDate,
    this.rating,
    this.durationText,
    this.cover,
    this.backdrop,
    this.youtubeTrailer,
  });

  bool get isEmpty =>
      (plot ?? '').isEmpty &&
      (genre ?? '').isEmpty &&
      (cast ?? '').isEmpty &&
      (releaseDate ?? '').isEmpty;

  /// Año extraído de releaseDate (formato YYYY-MM-DD u otro con 4 dígitos).
  String? get year {
    final m = RegExp(r'(19|20)\d{2}').firstMatch(releaseDate ?? '');
    return m?.group(0);
  }
}

/// Construye la URL Xtream `get_vod_info` a partir de la URL del stream de la
/// película: `scheme://host:port/movie/user/pass/vodId.ext`.
Uri? buildVodInfoUrl(String streamUrl) {
  final s = Uri.tryParse(streamUrl);
  if (s == null) return null;
  final segs = s.pathSegments;
  if (segs.length < 3) return null;
  final vodId = segs.last.split('.').first;
  final pass = segs[segs.length - 2];
  final user = segs[segs.length - 3];
  if (vodId.isEmpty || user.isEmpty || pass.isEmpty) return null;
  return Uri(
    scheme: s.scheme,
    host: s.host,
    port: s.hasPort ? s.port : null,
    path: '/player_api.php',
    queryParameters: {
      'username': user,
      'password': pass,
      'action': 'get_vod_info',
      'vod_id': vodId,
    },
  );
}

/// Normaliza la imagen de fondo que devuelve el proveedor: muchos paneles
/// mandan la ruta relativa de TMDB ("/abc.jpg") en vez de una URL completa,
/// y entonces no se veía nada. Devuelve null si no hay nada usable.
String? normalizeBackdrop(String? raw) {
  final v = raw?.trim() ?? '';
  if (v.isEmpty) return null;
  if (v.startsWith('http://') || v.startsWith('https://')) return v;
  if (v.startsWith('/')) return 'https://image.tmdb.org/t/p/w1280$v';
  return null;
}

/// Parsea la respuesta de `get_vod_info` (campo `info`).
VodInfo? parseVodInfo(Map<String, dynamic> json) {
  final info = json['info'];
  if (info is! Map) return null;
  String? str(String k) {
    final v = info[k];
    if (v == null) return null;
    final s = v is List ? (v.isEmpty ? '' : '${v.first}') : '$v';
    return s.trim().isEmpty ? null : s.trim();
  }

  return VodInfo(
    plot: str('plot') ?? str('description'),
    cast: str('cast') ?? str('actors'),
    director: str('director'),
    genre: str('genre'),
    releaseDate: str('releasedate') ?? str('release_date'),
    rating: str('rating'),
    durationText: str('duration'),
    cover: str('movie_image') ?? str('cover_big') ?? str('cover'),
    backdrop: normalizeBackdrop(str('backdrop_path')),
    youtubeTrailer: str('youtube_trailer'),
  );
}

/// Obtiene la ficha de una película. Best-effort: null ante cualquier error.
class VodInfoService {
  final Dio _dio;
  VodInfoService([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 12),
            ));

  Future<VodInfo?> fetch(String streamUrl) async {
    final url = buildVodInfoUrl(streamUrl);
    if (url == null) return null;
    try {
      final resp = await _dio.getUri<dynamic>(url);
      final data = resp.data;
      final map = data is Map<String, dynamic>
          ? data
          : (data is String && data.isNotEmpty
              ? jsonDecode(data) as Map<String, dynamic>
              : null);
      if (map == null) return null;
      return parseVodInfo(map);
    } catch (_) {
      return null;
    }
  }
}
