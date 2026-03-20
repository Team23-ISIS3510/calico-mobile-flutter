import 'package:flutter/foundation.dart';
import '../../data/models/available_tutor_model.dart';
import '../../data/models/course_model.dart';
import '../../data/models/session_model.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../../domain/repositories/course_repository.dart';
import '../../domain/repositories/session_repository.dart';

enum HomeStatus { idle, loading, success, failure }

/// Loads courses, sessions, and available tutors per course.
/// Tutors load in the background after the main content is shown.
class HomeController extends ChangeNotifier {
  final CourseRepository _courseRepo;
  final SessionRepository _sessionRepo;
  final AnalyticsRepository _analyticsRepo;

  HomeController(this._courseRepo, this._sessionRepo, this._analyticsRepo);

  HomeStatus _status = HomeStatus.idle;
  List<CourseModel> _allCourses = [];
  List<CourseModel> _filteredCourses = [];
  List<SessionModel> _sessions = [];
  final Map<String, List<AvailableTutorModel>> _availableTutors = {};
  String? _error;

  HomeStatus get status => _status;
  List<CourseModel> get courses => _filteredCourses;
  List<SessionModel> get sessions => _sessions;
  Map<String, List<AvailableTutorModel>> get availableTutors => _availableTutors;
  String? get error => _error;
  bool get isLoading => _status == HomeStatus.loading;

  Future<void> loadData(String studentId) async {
    _status = HomeStatus.loading;
    notifyListeners();

    try {
      final results = await Future.wait([
        _courseRepo.getCourses(),
        _sessionRepo.getStudentSessions(studentId),
      ]);

      _allCourses = results[0] as List<CourseModel>;
      _sessions = results[1] as List<SessionModel>;
      _filteredCourses = List.from(_allCourses);
      _status = HomeStatus.success;
      notifyListeners();

      // Load available tutors per course in the background so the main
      // content is shown immediately. Each course updates independently.
      _loadAvailableTutors();
    } on Exception catch (e) {
      _error = e.toString();
      _status = HomeStatus.failure;
      notifyListeners();
    }
  }

  Future<void> _loadAvailableTutors() async {
    await Future.wait(_allCourses.map((course) async {
      try {
        final tutors = await _analyticsRepo.getAvailableTutors(course.id);
        _availableTutors[course.id] = tutors;
        notifyListeners();
      } catch (_) {
        // Silently skip courses with no data or failed requests.
      }
    }));
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
