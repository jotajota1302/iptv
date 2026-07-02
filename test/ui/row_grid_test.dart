import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/ui/widgets/row_grid.dart';

Widget _app(double width, Widget child) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: Scaffold(
          body: SizedBox(width: width, child: child),
        ),
      ),
    );

void main() {
  testWidgets('en escritorio reparte las filas en varias columnas',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(
      1600,
      RowGrid(
        itemCount: 4,
        itemBuilder: (_, i) => ListTile(key: ValueKey(i), title: Text('$i')),
      ),
    ));
    // Con 1600px y tiles de máx 470px caben varias columnas: el segundo
    // tile comparte fila (misma Y) con el primero.
    final p0 = tester.getTopLeft(find.byKey(const ValueKey(0)));
    final p1 = tester.getTopLeft(find.byKey(const ValueKey(1)));
    expect(p0.dy, p1.dy);
    expect(p1.dx, greaterThan(p0.dx));
  });

  testWidgets('en móvil mantiene una sola columna', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(
      400,
      RowGrid(
        itemCount: 3,
        itemBuilder: (_, i) => ListTile(key: ValueKey(i), title: Text('$i')),
      ),
    ));
    final p0 = tester.getTopLeft(find.byKey(const ValueKey(0)));
    final p1 = tester.getTopLeft(find.byKey(const ValueKey(1)));
    expect(p0.dx, p1.dx);
    expect(p1.dy, greaterThan(p0.dy));
  });
}
