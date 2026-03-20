import '../../data/models/available_tutor_model.dart';

abstract class AnalyticsRepository {
  Future<List<AvailableTutorModel>> getAvailableTutors(String courseId);
}
