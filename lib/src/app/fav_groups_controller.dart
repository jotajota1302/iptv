import 'dart:convert';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Grupos de favoritos personalizados: nombre → ids de items. Persistidos en
/// SharedPreferences ('fav_groups').
class FavGroupsNotifier extends StateNotifier<Map<String, List<String>>> {
  final SharedPreferences _prefs;
  static const _k = 'fav_groups';

  FavGroupsNotifier(this._prefs) : super(_load(_prefs));

  static Map<String, List<String>> _load(SharedPreferences prefs) {
    final raw = prefs.getString(_k);
    if (raw == null) return const {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in map.entries)
          e.key: [for (final id in e.value as List) '$id'],
      };
    } catch (_) {
      return const {};
    }
  }

  void _persist() => _prefs.setString(_k, jsonEncode(state));

  void createGroup(String name) {
    final n = name.trim();
    if (n.isEmpty || state.containsKey(n)) return;
    state = {...state, n: const []};
    _persist();
  }

  void deleteGroup(String name) {
    state = {...state}..remove(name);
    _persist();
  }

  /// Añade o quita un item de un grupo.
  void toggle(String group, String id) {
    final list = <String>[...(state[group] ?? const <String>[])];
    list.contains(id) ? list.remove(id) : list.add(id);
    state = {...state, group: list};
    _persist();
  }

  bool isIn(String group, String id) => state[group]?.contains(id) ?? false;
}
