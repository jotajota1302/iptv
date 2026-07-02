import 'dart:convert';
import 'package:dio/dio.dart';

/// Una entrada de la guía de programación (EPG): un programa con su título y
/// franja horaria. [hasArchive] indica si está disponible en el archivo
/// (catch‑up) para rebobinarlo.
class EpgEntry {
  final String title;
  final DateTime start;
  final DateTime end;
  final bool hasArchive;
  const EpgEntry({
    required this.title,
    required this.start,
    required this.end,
    this.hasArchive = false,
  });

  int get durationMinutes {
    final m = end.difference(start).inMinutes;
    return m > 0 ? m : 1;
  }
}

/// Construye la URL de *timeshift* (catch‑up) de Xtream a partir de la URL del
/// stream en directo del canal, la hora de inicio (local) y la duración.
/// Formato: `{server}/timeshift/{user}/{pass}/{minutos}/{Y-m-d:H-i}/{id}.ts`.
String? buildTimeshiftUrl(
    String streamUrl, DateTime startLocal, int durationMinutes) {
  final s = Uri.tryParse(streamUrl);
  if (s == null) return null;
  final segs = s.pathSegments;
  if (segs.length < 3) return null;
  final id = segs.last.split('.').first;
  final pass = segs[segs.length - 2];
  final user = segs[segs.length - 3];
  if (id.isEmpty || user.isEmpty || pass.isEmpty) return null;
  String two(int n) => n.toString().padLeft(2, '0');
  final start = '${startLocal.year}-${two(startLocal.month)}-'
      '${two(startLocal.day)}:${two(startLocal.hour)}-${two(startLocal.minute)}';
  final port = s.hasPort ? ':${s.port}' : '';
  return '${s.scheme}://${s.host}$port/timeshift/$user/$pass/'
      '$durationMinutes/$start/$id.ts';
}

/// Construye una URL de la API Xtream para un [action] de EPG, derivando TODO
/// de la URL del stream, que en Xtream tiene la forma
/// `scheme://host:port/[live|movie|series]/user/pass/streamId.ext`.
/// Así no dependemos de que haya una lista guardada activa.
///
/// Devuelve null si la URL no encaja con ese patrón.
Uri? buildEpgUrl(String streamUrl,
    {String action = 'get_short_epg', int? limit}) {
  final s = Uri.tryParse(streamUrl);
  if (s == null) return null;
  final segs = s.pathSegments;
  // Necesitamos al menos user/pass/id (los 3 últimos segmentos).
  if (segs.length < 3) return null;
  final streamId = segs.last.split('.').first;
  final pass = segs[segs.length - 2];
  final user = segs[segs.length - 3];
  if (streamId.isEmpty || user.isEmpty || pass.isEmpty) return null;
  return Uri(
    scheme: s.scheme,
    host: s.host,
    port: s.hasPort ? s.port : null,
    path: '/player_api.php',
    queryParameters: {
      'username': user,
      'password': pass,
      'action': action,
      'stream_id': streamId,
      if (limit != null) 'limit': '$limit',
    },
  );
}

/// Guía corta (ahora/siguiente): `get_short_epg` con límite.
Uri? buildShortEpgUrl(String streamUrl, {int limit = 4}) =>
    buildEpgUrl(streamUrl, action: 'get_short_epg', limit: limit);

/// Guía completa del canal: `get_simple_data_table` (todo el EPG disponible).
Uri? buildFullEpgUrl(String streamUrl) =>
    buildEpgUrl(streamUrl, action: 'get_simple_data_table');

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
      hasArchive: _asInt(e['has_archive']) == 1,
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

int? _asInt(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}');

DateTime? _tsToDate(dynamic v) {
  final n = v is int ? v : int.tryParse('$v');
  if (n == null || n <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(n * 1000, isUtc: true).toLocal();
}

/// Obtiene la guía corta (programa actual y siguientes) de un canal Xtream.
/// Es "best-effort": ante cualquier error devuelve lista vacía.
class EpgService {
  final Dio _dio;
  EpgService([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 12),
            ));

  Future<List<EpgEntry>> shortEpg(String streamUrl) =>
      _fetch(buildShortEpgUrl(streamUrl));

  /// Guía completa del canal (todo el EPG disponible, varias horas/días).
  Future<List<EpgEntry>> fullEpg(String streamUrl) =>
      _fetch(buildFullEpgUrl(streamUrl));

  Future<List<EpgEntry>> _fetch(Uri? url) async {
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
