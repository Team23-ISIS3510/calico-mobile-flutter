import 'package:flutter/foundation.dart';
import '../../domain/entities/course_entity.dart';
import '../../domain/entities/session_entity.dart';
import '../../domain/repositories/course_repository.dart';
import '../../domain/repositories/session_repository.dart';
import '../../../../core/utils/course_filter_isolate.dart';

enum HomeStatus { idle, loading, success, failure }

/// Manages courses, sessions, and search state for the Home screen.
///
/// Data is loaded concurrently via [loadCourses] and [loadSessions], which are
/// designed to be called together inside a [Future.wait] in the screen's
/// [initState]. Status transitions ([markLoading], [markSuccess], [markFailure])
/// are driven by the screen so the screen controls the concurrency strategy.
class HomeController extends ChangeNotifier {
  final CourseRepository _courseRepo;
  final SessionRepository _sessionRepo;

  HomeController(this._courseRepo, this._sessionRepo);

  HomeStatus _status = HomeStatus.idle;
  List<CourseEntity> _allCourses = [];
  List<CourseEntity> _filteredCourses = [];
  List<SessionEntity> _sessions = [];
  String? _error;

  // Tracks the most recent search query to discard stale isolate results.
  String _lastSearchQuery = '';

  HomeStatus get status => _status;
  List<CourseEntity> get courses => _filteredCourses;
  List<SessionEntity> get sessions => _sessions;
  String? get error => _error;
  bool get isLoading => _status == HomeStatus.loading;

  /// Top 3 courses the student has had the most tutoring sessions in.
  List<CourseEntity> get recommendedCourses {
    if (_sessions.isEmpty || _allCourses.isEmpty) return [];
    final counts = <String, int>{};
    for (final s in _sessions) {
      if (s.courseId != null && s.courseId!.isNotEmpty) {
        counts[s.courseId!] = (counts[s.courseId!] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final courseMap = {for (final c in _allCourses) c.id: c};
    return sorted
        .take(3)
        .map((e) => courseMap[e.key])
        .whereType<CourseEntity>()
        .toList();
  }

  // ── Status helpers ────────────────────────────────────────────────────────

  /// Transitions to the loading state. Call before starting parallel fetches.
  void markLoading() {
    _status = HomeStatus.loading;
    _error = null;
    notifyListeners();
  }

  /// Transitions to success once all parallel fetches have completed.
  void markSuccess() {
    _status = HomeStatus.success;
    notifyListeners();
  }

  /// Transitions to failure and stores an error message.
  void markFailure(String errorMessage) {
    _error = errorMessage;
    _status = HomeStatus.failure;
    notifyListeners();
  }

  // ── Individual loaders ────────────────────────────────────────────────────

  /// Fetches the full course list and resets the active filter.
  ///
  /// Designed to run concurrently alongside [loadSessions] inside a
  /// [Future.wait] call. Does not touch [status] — the caller controls
  /// status transitions via [markLoading] / [markSuccess] / [markFailure].

  Future<void> loadCourses(String studentId) async {
    debugPrint('loadCourses START ${DateTime.now()}');
    _allCourses = await _courseRepo.getCourses();
    _filteredCourses = List.from(_allCourses);
    debugPrint('loadCourses END ${DateTime.now()}');
  }

  /// Fetches upcoming sessions for [studentId], sorted by start time.
  ///
  /// Designed to run concurrently alongside [loadCourses] inside a
  /// [Future.wait] call. Past sessions are discarded at load time.
  Future<void> loadSessions(String studentId) async {
    debugPrint('loadSessions START ${DateTime.now()}');
    final raw = await _sessionRepo.getStudentSessions(studentId);
    final now = DateTime.now();
    _sessions =
        raw
            .where(
              (s) => s.startDateTime != null && s.startDateTime!.isAfter(now),
            )
            .toList()
          ..sort((a, b) => a.startDateTime!.compareTo(b.startDateTime!));
    debugPrint('loadSessions END ${DateTime.now()}');
  }

  // ── Convenience loader (used by the retry button) ─────────────────────────

  /// Loads both courses and sessions in parallel, managing status internally.
  ///
  /// Wraps [loadCourses] and [loadSessions] with [Future.wait] so both network
  /// calls overlap on the event loop. The retry button in the UI calls this
  /// directly instead of rebuilding the whole [Future.wait] chain.
  Future<void> loadData(String studentId) async {
    markLoading();
    try {
      await Future.wait([loadCourses(studentId), loadSessions(studentId)]);
      markSuccess();
    } on Exception catch (e) {
      markFailure(e.toString());
    }
  }

  // ── Search ────────────────────────────────────────────────────────────────

  /// Filters courses by [query] in a background Isolate via [filterCoursesInIsolate].
  ///
  /// Fires a new Isolate computation on every keystroke. Stale results are
  /// discarded by comparing [query] against [_lastSearchQuery] when the
  /// future resolves — only the most recent query updates the UI. This
  /// prevents out-of-order results when the user types quickly.
  void search(String query) {
    _lastSearchQuery = query;
    filterCoursesInIsolate(_allCourses, query).then((filtered) {
      if (_lastSearchQuery == query) {
        _filteredCourses = filtered;
        notifyListeners();
      }
    });
  }
}
