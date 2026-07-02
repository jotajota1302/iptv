import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/data/tmdb_service.dart';
import 'package:iptv_player/src/domain/content_type.dart';
import 'package:iptv_player/src/domain/credit_match.dart';
import 'package:iptv_player/src/domain/media_item.dart';

MediaItem _item(String id, String name, ContentType type) =>
    MediaItem(id: id, name: name, streamUrl: 'http://x/$id.mp4', type: type);

void main() {
  group('cleanMediaTitle', () {
    test('quita prefijos, etiquetas, año y calidad', () {
      expect(cleanMediaTitle('ES| Oppenheimer (2023) [4K]'), 'Oppenheimer');
      expect(cleanMediaTitle('4K - no toca prefijo largo'), isNot(''));
      expect(cleanMediaTitle('El Padrino FHD MULTI'), 'El Padrino');
      expect(cleanMediaTitle('  Dune:  parte dos  '), 'Dune: parte dos');
    });

    test('yearFromName saca el año del nombre', () {
      expect(yearFromName('Oppenheimer (2023)'), '2023');
      expect(yearFromName('Sin año'), isNull);
    });
  });

  group('parseCast', () {
    test('películas: campo character', () {
      final cast = parseCast({
        'cast': [
          {
            'id': 2037,
            'name': 'Cillian Murphy',
            'character': 'J. Robert Oppenheimer',
            'profile_path': '/abc.jpg',
          },
        ],
      });
      expect(cast.single.name, 'Cillian Murphy');
      expect(cast.single.character, 'J. Robert Oppenheimer');
      expect(cast.single.profileUrl,
          'https://image.tmdb.org/t/p/w185/abc.jpg');
    });

    test('series (aggregate_credits): personaje dentro de roles', () {
      final cast = parseCast({
        'cast': [
          {
            'id': 17419,
            'name': 'Bryan Cranston',
            'roles': [
              {'character': 'Walter White'},
            ],
          },
        ],
      });
      expect(cast.single.character, 'Walter White');
    });

    test('entradas inválidas se descartan', () {
      expect(parseCast({'cast': [{}, {'id': 'x', 'name': 'y'}]}), isEmpty);
      expect(parseCast(null), isEmpty);
    });
  });

  group('parsePerson / parseCombinedCredits', () {
    test('persona con bio y foto', () {
      final p = parsePerson({
        'id': 2037,
        'name': 'Cillian Murphy',
        'biography': 'Actor irlandés...',
        'birthday': '1976-05-25',
        'place_of_birth': 'Douglas, Cork, Ireland',
        'profile_path': '/p.jpg',
      });
      expect(p!.biography, 'Actor irlandés...');
      expect(p.profileUrl, 'https://image.tmdb.org/t/p/w342/p.jpg');
    });

    test('créditos: dedup, orden por año desc y tipos válidos', () {
      final credits = parseCombinedCredits({
        'cast': [
          {'id': 1, 'media_type': 'movie', 'title': 'Vieja', 'release_date': '1999-01-01'},
          {'id': 2, 'media_type': 'tv', 'name': 'Serie', 'first_air_date': '2020-05-05'},
          {'id': 1, 'media_type': 'movie', 'title': 'Vieja duplicada', 'release_date': '1999-01-01'},
          {'id': 3, 'media_type': 'person', 'name': 'inválido'},
        ],
      });
      expect(credits.length, 2);
      expect(credits.first.title, 'Serie');
      expect(credits.first.year, '2020');
      expect(credits.last.year, '1999');
    });
  });

  group('pickCatalogMatch', () {
    final credit = const TmdbCredit(
        id: 1, title: 'Oppenheimer', mediaType: 'movie');
    final tvCredit = const TmdbCredit(
        id: 2, title: 'Breaking Bad', mediaType: 'tv');

    test('película: igualdad normalizada aunque haya adornos', () {
      final m = pickCatalogMatch(
          [_item('a', 'ES| Oppenheimer (2023) [4K]', ContentType.movie)],
          credit);
      expect(m!.id, 'a');
    });

    test('película: ignora tipos distintos y ambigüedad por prefijo', () {
      expect(
          pickCatalogMatch(
              [_item('a', 'Oppenheimer', ContentType.series)], credit),
          isNull);
      expect(
          pickCatalogMatch([
            _item('a', 'Oppenheimer parte 1', ContentType.movie),
            _item('b', 'Oppenheimer parte 2', ContentType.movie),
          ], credit),
          isNull);
    });

    test('serie: un episodio sirve de puerta de entrada', () {
      final m = pickCatalogMatch(
          [_item('e1', 'Breaking Bad S01 E01', ContentType.series)],
          tvCredit);
      expect(m!.id, 'e1');
    });
  });
}
