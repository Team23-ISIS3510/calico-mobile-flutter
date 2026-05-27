import 'package:flutter/foundation.dart';

import '../../../home/data/models/available_tutor_model.dart';
import '../../domain/repositories/tutor_search_repository.dart';

enum SearchStatus { idle, loading, success, failure }

/// Holds all mutable state for TutorSearchScreen and drives data fetches.
///
/// The screen owns the connectivity subscription and debounce timer; this
/// controller only manages the repository call and result state so it stays
/// testable in isolation.
class TutorSearchController extends ChangeNotifier {
  final TutorSearchRepository _repo;

  TutorSearchController(this._repo);

  SearchStatus _status = SearchStatus.idle;
  List<AvailableTutorModel> _tutors = [];
  String? _error;

  // Last params used — replayed automatically on reconnect.
  String _lastCourseId = '';
  double _lastMinRating = 0.0;
  String _lastLocationType = 'all';

  SearchStatus get status => _status;
  List<AvailableTutorModel> get tutors => _tutors;
  String? get error => _error;
  bool get isLoading => _status == SearchStatus.loading;

  /// Returns the top-rated tutor with the earliest next slot, or null if the
  /// list is empty. Used by the Auto-Assign row.
  AvailableTutorModel? get topRatedWithEarliestSlot {
    if (_tutors.isEmpty) return null;
    final withSlots = _tutors.where((t) => t.nextSlotStart != null).toList();
    if (withSlots.isEmpty) return _tutors.first;
    withSlots.sort((a, b) {
      final ratingCmp = b.rating.compareTo(a.rating);
      if (ratingCmp != 0) return ratingCmp;
      return a.nextSlotStart!.compareTo(b.nextSlotStart!);
    });
    return withSlots.first;
  }

  Future<void> search({
    required String courseId,
    double minRating = 0.0,
    String locationType = 'all',
  }) async {
    _lastCourseId = courseId;
    _lastMinRating = minRating;
    _lastLocationType = locationType;

    _status = SearchStatus.loading;
    _error = null;
    notifyListeners();

    try {
      _tutors = await _repo.searchTutors(
        courseId: courseId,
        minRating: minRating,
        locationType: locationType,
      );
      _status = SearchStatus.success;
    } catch (e) {
      _error = e.toString();
      _status = SearchStatus.failure;
    }
    notifyListeners();
  }

  /// Re-runs the last search silently (no loading spinner) — called on
  /// reconnect so the screen refreshes without interrupting the user.
  Future<void> replayLastSearch() async {
    if (_lastCourseId.isEmpty) return;
    try {
      final fresh = await _repo.searchTutors(
        courseId: _lastCourseId,
        minRating: _lastMinRating,
        locationType: _lastLocationType,
      );
      _tutors = fresh;
      _status = SearchStatus.success;
      notifyListeners();
    } catch (_) {
      // Silently ignore — keep showing the last known results.
    }
  }

  void invalidateForCourse(String courseId) {
    _repo.invalidateForCourse(courseId);
  }

  void clearResults() {
    _tutors = [];
    _status = SearchStatus.idle;
    _error = null;
    notifyListeners();
  }
}
