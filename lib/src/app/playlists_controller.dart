import 'dart:convert';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/saved_playlist.dart';

/// Estado de las listas guardadas y cuál está activa.
class PlaylistsState {
  final List<SavedPlaylist> playlists;
  final String? activeId;
  const PlaylistsState(this.playlists, this.activeId);

  SavedPlaylist? get active {
    for (final p in playlists) {
      if (p.id == activeId) return p;
    }
    return null;
  }
}

/// Gestiona la persistencia de las listas guardadas en SharedPreferences.
class PlaylistsNotifier extends StateNotifier<PlaylistsState> {
  final SharedPreferences _prefs;
  static const _kList = 'playlists';
  static const _kActive = 'active_playlist_id';

  PlaylistsNotifier(this._prefs) : super(_load(_prefs));

  static PlaylistsState _load(SharedPreferences prefs) {
    final raw = prefs.getString(_kList);
    final list = raw == null
        ? <SavedPlaylist>[]
        : (jsonDecode(raw) as List)
            .map((e) => SavedPlaylist.fromJson(e as Map<String, dynamic>))
            .toList();
    return PlaylistsState(list, prefs.getString(_kActive));
  }

  void _persist() {
    _prefs.setString(_kList,
        jsonEncode(state.playlists.map((e) => e.toJson()).toList()));
    final a = state.activeId;
    if (a != null) {
      _prefs.setString(_kActive, a);
    } else {
      _prefs.remove(_kActive);
    }
  }

  /// Añade una lista y la marca como activa.
  void add(SavedPlaylist playlist) {
    state = PlaylistsState([...state.playlists, playlist], playlist.id);
    _persist();
  }

  /// Elimina una lista; si era la activa, activa la primera restante.
  void remove(String id) {
    final list = state.playlists.where((e) => e.id != id).toList();
    final active = state.activeId == id
        ? (list.isNotEmpty ? list.first.id : null)
        : state.activeId;
    state = PlaylistsState(list, active);
    _persist();
  }

  /// Marca una lista como activa.
  void setActive(String id) {
    state = PlaylistsState(state.playlists, id);
    _persist();
  }
}
