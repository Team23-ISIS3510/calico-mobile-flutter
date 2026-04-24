import 'package:flutter/foundation.dart';
import '../../domain/entities/course_entity.dart';
import '../../domain/entities/session_entity.dart';
import '../../domain/repositories/course_repository.dart';
import '../../domain/repositories/student_tutoring_repository.dart';

enum HomeStatus { idle, loading, success, failure }

/// Loads courses and sessions in parallel, and handles live search filtering.
class HomeController extends ChangeNotifier {
  final CourseRepository _courseRepo;
  final StudentTutoringRepository _tutoringRepo;

  HomeController(this._courseRepo, this._tutoringRepo);

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

  Future<void> loadData(String studentId) async {
    _status = HomeStatus.loading;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _courseRepo.getCourses(),
        _tutoringRepo.getUpcomingSessions(studentId),
      ]).timeout(const Duration(seconds: 20));

      _allCourses = results[0] as List<CourseEntity>;
      _sessions = results[1] as List<SessionEntity>;
      _filteredCourses = List.from(_allCourses);
      _status = HomeStatus.success;
    } catch (e) {
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
