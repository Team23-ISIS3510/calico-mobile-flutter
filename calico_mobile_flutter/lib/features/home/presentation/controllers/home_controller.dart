import 'package:flutter/foundation.dart';
import '../../domain/entities/course_entity.dart';
import '../../domain/entities/session_entity.dart';
import '../../domain/repositories/course_repository.dart';
import '../../domain/repositories/session_repository.dart';

enum HomeStatus { idle, loading, success, failure }

/// Loads courses and sessions in parallel, and handles live search filtering.
class HomeController extends ChangeNotifier {
  final CourseRepository _courseRepo;
  final SessionRepository _sessionRepo;

  HomeController(this._courseRepo, this._sessionRepo);

  HomeStatus _status = HomeStatus.idle;
  List<CourseEntity> _allCourses = [];
  List<CourseEntity> _filteredCourses = [];
  List<SessionEntity> _sessions = [];
  String? _error;

  HomeStatus get status => _status;
  List<CourseEntity> get courses => _filteredCourses;
  List<SessionEntity> get sessions => _sessions;
  String? get error => _error;
  bool get isLoading => _status == HomeStatus.loading;

  /// Top 3 courses the student has had the most sessions in.
  List<CourseModel> get recommendedCourses {
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
        .whereType<CourseModel>()
        .toList();
  }

  Future<void> loadData(String studentId) async {
    _status = HomeStatus.loading;
    notifyListeners();

    try {
      final results = await Future.wait([
        _courseRepo.getCourses(),
        _sessionRepo.getStudentSessions(studentId),
      ]);

      _allCourses = results[0] as List<CourseEntity>;
      final now = DateTime.now();
      _sessions = (results[1] as List<SessionEntity>)
          .where((s) => s.startDateTime != null && s.startDateTime!.isAfter(now))
          .toList()
        ..sort((a, b) => a.startDateTime!.compareTo(b.startDateTime!));
      _filteredCourses = List.from(_allCourses);
      _status = HomeStatus.success;
    } on Exception catch (e) {
      _error = e.toString();
      _status = HomeStatus.failure;
    }

    notifyListeners();
  }

  /// Filters the courses list by name or code. Call on every search keystroke.
  void search(String query) {
    if (query.trim().isEmpty) {
      _filteredCourses = List.from(_allCourses);
    } else {
      final q = query.toLowerCase();
      _filteredCourses = _allCourses
          .where((c) =>
              c.name.toLowerCase().contains(q) ||
              c.code.toLowerCase().contains(q))
          .toList();
    }
    notifyListeners();
  }
}
