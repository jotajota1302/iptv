import 'dart:io' as io;
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

abstract class HttpClient {
  Future<String> getText(String url);
}

/// Error legible al descargar una lista (para mostrarlo en la UI).
class PlaylistLoadException implements Exception {
  final String message;
  const PlaylistLoadException(this.message);
  @override
  String toString() => message;
}

class DioHttpClient implements HttpClient {
  final Dio _dio;
  DioHttpClient([Dio? dio]) : _dio = dio ?? _build();

  static Dio _build() {
    final dio = Dio(BaseOptions(
      responseType: ResponseType.plain,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 3),
      followRedirects: true,
      maxRedirects: 5,
      // Muchos paneles Xtream rechazan (403) peticiones sin User-Agent de
      // reproductor; el de VLC es el más aceptado.
      headers: {'User-Agent': 'VLC/3.0.20 LibVLC/3.0.20'},
    ));
    // Aceptar certificados no válidos: es habitual que los paneles IPTV usen
    // certificados caducados o autofirmados. La URL la introduce el usuario.
    final adapter = dio.httpClientAdapter;
    if (adapter is IOHttpClientAdapter) {
      adapter.createHttpClient = () {
        final client = io.HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      };
    }
    return dio;
  }

  @override
  Future<String> getText(String url) async {
    try {
      final res = await _dio.get<String>(url);
      return res.data ?? '';
    } on DioException catch (e) {
      throw PlaylistLoadException(_friendly(e));
    }
  }

  String _friendly(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'La lista tardó demasiado en responder (tiempo agotado). '
            'Inténtalo de nuevo o revisa la URL.';
      case DioExceptionType.badCertificate:
        return 'El certificado del servidor no es válido.';
      case DioExceptionType.connectionError:
        return 'No se pudo conectar con el servidor. Revisa la URL y tu '
            'conexión a internet.';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code == 403 || code == 401) {
          return 'El servidor rechazó la lista (error $code). Suele significar: '
              'cuenta caducada o desactivada, límite de conexiones alcanzado, '
              'o usuario/contraseña incorrectos.';
        }
        if (code == 404) {
          return 'Lista no encontrada (404). Revisa la URL.';
        }
        return 'El servidor respondió con error $code.';
      default:
        return 'No se pudo cargar la lista: ${e.message ?? e.type.name}';
    }
  }
}

class M3uSource {
  final HttpClient _http;
  M3uSource(this._http);

  Future<String> fetchFromUrl(String url) => _http.getText(url);

  Future<String> readFromFile(String path) => io.File(path).readAsString();
}
