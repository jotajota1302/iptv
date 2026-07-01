import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/app/providers.dart';
import 'package:iptv_player/src/domain/content_type.dart';
import 'package:iptv_player/src/domain/media_item.dart';
import 'package:iptv_player/src/ui/continue_watching_row.dart';

void main() {
  testWidgets('muestra los items en progreso del tipo indicado', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        continueWatchingProvider.overrideWith((ref) async => const [
              MediaItem(
                  id: 'p', name: 'Peli a medias', streamUrl: 'u',
                  type: ContentType.movie,
                  positionSeconds: 600, durationSeconds: 6000),
              MediaItem(
                  id: 's', name: 'Serie a medias', streamUrl: 'u2',
                  type: ContentType.series,
                  positionSeconds: 100, durationSeconds: 3000),
            ]),
      ],
      child: const MaterialApp(
        home: Scaffold(body: ContinueWatchingRow(type: ContentType.movie)),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Continuar viendo'), findsOneWidget);
    expect(find.text('Peli a medias'), findsOneWidget);
    expect(find.text('Serie a medias'), findsNothing); // filtrado a movie
  });

  testWidgets('se oculta si no hay nada en progreso', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        continueWatchingProvider.overrideWith((ref) async => const []),
      ],
      child: const MaterialApp(home: Scaffold(body: ContinueWatchingRow())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Continuar viendo'), findsNothing);
  });
}
