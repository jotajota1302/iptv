import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/data/vod_info_service.dart';

void main() {
  group('buildVodInfoUrl', () {
    test('deriva vod_id y credenciales de la URL de la peli', () {
      final url = buildVodInfoUrl('https://host.tv:8443/movie/u1/p1/9876.mkv');
      expect(url, isNotNull);
      expect(url!.path, '/player_api.php');
      expect(url.queryParameters['action'], 'get_vod_info');
      expect(url.queryParameters['vod_id'], '9876');
      expect(url.queryParameters['username'], 'u1');
      expect(url.queryParameters['password'], 'p1');
    });

    test('null si la URL no encaja', () {
      expect(buildVodInfoUrl('https://host.tv/solo.mkv'), isNull);
    });
  });

  group('parseVodInfo', () {
    test('extrae campos y el año del releasedate', () {
      final info = parseVodInfo({
        'info': {
          'plot': 'Una gran película',
          'genre': 'Acción',
          'releasedate': '2021-05-10',
          'rating': '7.8',
          'movie_image': 'http://poster.jpg',
          'backdrop_path': ['http://back.jpg'],
        },
      });
      expect(info, isNotNull);
      expect(info!.plot, 'Una gran película');
      expect(info.genre, 'Acción');
      expect(info.year, '2021');
      expect(info.rating, '7.8');
      expect(info.cover, 'http://poster.jpg');
      expect(info.backdrop, 'http://back.jpg');
      expect(info.isEmpty, isFalse);
    });

    test('null si no hay info', () {
      expect(parseVodInfo({}), isNull);
    });
  });
}
