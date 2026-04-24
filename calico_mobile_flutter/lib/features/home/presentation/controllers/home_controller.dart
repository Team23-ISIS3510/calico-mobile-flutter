import 'package:flutter/foundation.dart';

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
  }

  /// Fetches upcoming sessions for [studentId], via the StudentTutoring
  /// repository (remote → SQLite cache fallback). Exposes `sessionsFromCache`
  /// and `sessionsLastUpdated` so the screen can render the offline notice.
  Future<void> loadSessions(String studentId) async {
    final result = await _tutoringRepo.getUpcomingSessions(studentId);
    _sessions = result.data;
    _sessionsFromCache = result.isFromCache;
    _sessionsLastUpdated = result.lastUpdated;
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
  /// status internally. Wraps the three loaders with [Future.wait] so their
  /// I/O overlaps on the event loop.
  Future<void> loadData(String studentId) async {
    markLoading();
    try {
      await Future.wait([
        loadCourses(studentId),
        loadSessions(studentId),
        loadPendingSessions(studentId),
      ]);
      markSuccess();
    } on Exception catch (e) {
      markFailure(e.toString());
    }
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
