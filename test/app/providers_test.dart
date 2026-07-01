import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iptv_player/src/app/providers.dart';
import 'package:iptv_player/src/data/app_database.dart';

void main() {
  test('override de databaseProvider permite resolver el repositorio', () {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    expect(container.read(playlistRepositoryProvider), isNotNull);
  });
}
