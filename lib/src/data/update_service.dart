import 'dart:convert';
import 'package:dio/dio.dart';

/// Una versión publicada más nueva que la instalada.
class UpdateInfo {
  final String version; // p. ej. 'v1.1.0'
  final String url; // página de descarga (release en GitHub o landing)
  final String? notes; // changelog (body del release)
  const UpdateInfo({required this.version, required this.url, this.notes});
}

/// Compara versiones tipo semver ('1.2.3', 'v1.2.3', '1.0.0+4').
/// Devuelve negativo si a menor que b, 0 si iguales, positivo si a mayor
/// que b. El número de build y los sufijos ('+1', '-beta') se ignoran, así
/// '1.0.0+1' == '1.0.0'.
int compareVersions(String a, String b) {
  List<int> parts(String v) => v
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split(RegExp(r'[+\-]'))
      .first
      .split('.')
      .map((s) => int.tryParse(s) ?? 0)
      .toList();
  final pa = parts(a), pb = parts(b);
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

bool isNewerVersion(String current, String candidate) =>
    compareVersions(candidate, current) > 0;

/// Solo tags de versión de la app ('v1.2.3', '1.2'); descarta releases de
/// herramientas como 'libmpv-lgpl-20260702'.
final _appTag = RegExp(r'^v?\d+(\.\d+)*$');

/// Elige el release de app más reciente de la lista de la API de GitHub
/// (`/releases`, ya ordenada de nuevo a viejo). Ignora borradores,
/// prereleases y tags que no sean de versión.
UpdateInfo? pickLatestAppRelease(List<dynamic> releases) {
  for (final r in releases) {
    if (r is! Map) continue;
    if (r['draft'] == true || r['prerelease'] == true) continue;
    final tag = '${r['tag_name'] ?? ''}';
    if (!_appTag.hasMatch(tag)) continue;
    final url = '${r['html_url'] ?? ''}';
    if (url.isEmpty) continue;
    final body = r['body'];
    return UpdateInfo(
        version: tag, url: url, notes: body is String ? body : null);
  }
  return null;
}

/// Comprueba si hay una versión nueva contra un feed con el formato de la
/// API de GitHub Releases. Lanza excepción si el feed no responde (el
/// llamante decide si es silencioso o avisa al usuario).
class UpdateService {
  final String feedUrl;
  final Dio _dio;
  UpdateService({required this.feedUrl, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              headers: {'Accept': 'application/vnd.github+json'},
            ));

  /// Null = no hay versión más nueva (o feed desactivado).
  Future<UpdateInfo?> check(String currentVersion) async {
    if (feedUrl.isEmpty) return null;
    final resp = await _dio.get<dynamic>(feedUrl);
    final data = resp.data;
    final list = data is List
        ? data
        : (data is String ? jsonDecode(data) as List<dynamic> : <dynamic>[]);
    final latest = pickLatestAppRelease(list);
    if (latest == null) return null;
    return isNewerVersion(currentVersion, latest.version) ? latest : null;
  }
}
