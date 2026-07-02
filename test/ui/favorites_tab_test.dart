import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iptv_player/src/app/providers.dart';
import 'package:iptv_player/src/domain/content_type.dart';
import 'package:iptv_player/src/domain/media_item.dart';
import 'package:iptv_player/src/ui/favorites_tab.dart';

void main() {
  testWidgets('muestra favoritos', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        favoritesProvider.overrideWith((ref) async => const [
              MediaItem(
                  id: 'a',
                  name: 'Canal Fav',
                  streamUrl: 'u',
                  type: ContentType.live,
                  isFavorite: true),
            ]),
      ],
      child: const MaterialApp(home: Scaffold(body: FavoritesTab())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Canal Fav'), findsOneWidget);
    // Los chips de grupos están presentes (Todos + crear grupo).
    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Grupo'), findsOneWidget);
  });
}
