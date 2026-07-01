import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/app_database.dart';
import '../data/m3u_source.dart';
import '../data/playlist_repository.dart';
import '../domain/category.dart';
import '../domain/media_item.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return PlaylistRepository(M3uSource(DioHttpClient()), db);
});

final liveCategoriesProvider = FutureProvider<List<Category>>((ref) {
  return ref.watch(playlistRepositoryProvider).liveCategories();
});

final favoritesProvider = FutureProvider<List<MediaItem>>((ref) {
  return ref.watch(playlistRepositoryProvider).favorites();
});

final searchQueryProvider = StateProvider<String>((_) => '');

final searchResultsProvider = FutureProvider<List<MediaItem>>((ref) {
  final q = ref.watch(searchQueryProvider);
  if (q.trim().isEmpty) return Future.value(<MediaItem>[]);
  return ref.watch(playlistRepositoryProvider).search(q);
});

final loadStateProvider = StateProvider<String?>((_) => null);

final liveByCategoryProvider =
    FutureProvider.family<List<MediaItem>, String>((ref, group) {
  return ref.watch(playlistRepositoryProvider).liveByCategory(group);
});
