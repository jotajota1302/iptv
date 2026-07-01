import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iptv_player/src/app/providers.dart';
import 'package:iptv_player/src/data/playlist_repository.dart';
import 'package:iptv_player/src/ui/settings_tab.dart';

class _MockRepo extends Mock implements PlaylistRepository {}

void main() {
  testWidgets('cargar URL invoca al repositorio', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _MockRepo();
    when(() => repo.loadFromUrl(any())).thenAnswer((_) async => 42);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        playlistRepositoryProvider.overrideWithValue(repo),
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(home: Scaffold(body: SettingsTab())),
    ));
    await tester.enterText(
        find.widgetWithText(TextField, 'URL de la lista'), 'http://x/list.m3u');
    await tester.tap(find.text('Añadir y cargar'));
    await tester.pump();
    verify(() => repo.loadFromUrl('http://x/list.m3u')).called(1);
  });
}
