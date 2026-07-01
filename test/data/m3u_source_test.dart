import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:iptv_player/src/data/m3u_source.dart';

class _MockHttp extends Mock implements HttpClient {}

void main() {
  test('fetchFromUrl devuelve el texto del http client', () async {
    final http = _MockHttp();
    when(() => http.getText('http://x/list.m3u'))
        .thenAnswer((_) async => '#EXTM3U\n');
    final source = M3uSource(http);
    final text = await source.fetchFromUrl('http://x/list.m3u');
    expect(text, '#EXTM3U\n');
  });
}
