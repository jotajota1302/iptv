import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/domain/content_type.dart';
import 'package:iptv_player/src/domain/media_item.dart';
import 'package:iptv_player/src/domain/series_group.dart';
import 'package:iptv_player/src/ui/series_detail_screen.dart';

void main() {
  testWidgets('muestra temporadas y episodios de la serie', (tester) async {
    const it1 = MediaItem(
        id: '1', name: 'Serie S01E01', streamUrl: 'u1', type: ContentType.series);
    const it2 = MediaItem(
        id: '2', name: 'Serie S02E01', streamUrl: 'u2', type: ContentType.series);
    const series = SeriesGroup(title: 'Serie', seasons: {
      1: [Episode(item: it1, season: 1, episode: 1)],
      2: [Episode(item: it2, season: 2, episode: 1)],
    });

    await tester.pumpWidget(
        const MaterialApp(home: SeriesDetailScreen(series: series)));
    await tester.pumpAndSettle();

    expect(find.text('Temporada 1'), findsOneWidget);
    expect(find.text('Temporada 2'), findsOneWidget);

    // Al desplegar la temporada 1 aparece su episodio.
    await tester.tap(find.text('Temporada 1'));
    await tester.pumpAndSettle();
    expect(find.text('Serie S01E01'), findsOneWidget);
  });
}
