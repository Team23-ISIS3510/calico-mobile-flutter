import '../../domain/entities/session_entity.dart';
import '../../domain/entities/tutor_entity.dart';

/// Client-side rules that keep tutor availability aligned with the student's
/// pending and upcoming sessions (Calendly-style: a reserved slot disappears
/// from the bookable list even before the server reflects the booking).
class BookingAvailabilityService {
  BookingAvailabilityService._();

  static const Duration _slotGrace = Duration(minutes: 5);

  /// Merges upcoming and locally queued sessions into one list for UI guards.
  static List<SessionEntity> mergeStudentSessions({
    required List<SessionEntity> upcoming,
    required List<SessionEntity> pending,
  }) {
    return [...upcoming, ...pending];
  }

  /// True when the tutor's advertised next slot is still in the future.
  static bool isSlotStillBookable(TutorEntity tutor) {
    final start = tutor.nextSlotStart;
    if (start == null) return false;
    return start.isAfter(DateTime.now().subtract(_slotGrace));
  }

  /// Whether this tutor should be hidden from the carousel for [courseId].
  static bool conflictsWithStudentSessions(
    TutorEntity tutor,
    List<SessionEntity> sessions,
    String courseId,
  ) {
    for (final session in sessions) {
      if (session.tutorId != tutor.id) continue;
      final sessionCourse = session.courseId;
      if (sessionCourse != null &&
          sessionCourse.isNotEmpty &&
          sessionCourse != courseId) {
        continue;
      }
      return true;
    }
    return false;
  }

  /// Human-readable reason when [conflictsWithStudentSessions] is true.
  static String? blockReason(
    TutorEntity tutor,
    List<SessionEntity> sessions,
    String courseId,
  ) {
    if (!isSlotStillBookable(tutor)) {
      return 'This time slot is no longer available.';
    }
    if (!conflictsWithStudentSessions(tutor, sessions, courseId)) return null;

    final pending = sessions.where(
      (s) =>
          s.tutorId == tutor.id &&
          s.status == 'pending_local' &&
          (s.courseId == null || s.courseId == courseId),
    );
    if (pending.isNotEmpty) {
      return 'You already have a pending booking with ${tutor.name}.';
    }
    return 'You already have a session with ${tutor.name} for this course.';
  }

  /// Filters API/cached tutors to those the student can still book.
  static List<TutorEntity> filterBookableTutors(
    List<TutorEntity> tutors,
    List<SessionEntity> sessions,
    String courseId,
  ) {
    return tutors
        .where(
          (t) =>
              isSlotStillBookable(t) &&
              !conflictsWithStudentSessions(t, sessions, courseId),
        )
        .toList(growable: false);
  }

  /// Whether [tutor] should still appear in the Go-To section.
  static bool shouldShowGoToTutor(
    TutorEntity? tutor,
    List<SessionEntity> sessions,
    String courseId,
  ) {
    if (tutor == null) return false;
    return isSlotStillBookable(tutor) &&
        !conflictsWithStudentSessions(tutor, sessions, courseId);
  }
}
