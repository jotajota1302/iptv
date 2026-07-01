import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:iptv_player/src/app/providers.dart';
import 'package:iptv_player/src/data/playlist_repository.dart';
import 'package:iptv_player/src/domain/category.dart';
import 'package:iptv_player/src/domain/content_type.dart';
import 'package:iptv_player/src/domain/media_item.dart';
import 'package:iptv_player/src/ui/channel_list_screen.dart';

class _MockRepo extends Mock implements PlaylistRepository {}

void main() {
  setUpAll(() => registerFallbackValue(const MediaItem(
      id: 'x', name: 'x', streamUrl: 'x', type: ContentType.live)));

  testWidgets('el menu Ocultar invoca hideItem', (tester) async {
    const item = MediaItem(
        id: 'a', name: 'La 1', streamUrl: 'u', type: ContentType.live);
    final repo = _MockRepo();
    when(() => repo.hideItem(any())).thenAnswer((_) async {});

    await tester.pumpWidget(ProviderScope(
      overrides: [
        playlistRepositoryProvider.overrideWithValue(repo),
        liveByCategoryProvider('Nacionales')
            .overrideWith((ref) async => [item]),
      ],
      child: const MaterialApp(
        home: ChannelListScreen(
            category: Category(name: 'Nacionales', type: ContentType.live)),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ocultar'));
    await tester.pumpAndSettle();

    verify(() => repo.hideItem(any())).called(1);
  });
}
