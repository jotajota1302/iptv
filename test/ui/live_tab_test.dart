import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iptv_player/src/app/providers.dart';
import 'package:iptv_player/src/domain/category.dart';
import 'package:iptv_player/src/domain/content_type.dart';
import 'package:iptv_player/src/ui/live_tab.dart';

void main() {
  testWidgets('lista las categorias en directo', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        liveCategoriesProvider.overrideWith((ref) async => const [
              Category(name: 'Nacionales', type: ContentType.live, itemCount: 3),
            ]),
      ],
      child: const MaterialApp(home: Scaffold(body: LiveTab())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Nacionales'), findsOneWidget);
  });
}
