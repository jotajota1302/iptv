import 'dart:io';
import 'package:dio/dio.dart';

abstract class HttpClient {
  Future<String> getText(String url);
}

class DioHttpClient implements HttpClient {
  final Dio _dio;
  DioHttpClient([Dio? dio])
      : _dio = dio ?? Dio(BaseOptions(responseType: ResponseType.plain));

  @override
  Future<String> getText(String url) async {
    final res = await _dio.get<String>(url);
    return res.data ?? '';
  }
}

class M3uSource {
  final HttpClient _http;
  M3uSource(this._http);

  Future<String> fetchFromUrl(String url) => _http.getText(url);

  Future<String> readFromFile(String path) => File(path).readAsString();
}
