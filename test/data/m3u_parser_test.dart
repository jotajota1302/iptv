import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/data/m3u_parser.dart';

const sample = '''
#EXTM3U
#EXTINF:-1 tvg-id="la1.es" tvg-logo="http://logo/la1.png" group-title="Nacionales",La 1
http://host:8443/user/pass/1001.ts
#EXTINF:-1 group-title="Cine",Pelicula X
http://host:8443/movie/user/pass/2002.mkv
linea-basura-sin-extinf
''';

void main() {
  test('parsea entradas validas e ignora basura', () {
    final items = parseM3u(sample);
    expect(items.length, 2);
    expect(items.first.name, 'La 1');
    expect(items.first.tvgId, 'la1.es');
    expect(items.first.logoUrl, 'http://logo/la1.png');
    expect(items.first.groupTitle, 'Nacionales');
    expect(items.first.streamUrl, 'http://host:8443/user/pass/1001.ts');
    expect(items[1].name, 'Pelicula X');
  });

  test('lista vacia o sin cabecera devuelve vacio sin crashear', () {
    expect(parseM3u(''), isEmpty);
    expect(parseM3u('texto random'), isEmpty);
  });
}
