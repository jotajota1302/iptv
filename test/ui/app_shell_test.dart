import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:iptv_player/src/app/providers.dart';
import 'package:iptv_player/src/ui/app_shell.dart';

void main() {
  testWidgets('muestra los 6 destinos de navegacion', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        // Providers del Inicio vacíos para no tocar la base de datos.
        recentMoviesProvider.overrideWith((ref) async => []),
        recentSeriesProvider.overrideWith((ref) async => []),
        continueWatchingProvider.overrideWith((ref) async => []),
        favoritesProvider.overrideWith((ref) async => []),
      ],
      child: const MaterialApp(home: AppShell()),
    ));
    expect(find.text('Inicio'), findsWidgets);
    expect(find.text('TV'), findsWidgets);
    expect(find.text('Películas'), findsWidgets);
    expect(find.text('Series'), findsWidgets);
    expect(find.text('Buscar'), findsWidgets);
    expect(find.text('Ajustes'), findsWidgets);
  });
}
