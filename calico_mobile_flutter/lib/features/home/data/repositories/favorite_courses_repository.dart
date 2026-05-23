import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only favorites for courses. Persisted in SharedPreferences as a
/// `List<String>` of course IDs.
///
/// Reads come from the in-memory [Set] so toggling is instant and rebuilds
/// listening widgets via [changes] without waiting on disk I/O. Writes update
/// memory immediately, then persist best-effort; a transient SharedPreferences
/// failure (e.g. plugin channel unavailable) keeps the favorite in memory for
/// the rest of the session.
class FavoriteCoursesRepository {
  FavoriteCoursesRepository._();

  static const String _prefsKey = 'favorite_course_ids';

  static final Set<String> _ids = <String>{};
  static bool _loaded = false;

  /// Notifies listeners with an immutable snapshot of the favorite course IDs.
  /// Widgets can `ValueListenableBuilder<Set<String>>` on this to react.
  static final ValueNotifier<Set<String>> changes =
      ValueNotifier<Set<String>>(const <String>{});

  /// Loads favorites from disk once per app run. Subsequent calls are no-ops.
  static Future<Set<String>> load() async {
    if (_loaded) return _snapshot();
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_prefsKey) ?? const <String>[];
      _ids
        ..clear()
        ..addAll(stored);
    } catch (_) {
      // Fall back to whatever is already in memory.
    }
    _loaded = true;
    changes.value = _snapshot();
    return changes.value;
  }

  static Set<String> get ids => _snapshot();

  static bool isFavorite(String courseId) => _ids.contains(courseId);

  /// Toggles [courseId] and persists the new set. Returns the resulting state.
  static Future<bool> toggle(String courseId) async {
    final added = _ids.contains(courseId) ? false : true;
    if (added) {
      _ids.add(courseId);
    } else {
      _ids.remove(courseId);
    }
    changes.value = _snapshot();
    await _persist();
    return added;
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_prefsKey, _ids.toList(growable: false));
    } catch (_) {
      // In-memory state already updated; persistence will retry on next toggle.
    }
  }

  static Set<String> _snapshot() => Set<String>.unmodifiable(_ids);
}
