import '../../../../core/network/api_client.dart';
import '../../domain/entities/session_entity.dart';
import '../../domain/entities/tutor_entity.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../../domain/repositories/session_repository.dart';
import '../../domain/repositories/student_tutoring_repository.dart';

class StudentTutoringRepositoryImpl implements StudentTutoringRepository {
  final AnalyticsRepository _analytics;
  final SessionRepository _sessions;
  final ApiClient _apiClient;

  const StudentTutoringRepositoryImpl(
    this._analytics,
    this._sessions,
    this._apiClient,
  );

  @override
  Future<List<TutorEntity>> getAvailableTutorsNext4Hours(String courseId) {
    return _analytics.getAvailableTutors(courseId);
  }

  @override
  Future<TutorEntity?> getGoToTutor(String studentId, String courseId) {
    return _analytics.getReturningTutor(studentId, courseId);
  }

  @override
  Future<List<SessionEntity>> getUpcomingSessions(String studentId) {
    if (studentId.isEmpty) return Future.value(<SessionEntity>[]);
    return _sessions.getStudentSessions(studentId).then((list) {
      final now = DateTime.now();
      final upcoming = list
          .where(
            (s) => s.startDateTime != null && s.startDateTime!.isAfter(now),
          )
          .toList()
        ..sort(
          (a, b) => a.startDateTime!.compareTo(b.startDateTime!),
        );
      return upcoming;
    });
  }

  @override
  Future<void> sendMotionEmergencyAlert({
    required String toEmail,
    String? toName,
    required String studentName,
    required String alertReason,
    String? location,
  }) async {
    await _apiClient.post(
      '/notifications/emergency-alert/email',
      body: {
        'toEmail': toEmail,
        'toName': toName,
        'studentName': studentName,
        'alertReason': alertReason,
        'location': location,
      },
    );
  }

  @override
  Future<void> trackCarouselEvent(
    String event,
    String courseId, {
    String? tutorId,
    double? tutorRating,
    int? resultCount,
    int? countdownMinutes,
  }) {
    return _analytics.trackCarouselEvent(
      event,
      courseId,
      tutorId: tutorId,
      tutorRating: tutorRating,
      resultCount: resultCount,
      countdownMinutes: countdownMinutes,
    );
  }
}
