import '../entities/tutor_entity.dart';

abstract class AnalyticsRepository {
  Future<List<TutorEntity>> getAvailableTutors(String courseId);
  Future<TutorEntity?> getReturningTutor(String studentId, String courseId);
}
