import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/data/series_grouper.dart';
import 'package:iptv_player/src/domain/content_type.dart';
import 'package:iptv_player/src/domain/media_item.dart';

MediaItem ep(String name, {String? logo}) => MediaItem(
    id: name, name: name, streamUrl: 'u/$name', logoUrl: logo,
    type: ContentType.series);

void main() {
  test('agrupa episodios de 2 temporadas de una serie (SxxEyy)', () {
    final groups = groupSeries([
      ep('Breaking Bad S01E01'),
      ep('Breaking Bad S01E02'),
      ep('Breaking Bad S02E01'),
    ]);
    expect(groups.length, 1);
    final g = groups.single;
    expect(g.title, 'Breaking Bad');
    expect(g.sortedSeasons, [1, 2]);
    expect(g.seasons[1]!.length, 2);
    expect(g.seasons[2]!.length, 1);
    expect(g.episodeCount, 3);
  });

  test('ordena episodios por numero dentro de la temporada', () {
    final g = groupSeries([
      ep('Lost S01E03'),
      ep('Lost S01E01'),
      ep('Lost S01E02'),
    ]).single;
    expect(g.seasons[1]!.map((e) => e.episode), [1, 2, 3]);
  });

  test('reconoce el formato NxM', () {
    final g = groupSeries([ep('Friends 1x02')]).single;
    expect(g.title, 'Friends');
    expect(g.seasons[1]!.single.episode, 2);
  });

  test('separa series distintas y las ordena por titulo', () {
    final groups = groupSeries([
      ep('Zeta S01E01'),
      ep('Alfa S01E01'),
    ]);
    expect(groups.map((g) => g.title), ['Alfa', 'Zeta']);
  });

  test('sin patron -> temporada 0, titulo completo', () {
    final g = groupSeries([ep('Documental sobre el mar')]).single;
    expect(g.title, 'Documental sobre el mar');
    expect(g.sortedSeasons, [0]);
  });

  test('toma el primer poster no nulo', () {
    final g = groupSeries([
      ep('Dexter S01E01'),
      ep('Dexter S01E02', logo: 'http://poster.jpg'),
    ]).single;
    expect(g.poster, 'http://poster.jpg');
  });

  group('cleanEpisodeName', () {
    test('quita el título de la serie y el patrón SxxEyy', () {
      expect(cleanEpisodeName('Breaking Bad S01E01 - Pilot', 'Breaking Bad'),
          'Pilot');
      expect(cleanEpisodeName('Friends 1x02 The One', 'Friends'), 'The One');
    });

    test('vacío si el nombre no aporta nada más', () {
      expect(cleanEpisodeName('Breaking Bad S01E02', 'Breaking Bad'), '');
      expect(cleanEpisodeName('Dexter - S03E04', 'Dexter'), '');
    });

    test('conserva el nombre si no hay título de serie dentro', () {
      expect(cleanEpisodeName('El comienzo del fin', 'Vikings'),
          'El comienzo del fin');
    });
  });
}
