import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/data/series_info_service.dart';

void main() {
  group('buildSeriesCatalogUrl', () {
    test('deriva player_api.php?action=get_series de la URL de un episodio',
        () {
      final url = buildSeriesCatalogUrl(
          'http://host.tv:8080/series/u1/p1/9021.mkv');
      expect(url, isNotNull);
      expect(url!.path, '/player_api.php');
      expect(url.queryParameters['username'], 'u1');
      expect(url.queryParameters['password'], 'p1');
      expect(url.queryParameters['action'], 'get_series');
    });

    test('null si la URL no tiene el patrón user/pass/id', () {
      expect(buildSeriesCatalogUrl('http://host.tv/x.mkv'), isNull);
    });
  });

  group('buildSeriesInfoUrl', () {
    test('incluye action=get_series_info y series_id', () {
      final url = buildSeriesInfoUrl(
          'http://host.tv:8080/series/u1/p1/9021.mkv', '77');
      expect(url, isNotNull);
      expect(url!.queryParameters['action'], 'get_series_info');
      expect(url.queryParameters['series_id'], '77');
    });
  });

  group('episodeIdFromUrl', () {
    test('extrae el id del último segmento sin extensión', () {
      expect(episodeIdFromUrl('http://h/series/u/p/9021.mkv'), '9021');
      expect(episodeIdFromUrl('http://h/series/u/p/123'), '123');
    });

    test('cadena vacía si la URL no es válida', () {
      expect(episodeIdFromUrl('::::'), '');
    });
  });

  group('matchSeriesId', () {
    final catalog = [
      const SeriesCatalogEntry(id: '1', name: 'Breaking Bad'),
      const SeriesCatalogEntry(id: '2', name: 'Better Call Saul'),
      const SeriesCatalogEntry(id: '3', name: 'La Casa de Papel (ES)'),
    ];

    test('match exacto ignorando mayúsculas y signos', () {
      expect(matchSeriesId(catalog, 'breaking bad'), '1');
      expect(matchSeriesId(catalog, 'BREAKING-BAD'), '1');
    });

    test('match por prefijo cuando el catálogo añade sufijos', () {
      expect(matchSeriesId(catalog, 'La Casa de Papel'), '3');
    });

    test('null si no hay candidato', () {
      expect(matchSeriesId(catalog, 'Los Soprano'), isNull);
    });
  });

  group('parseSeriesCatalog', () {
    test('lee series_id y name de la lista', () {
      final list = parseSeriesCatalog([
        {'series_id': 10, 'name': 'Dark'},
        {'series_id': '11', 'name': 'Dexter'},
        {'noise': true},
      ]);
      expect(list, hasLength(2));
      expect(list.first.id, '10');
      expect(list.first.name, 'Dark');
      expect(list.last.id, '11');
    });

    test('lista vacía si el JSON no es una lista', () {
      expect(parseSeriesCatalog({'a': 1}), isEmpty);
    });
  });

  group('parseSeriesInfo', () {
    final json = {
      'info': {
        'plot': 'Un profesor de química...',
        'cast': 'Bryan Cranston',
        'director': 'Vince Gilligan',
        'genre': 'Drama',
        'releaseDate': '2008-01-20',
        'rating': '9.5',
        'cover': 'http://img/cover.jpg',
        'backdrop_path': ['http://img/backdrop.jpg'],
      },
      'episodes': {
        '1': [
          {
            'id': '9021',
            'episode_num': 1,
            'season': 1,
            'title': 'Breaking Bad S01E01 - Pilot',
            'info': {
              'movie_image': 'http://img/e1.jpg',
              'plot': 'Walter White...',
              'duration': '00:58:00',
            },
          },
          {
            'id': 9022,
            'episode_num': '2',
            'season': 1,
            'title': 'Breaking Bad S01E02',
            'info': {'movie_image': 'http://img/e2.jpg'},
          },
        ],
      },
    };

    test('extrae la ficha de la serie', () {
      final info = parseSeriesInfo(json)!;
      expect(info.plot, contains('química'));
      expect(info.rating, '9.5');
      expect(info.cover, 'http://img/cover.jpg');
      expect(info.backdrop, 'http://img/backdrop.jpg');
      expect(info.year, '2008');
    });

    test('indexa episodios por id con imagen y duración', () {
      final info = parseSeriesInfo(json)!;
      expect(info.episodesById, hasLength(2));
      final e1 = info.episodesById['9021']!;
      expect(e1.image, 'http://img/e1.jpg');
      expect(e1.plot, contains('Walter'));
      expect(e1.durationText, '00:58:00');
      expect(e1.episodeNum, 1);
      // id numérico y episode_num como texto también se normalizan.
      expect(info.episodesById['9022']!.episodeNum, 2);
    });

    test('acepta episodes como lista de listas', () {
      final alt = {
        'info': <String, dynamic>{},
        'episodes': [
          [
            {'id': '5', 'episode_num': 1, 'season': 1, 'title': 'Uno'},
          ],
        ],
      };
      final info = parseSeriesInfo(alt)!;
      expect(info.episodesById.keys, ['5']);
    });

    test('null si no hay mapa raíz válido', () {
      expect(parseSeriesInfo({}), isNotNull); // sin info ni episodios → vacío
      expect(parseSeriesInfo({})!.episodesById, isEmpty);
    });
  });

  group('formatEpisodeDuration', () {
    test('convierte HH:MM:SS a minutos legibles', () {
      expect(formatEpisodeDuration('00:58:00'), '58 min');
      expect(formatEpisodeDuration('01:30:00'), '1 h 30 min');
      expect(formatEpisodeDuration(null), isNull);
      expect(formatEpisodeDuration('raro'), isNull);
    });
  });
}
