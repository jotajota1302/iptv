import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/domain/media_item.dart';
import 'package:iptv_player/src/domain/series_group.dart';

Episode ep(String name, {int added = 0}) => Episode(
    item: MediaItem(id: name, name: name, streamUrl: 'u', addedAt: added),
    season: 1,
    episode: 1);

void main() {
  test('year es el mayor año entre los episodios', () {
    final g = SeriesGroup(title: 'S', seasons: {
      1: [ep('S (2018) S01E01'), ep('S (2020) S01E02')],
      2: [ep('S (2019) S02E01')],
    });
    expect(g.year, 2020);
  });

  test('year es 0 cuando ningún episodio trae año', () {
    final g = SeriesGroup(title: 'S', seasons: {
      1: [ep('S S01E01'), ep('S S01E02')],
    });
    expect(g.year, 0);
  });

  test('addedAt es el mayor addedAt entre los episodios', () {
    final g = SeriesGroup(title: 'S', seasons: {
      1: [ep('S S01E01', added: 100), ep('S S01E02', added: 300)],
      2: [ep('S S02E01', added: 200)],
    });
    expect(g.addedAt, 300);
  });
}
