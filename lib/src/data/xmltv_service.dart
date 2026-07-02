import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:xml/xml.dart';
import 'epg_service.dart';

/// Guía XMLTV completa del servidor: programas por id de canal, con búsqueda
/// por tvg-id del M3U o, en su defecto, por nombre visible del canal.
class XmltvGuide {
  final Map<String, List<EpgEntry>> byChannel;
  final Map<String, String> _idByName; // display-name normalizado -> id
  const XmltvGuide(this.byChannel, this._idByName);

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Programas de un canal: primero por [tvgId]; si no, por [name].
  List<EpgEntry> forChannel(String? tvgId, String name) {
    if (tvgId != null && tvgId.isNotEmpty) {
      final byId = byChannel[tvgId];
      if (byId != null) return byId;
    }
    final id = _idByName[_norm(name)];
    return id == null ? const [] : (byChannel[id] ?? const []);
  }

  bool get isEmpty => byChannel.isEmpty;
}

/// URL del EPG completo (`xmltv.php`) desde la URL de la lista (`get.php`),
/// reutilizando username/password. Null si la URL no lleva credenciales.
Uri? buildXmltvUrl(String listUrl) {
  final u = Uri.tryParse(listUrl);
  if (u == null) return null;
  final user = u.queryParameters['username'];
  final pass = u.queryParameters['password'];
  if (user == null || pass == null || user.isEmpty || pass.isEmpty) {
    return null;
  }
  return Uri(
    scheme: u.scheme,
    host: u.host,
    port: u.hasPort ? u.port : null,
    path: '/xmltv.php',
    queryParameters: {'username': user, 'password': pass},
  );
}

final _timeRe = RegExp(r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})'
    r'(?:\s*([+-])(\d{2})(\d{2}))?$');

/// Hora XMLTV ("yyyyMMddHHmmss ±HHMM", desfase opcional = UTC) a hora local.
DateTime? parseXmltvTime(String s) {
  final m = _timeRe.firstMatch(s.trim());
  if (m == null) return null;
  var utc = DateTime.utc(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
    int.parse(m.group(4)!),
    int.parse(m.group(5)!),
    int.parse(m.group(6)!),
  );
  if (m.group(7) != null) {
    final sign = m.group(7) == '-' ? -1 : 1;
    final offset = Duration(
        hours: int.parse(m.group(8)!), minutes: int.parse(m.group(9)!));
    utc = utc.subtract(offset * sign);
  }
  return utc.toLocal();
}

/// Parsea un documento XMLTV completo. Función de nivel superior para poder
/// ejecutarla en un isolate con `compute` (los EPG completos pesan varios MB).
XmltvGuide parseXmltv(String xmlStr) {
  final byChannel = <String, List<EpgEntry>>{};
  final idByName = <String, String>{};
  final XmlDocument doc;
  try {
    doc = XmlDocument.parse(xmlStr);
  } catch (_) {
    return const XmltvGuide({}, {});
  }
  for (final ch in doc.findAllElements('channel')) {
    final id = ch.getAttribute('id');
    if (id == null || id.isEmpty) continue;
    for (final name in ch.findElements('display-name')) {
      final n = XmltvGuide._norm(name.innerText);
      if (n.isNotEmpty) idByName.putIfAbsent(n, () => id);
    }
  }
  for (final p in doc.findAllElements('programme')) {
    final channel = p.getAttribute('channel');
    final start = parseXmltvTime(p.getAttribute('start') ?? '');
    final stop = parseXmltvTime(p.getAttribute('stop') ?? '');
    if (channel == null || start == null || stop == null) continue;
    final title = p.getElement('title')?.innerText.trim() ?? '';
    final desc = p.getElement('desc')?.innerText.trim();
    byChannel.putIfAbsent(channel, () => []).add(EpgEntry(
          title: title,
          start: start,
          end: stop,
          description: desc == null || desc.isEmpty ? null : desc,
        ));
  }
  for (final list in byChannel.values) {
    list.sort((a, b) => a.start.compareTo(b.start));
  }
  return XmltvGuide(byChannel, idByName);
}

/// Descarga y cachea la guía XMLTV (una petición por sesión y servidor,
/// con caducidad). Best-effort: null si el servidor no la expone.
class XmltvService {
  final Dio _dio;
  final _cache = <String, (DateTime, Future<XmltvGuide?>)>{};
  static const _ttl = Duration(hours: 6);

  XmltvService([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 20),
              receiveTimeout: const Duration(minutes: 3),
            ));

  Future<XmltvGuide?> fetchFromListUrl(String listUrl) {
    final url = buildXmltvUrl(listUrl);
    if (url == null) return Future.value(null);
    final key = url.toString();
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.$1) < _ttl) {
      return cached.$2;
    }
    final future = _fetch(url);
    _cache[key] = (DateTime.now(), future);
    return future;
  }

  Future<XmltvGuide?> _fetch(Uri url) async {
    try {
      final resp = await _dio.getUri<String>(url,
          options: Options(responseType: ResponseType.plain));
      final body = resp.data;
      if (body == null || body.isEmpty) return null;
      final guide = await compute(parseXmltv, body);
      return guide.isEmpty ? null : guide;
    } catch (_) {
      return null;
    }
  }
}
