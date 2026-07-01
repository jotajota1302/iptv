import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:iptv_player/src/app/providers.dart';
import 'package:iptv_player/src/data/playlist_repository.dart';
import 'package:iptv_player/src/domain/category.dart';
import 'package:iptv_player/src/domain/content_type.dart';
import 'package:iptv_player/src/domain/media_item.dart';
import 'package:iptv_player/src/ui/management_screen.dart';

class _MockRepo extends Mock implements PlaylistRepository {}

void main() {
  setUpAll(() => registerFallbackValue(const MediaItem(
      id: 'x', name: 'x', streamUrl: 'x', type: ContentType.live)));

  testWidgets('muestra estado Oculto y permite restaurar', (tester) async {
    const item = MediaItem(
        id: 'a',
        name: 'Canal Oculto',
        streamUrl: 'u',
        type: ContentType.live,
        isHidden: true);
    final repo = _MockRepo();
    when(() => repo.restoreItem(any())).thenAnswer((_) async {});

    await tester.pumpWidget(ProviderScope(
      overrides: [
        playlistRepositoryProvider.overrideWithValue(repo),
        manageByCategoryProvider((type: ContentType.live, group: 'Nacionales'))
            .overrideWith((ref) async => [item]),
      ],
      child: const MaterialApp(
        home: ManageCategoryScreen(
            category: Category(name: 'Nacionales', type: ContentType.live)),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Canal Oculto'), findsOneWidget);
    expect(find.text('Oculto'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restaurar'));
    await tester.pumpAndSettle();

    verify(() => repo.restoreItem(any())).called(1);
  });
}
