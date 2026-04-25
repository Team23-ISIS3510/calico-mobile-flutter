import '../../../../core/storage/cached_result.dart';
import '../entities/session_entity.dart';
import '../entities/tutor_entity.dart';

/// Futures for tutor discovery, upcoming sessions, motion alerts, and analytics
/// tied to the student home / course booking flows.
abstract class StudentTutoringRepository {
  /// Tutors bookable within the next 4 hours for [courseId] (backend window).
  /// Falls back to SQLite cache when the remote call fails.
  Future<CachedResult<List<TutorEntity>>> getAvailableTutorsNext4Hours(
    String courseId,
  );

  /// Most-booked tutor for this student and course, if any. Falls back to
  /// SQLite cache when the remote call fails.
  Future<CachedResult<TutorEntity?>> getGoToTutor(
    String studentId,
    String courseId,
  );

  /// Student sessions with start in the future, ordered by start time. Falls
  /// back to SQLite cache when the remote call fails.
  Future<CachedResult<List<SessionEntity>>> getUpcomingSessions(
    String studentId,
  );

  Future<void> sendMotionEmergencyAlert({
    required String toEmail,
    String? toName,
    required String studentName,
    required String alertReason,
    String? location,
  });

  Future<void> trackCarouselEvent(
    String event,
    String courseId, {
    String? tutorId,
    double? tutorRating,
    int? resultCount,
    int? countdownMinutes,
  });
}
