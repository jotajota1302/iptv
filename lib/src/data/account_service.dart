import 'dart:convert';
import 'package:dio/dio.dart';

/// Estado de una cuenta Xtream (de `player_api.php` → `user_info`).
class AccountInfo {
  final String status; // Active, Expired, Disabled, Banned...
  final DateTime? expiry; // null = sin caducidad
  final int activeConnections;
  final int maxConnections;
  final bool isTrial;
  const AccountInfo({
    required this.status,
    required this.expiry,
    required this.activeConnections,
    required this.maxConnections,
    required this.isTrial,
  });

  bool get isActive => status.toLowerCase() == 'active';
}

/// Construye la URL de `player_api.php` (estado de cuenta) a partir de la URL
/// de la lista (get.php con username/password).
Uri? buildAccountUrl(String listUrl) {
  final p = Uri.tryParse(listUrl);
  if (p == null) return null;
  final user = p.queryParameters['username'];
  final pass = p.queryParameters['password'];
  if (user == null || pass == null) return null;
  return Uri(
    scheme: p.scheme,
    host: p.host,
    port: p.hasPort ? p.port : null,
    path: '/player_api.php',
    queryParameters: {'username': user, 'password': pass},
  );
}

/// Reconstruye la URL de la lista (get.php) a partir de la URL de un stream
/// Xtream (`.../live|movie|series/user/pass/id.ext`). Sirve para recuperar una
/// lista que se cargó sin guardarse.
String? deriveListUrlFromStream(String streamUrl) {
  final s = Uri.tryParse(streamUrl);
  if (s == null) return null;
  final segs = s.pathSegments;
  if (segs.length < 3) return null;
  final pass = segs[segs.length - 2];
  final user = segs[segs.length - 3];
  if (user.isEmpty || pass.isEmpty) return null;
  final port = s.hasPort ? ':${s.port}' : '';
  return '${s.scheme}://${s.host}$port/get.php?username=$user&password=$pass'
      '&type=m3u_plus&output=ts';
}

AccountInfo? parseAccountInfo(Map<String, dynamic> json) {
  final u = json['user_info'];
  if (u is! Map) return null;
  int toInt(dynamic v) => v is int ? v : (int.tryParse('${v ?? ''}') ?? 0);
  DateTime? exp;
  final e = u['exp_date'];
  final es = toInt(e);
  if (es > 0) {
    exp = DateTime.fromMillisecondsSinceEpoch(es * 1000, isUtc: true).toLocal();
  }
  return AccountInfo(
    status: '${u['status'] ?? 'Desconocido'}',
    expiry: exp,
    activeConnections: toInt(u['active_cons']),
    maxConnections: toInt(u['max_connections']),
    isTrial: toInt(u['is_trial']) == 1,
  );
}

/// Obtiene el estado de cuenta. Best-effort: null ante cualquier error.
class AccountService {
  final Dio _dio;
  AccountService([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 12),
              headers: {'User-Agent': 'VLC/3.0.20 LibVLC/3.0.20'},
            ));

  Future<AccountInfo?> fetch(String listUrl) async {
    final url = buildAccountUrl(listUrl);
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
      return parseAccountInfo(map);
    } catch (_) {
      return null;
    }
  }
}
