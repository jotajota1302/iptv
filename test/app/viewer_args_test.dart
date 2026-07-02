import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/app/viewer_args.dart';
import 'package:iptv_player/src/domain/content_type.dart';

void main() {
  test('null sin --play', () {
    expect(parseViewerArgs([]), isNull);
    expect(parseViewerArgs(['--name', 'x']), isNull);
    expect(parseViewerArgs(['--play']), isNull); // sin valor
  });

  test('parsea url, nombre y tipo', () {
    final a = parseViewerArgs(
        ['--play', 'http://h/live/u/p/1.ts', '--name', 'La 1', '--type', 'live'])!;
    expect(a.url, 'http://h/live/u/p/1.ts');
    expect(a.name, 'La 1');
    expect(a.type, ContentType.live);
    expect(a.toItem().streamUrl, a.url);
  });

  test('valores por defecto: nombre genérico y tipo live', () {
    final a = parseViewerArgs(['--play', 'http://x'])!;
    expect(a.name, 'IPTV Player');
    expect(a.type, ContentType.live);
  });

  test('tipo movie para VOD', () {
    final a = parseViewerArgs(['--play', 'u', '--type', 'movie'])!;
    expect(a.type, ContentType.movie);
  });
}
