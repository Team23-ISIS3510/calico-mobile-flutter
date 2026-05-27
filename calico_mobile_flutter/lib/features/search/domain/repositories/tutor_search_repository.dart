import '../../../home/data/models/available_tutor_model.dart';

abstract class TutorSearchRepository {
  /// Returns tutors bookable for [courseId], filtered by [minRating] and [locationType].
  ///
  /// Implementations are expected to cache results so repeated calls with the
  /// same parameters are served instantly without hitting the network.
  Future<List<AvailableTutorModel>> searchTutors({
    required String courseId,
    double minRating = 0.0,
    String locationType = 'all',
  });

  /// Drops the cached results for [courseId] after a successful booking so the
  /// next search reflects the tutor's updated availability.
  void invalidateForCourse(String courseId);
}
