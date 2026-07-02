import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iptv_player/src/app/providers.dart';
import 'package:iptv_player/src/domain/content_type.dart';
import 'package:iptv_player/src/domain/media_item.dart';
import 'package:iptv_player/src/ui/movies_tab.dart';

void main() {
  testWidgets('el buscador de películas muestra resultados globales',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        movieCategoriesProvider.overrideWith((ref) async => const []),
        continueWatchingProvider.overrideWith((ref) async => const []),
        searchByTypeProvider.overrideWith((ref, k) async => [
              const MediaItem(
                  id: 'm1',
                  name: 'Matrix',
                  streamUrl: 'u',
                  type: ContentType.movie),
            ]),
      ],
      child: const MaterialApp(home: Scaffold(body: MoviesTab())),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'mat');
    await tester.pumpAndSettle();
    expect(find.text('Matrix'), findsOneWidget);

    // Limpiar la búsqueda vuelve a la vista de categorías.
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(find.text('Matrix'), findsNothing);
  });
}
