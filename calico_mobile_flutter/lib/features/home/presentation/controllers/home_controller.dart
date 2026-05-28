import 'package:flutter/foundation.dart';

import '../../../../core/cache/array_map.dart';
import '../../../../core/local/pending_sessions_database.dart';
import '../../../../core/utils/course_filter_isolate.dart';
import '../../domain/entities/course_entity.dart';
import '../../domain/entities/session_entity.dart';
import '../../domain/repositories/course_repository.dart';
import '../../domain/repositories/student_tutoring_repository.dart';

enum HomeStatus { idle, loading, success, failure }

/// Manages courses, sessions, and search state for the Home screen.
///
/// Data is loaded concurrently via [loadCourses] and [loadSessions], designed
/// to be called together inside a [Future.wait] in the screen's [initState].
/// Status transitions ([markLoading], [markSuccess], [markFailure]) are driven
/// by the screen so the screen controls the concurrency strategy.
class HomeController extends ChangeNotifier {
  final CourseRepository _courseRepo;
  final StudentTutoringRepository _tutoringRepo;

  HomeController(this._courseRepo, this._tutoringRepo);

  HomeStatus _status = HomeStatus.idle;
  List<CourseEntity> _allCourses = [];
  List<CourseEntity> _filteredCourses = [];
  List<SessionEntity> _sessions = [];
  bool _sessionsFromCache = false;
  DateTime? _sessionsLastUpdated;
  // Sessions queued in SQLite while offline — shown with a ⏳ badge.
  List<SessionEntity> _pendingSessions = [];
  String? _error;

  // ArrayMap<courseId, sessionCount> — built once per loadSessions call and
  // reused on every recommendedCourses access. ArrayMap is the right fit here
  // because the collection is small (≤ number of distinct courses, typically
  // ≤ 10), reads dominate (every build() call reads it, writes happen only
  // when sessions reload), and the O(log n) binary search is effectively O(1)
  // for n ≤ 10 — at most 4 comparisons. Null signals the cache is stale and
  // must be rebuilt before use.
  ArrayMap<String, int>? _sessionCountCache;

  // Micro-optimization 2: cached recommended courses list.
  // Rebuilt only when _sessions or _allCourses change (via loadSessions /
  // loadCourses). The public getter returns this list as-is, so rebuilds
  // triggered by unrelated notifyListeners() calls (e.g. each keystroke in
  // the search bar) no longer re-run sort + map + toList.
  List<CourseEntity> _recommendedCourses = const [];

  // Tracks the most recent search query to discard stale isolate results.
  String _lastSearchQuery = '';

  HomeStatus get status => _status;
  List<CourseEntity> get courses => _filteredCourses;
  List<SessionEntity> get sessions => _sessions;
  bool get sessionsFromCache => _sessionsFromCache;
  DateTime? get sessionsLastUpdated => _sessionsLastUpdated;
  List<SessionEntity> get pendingSessions => _pendingSessions;
  String? get error => _error;
  bool get isLoading => _status == HomeStatus.loading;

  /// Top 3 courses the student has had the most sessions in.
  /// Reads from a precomputed cache; no work is done on each access.
  List<CourseEntity> get recommendedCourses => _recommendedCourses;

  void _rebuildRecommendedCourses() {
    if (_sessions.isEmpty || _allCourses.isEmpty) {
      _recommendedCourses = const [];
      return;
    }
    _sessionCountCache ??= _buildSessionCounts();
    final courseMap = {for (final c in _allCourses) c.id: c};
    _recommendedCourses = (_sessionCountCache!.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(3)
        .map((e) => courseMap[e.key])
        .whereType<CourseEntity>()
        .toList(growable: false);
  }

  ArrayMap<String, int> _buildSessionCounts() {
    final counts = ArrayMap<String, int>();
    for (final s in _sessions) {
      if (s.courseId != null && s.courseId!.isNotEmpty) {
        counts[s.courseId!] = (counts[s.courseId!] ?? 0) + 1;
      }
    }
    return counts;
  }

  // ── Status helpers ────────────────────────────────────────────────────────

  void markLoading() {
    _status = HomeStatus.loading;
    _error = null;
    notifyListeners();
  }

  void markSuccess() {
    _status = HomeStatus.success;
    notifyListeners();
  }

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
    _allCourses = await _courseRepo.getCourses();
    _filteredCourses = List.from(_allCourses);
    _rebuildRecommendedCourses();
  }

  /// Fetches upcoming sessions for [studentId], via the StudentTutoring
  /// repository (remote → SQLite cache fallback). Exposes `sessionsFromCache`
  /// and `sessionsLastUpdated` so the screen can render the offline notice.
  Future<void> loadSessions(String studentId) async {
    final result = await _tutoringRepo.getUpcomingSessions(studentId);
    _sessions = result.data;
    _sessionsFromCache = result.isFromCache;
    _sessionsLastUpdated = result.lastUpdated;
    _sessionCountCache = null; // invalidate so recommendedCourses rebuilds
    _rebuildRecommendedCourses();
  }

  /// Reads all unsynced rows from the local pending_sessions table and
  /// exposes them as [SessionEntity] objects so the home screen can render
  /// them alongside confirmed sessions with a ⏳ badge.
  ///
  /// Uses status = 'pending_local' as a sentinel so [SessionCard] can detect
  /// and badge these rows without any extra field on [SessionEntity].
  Future<void> loadPendingSessions(String studentId) async {
    try {
      final rows =
          await PendingSessionsDatabase.instance.getUnsynced(studentId);
      _pendingSessions = rows
          .map(
            (r) => SessionEntity(
              id: 'pending_${r.id}',
              tutorId: r.tutorId,
              studentId: r.studentId,
              startDateTime: DateTime.tryParse(r.scheduledStart),
              endDateTime: DateTime.tryParse(r.scheduledEnd),
              courseId: r.courseId,
              tutorName: r.tutorName,
              status: 'pending_local',
            ),
          )
          .toList()
        ..sort(
          (a, b) => (a.startDateTime ?? DateTime.now())
              .compareTo(b.startDateTime ?? DateTime.now()),
        );
    } catch (_) {
      _pendingSessions = [];
    }
    notifyListeners();
  }

  // ── Convenience loader (used by the retry button) ─────────────────────────

  /// Loads courses, sessions, and pending sessions in parallel, managing
  /// status internally. Partial success is allowed: if courses load but
  /// sessions fail (or vice versa), the screen still renders what it can.
  Future<void> loadData(String studentId) async {
    markLoading();
    Object? coursesError;
    Object? sessionsError;

    try {
      await loadCourses(studentId);
    } catch (e) {
      coursesError = e;
    }

    try {
      await loadSessions(studentId);
    } catch (e) {
      sessionsError = e;
    }

    await loadPendingSessions(studentId);

    _reapplyActiveSearch();

    final hasCourses = _allCourses.isNotEmpty;
    final hasSessions = _sessions.isNotEmpty || _pendingSessions.isNotEmpty;
    final guestWithoutSessions = studentId.trim().isEmpty;

    if (hasCourses || hasSessions || guestWithoutSessions) {
      if (coursesError != null || sessionsError != null) {
        _error = _partialLoadMessage(coursesError, sessionsError);
      } else {
        _error = null;
      }
      markSuccess();
      return;
    }

    markFailure(
      coursesError?.toString() ??
          sessionsError?.toString() ??
          'Could not load home data.',
    );
  }

  void _reapplyActiveSearch() {
    if (_lastSearchQuery.trim().isEmpty) return;
    search(_lastSearchQuery);
  }

  String? _partialLoadMessage(Object? coursesError, Object? sessionsError) {
    if (coursesError != null && sessionsError != null) {
      return 'Some home data could not be refreshed. Showing what is available.';
    }
    if (coursesError != null) {
      return 'Courses could not be refreshed. Showing cached sessions if available.';
    }
    if (sessionsError != null) {
      return 'Sessions could not be refreshed. Course list is still available.';
    }
    return null;
  }

  // ── Search ────────────────────────────────────────────────────────────────

  /// Filters courses by [query] in a background Isolate via
  /// [filterCoursesInIsolate]. Stale results are discarded by comparing
  /// [query] against [_lastSearchQuery] when the future resolves so
  /// out-of-order results never clobber the UI when the user types quickly.
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
