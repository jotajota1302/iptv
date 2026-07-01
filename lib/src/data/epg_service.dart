import 'dart:convert';
import 'package:dio/dio.dart';

/// Una entrada de la guía de programación (EPG): un programa con su título y
/// franja horaria.
class EpgEntry {
  final String title;
  final DateTime start;
  final DateTime end;
  const EpgEntry({required this.title, required this.start, required this.end});
}

/// Construye la URL de la API Xtream `get_short_epg` a partir de la URL de la
/// lista (get.php con username/password) y la URL del stream (para el
/// stream_id, que es el último segmento del path sin extensión).
///
/// Devuelve null si faltan credenciales o no se puede deducir el stream_id.
Uri? buildShortEpgUrl(String playlistUrl, String streamUrl, {int limit = 4}) {
  final p = Uri.tryParse(playlistUrl);
  final s = Uri.tryParse(streamUrl);
  if (p == null || s == null) return null;
  final user = p.queryParameters['username'];
  final pass = p.queryParameters['password'];
  if (user == null || pass == null) return null;
  if (s.pathSegments.isEmpty) return null;
  final streamId = s.pathSegments.last.split('.').first;
  if (streamId.isEmpty) return null;
  return Uri(
    scheme: p.scheme,
    host: p.host,
    port: p.hasPort ? p.port : null,
    path: '/player_api.php',
    queryParameters: {
      'username': user,
      'password': pass,
      'action': 'get_short_epg',
      'stream_id': streamId,
      'limit': '$limit',
    },
  );
}

/// Parsea la respuesta JSON de `get_short_epg` (campo `epg_listings`).
/// Los títulos vienen en base64; las horas en `start_timestamp`/`stop_timestamp`
/// (segundos UTC). Ordena por hora de inicio.
List<EpgEntry> parseShortEpg(Map<String, dynamic> json) {
  final listings = json['epg_listings'];
  if (listings is! List) return [];
  final out = <EpgEntry>[];
  for (final e in listings) {
    if (e is! Map) continue;
    final start = _tsToDate(e['start_timestamp']);
    if (start == null) continue;
    out.add(EpgEntry(
      title: _decodeB64(e['title']),
      start: start,
      end: _tsToDate(e['stop_timestamp']) ?? start,
    ));
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

String _decodeB64(dynamic v) {
  if (v is! String || v.isEmpty) return '';
  try {
    return utf8.decode(base64.decode(v)).trim();
  } catch (_) {
    return v;
  }
}

DateTime? _tsToDate(dynamic v) {
  final n = v is int ? v : int.tryParse('$v');
  if (n == null || n <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(n * 1000, isUtc: true).toLocal();
}

/// Obtiene la guía corta (programa actual y siguientes) de un canal Xtream.
/// Es "best-effort": ante cualquier error devuelve lista vacía.
class EpgService {
  final Dio _dio;
  EpgService([Dio? dio]) : _dio = dio ?? Dio();

  Future<List<EpgEntry>> shortEpg(String playlistUrl, String streamUrl) async {
    final url = buildShortEpgUrl(playlistUrl, streamUrl);
    if (url == null) return [];
    try {
      final resp = await _dio.getUri<dynamic>(url);
      final data = resp.data;
      final map = data is Map<String, dynamic>
          ? data
          : (data is String && data.isNotEmpty
              ? jsonDecode(data) as Map<String, dynamic>
              : null);
      if (map == null) return [];
      return parseShortEpg(map);
    } catch (_) {
      return [];
    }
  }
}
