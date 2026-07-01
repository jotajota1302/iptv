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
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const MaterialApp(home: AppShell()),
    ));
    expect(find.text('TV'), findsWidgets);
    expect(find.text('Películas'), findsWidgets);
    expect(find.text('Series'), findsWidgets);
    expect(find.text('Favoritos'), findsWidgets);
    expect(find.text('Buscar'), findsWidgets);
    expect(find.text('Ajustes'), findsWidgets);
  });
}
