import 'package:flutter/foundation.dart';
import '../../data/models/course_model.dart';
import '../../data/models/session_model.dart';
import '../../domain/repositories/course_repository.dart';
import '../../domain/repositories/session_repository.dart';

enum HomeStatus { idle, loading, success, failure }

/// Loads courses and sessions in parallel, and handles live search filtering.
class HomeController extends ChangeNotifier {
  final CourseRepository _courseRepo;
  final SessionRepository _sessionRepo;

  HomeController(this._courseRepo, this._sessionRepo);

  HomeStatus _status = HomeStatus.idle;
  List<CourseModel> _allCourses = [];
  List<CourseModel> _filteredCourses = [];
  List<SessionModel> _sessions = [];
  String? _error;

  HomeStatus get status => _status;
  List<CourseModel> get courses => _filteredCourses;
  List<SessionModel> get sessions => _sessions;
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
      final now = DateTime.now();
      _sessions = (results[1] as List<SessionModel>)
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
