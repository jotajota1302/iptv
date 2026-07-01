import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iptv_player/src/app/providers.dart';
import 'package:iptv_player/src/domain/category.dart';
import 'package:iptv_player/src/domain/content_type.dart';
import 'package:iptv_player/src/ui/movies_tab.dart';

void main() {
  testWidgets('lista las categorias de peliculas', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        movieCategoriesProvider.overrideWith((ref) async => const [
              Category(name: 'Estrenos', type: ContentType.movie, itemCount: 5),
            ]),
      ],
      child: const MaterialApp(home: Scaffold(body: MoviesTab())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Estrenos'), findsOneWidget);
    expect(find.text('Películas'), findsOneWidget);
  });
}
