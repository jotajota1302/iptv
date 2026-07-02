import 'dart:convert';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/reminder.dart';

/// Recordatorios de programas, persistidos en SharedPreferences.
class RemindersNotifier extends StateNotifier<List<Reminder>> {
  final SharedPreferences _prefs;
  static const _k = 'epg_reminders';

  RemindersNotifier(this._prefs) : super(_load(_prefs));

  static List<Reminder> _load(SharedPreferences prefs) {
    final raw = prefs.getString(_k);
    if (raw == null) return const [];
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          Reminder.fromJson(e as Map<String, dynamic>)
      ];
    } catch (_) {
      return const [];
    }
  }

  void _persist() => _prefs.setString(
      _k, jsonEncode([for (final r in state) r.toJson()]));

  bool contains(String id) => state.any((r) => r.id == id);

  void add(Reminder r) {
    if (contains(r.id)) return;
    state = [...state, r];
    _persist();
  }

  void remove(String id) {
    state = state.where((r) => r.id != id).toList();
    _persist();
  }

  /// Elimina recordatorios ya pasados (más de 10 min desde su inicio).
  void prunePast() {
    final cutoff = DateTime.now().subtract(const Duration(minutes: 10));
    final kept = state.where((r) => r.start.isAfter(cutoff)).toList();
    if (kept.length != state.length) {
      state = kept;
      _persist();
    }
  }
}
