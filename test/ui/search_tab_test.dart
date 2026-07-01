import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/app/providers.dart';
import 'package:iptv_player/src/domain/content_type.dart';
import 'package:iptv_player/src/domain/media_item.dart';
import 'package:iptv_player/src/ui/search_tab.dart';

void main() {
  testWidgets('muestra resultados de busqueda', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        searchResultsProvider.overrideWith((ref) async => const [
              MediaItem(
                  id: 'a', name: 'La 1', streamUrl: 'u', type: ContentType.live),
            ]),
      ],
      child: const MaterialApp(home: Scaffold(body: SearchTab())),
    ));
    await tester.enterText(find.byType(TextField), 'la');
    await tester.pumpAndSettle();
    expect(find.text('La 1'), findsOneWidget);
  });

  testWidgets('el filtro por tipo restringe los resultados', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        searchResultsProvider.overrideWith((ref) async => const [
              MediaItem(
                  id: 'a', name: 'Canal Uno', streamUrl: 'u',
                  type: ContentType.live),
              MediaItem(
                  id: 'b', name: 'Peli Dos', streamUrl: 'u2',
                  type: ContentType.movie),
            ]),
      ],
      child: const MaterialApp(home: Scaffold(body: SearchTab())),
    ));
    await tester.enterText(find.byType(TextField), 'o');
    await tester.pumpAndSettle();
    expect(find.text('Canal Uno'), findsOneWidget);
    expect(find.text('Peli Dos'), findsOneWidget);

    // Filtrar por Películas oculta el canal en directo.
    await tester.tap(find.text('Películas'));
    await tester.pumpAndSettle();
    expect(find.text('Canal Uno'), findsNothing);
    expect(find.text('Peli Dos'), findsOneWidget);
  });
}
