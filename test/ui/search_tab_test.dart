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
    await tester.pumpAndSettle();
    expect(find.text('La 1'), findsOneWidget);
  });
}
