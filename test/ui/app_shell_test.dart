import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/ui/app_shell.dart';

void main() {
  testWidgets('muestra los 4 destinos de navegacion', (tester) async {
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: AppShell()),
    ));
    expect(find.text('TV'), findsWidgets);
    expect(find.text('Favoritos'), findsWidgets);
    expect(find.text('Buscar'), findsWidgets);
    expect(find.text('Ajustes'), findsWidgets);
  });
}
