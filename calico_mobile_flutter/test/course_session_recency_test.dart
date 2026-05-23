import 'package:calico_mobile_flutter/features/home/domain/entities/session_entity.dart';
import 'package:calico_mobile_flutter/features/home/domain/services/course_session_recency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final reference = DateTime(2026, 5, 22, 15, 30);

  SessionEntity session({
    required String courseId,
    required DateTime start,
    String status = 'completed',
  }) {
    return SessionEntity(
      id: 's-$courseId-${start.millisecondsSinceEpoch}',
      tutorId: 'tutor-1',
      studentId: 'student-1',
      startDateTime: start,
      courseId: courseId,
      status: status,
    );
  }

  group('CourseSessionRecency.daysSinceLastSessionByCourse', () {
    test('returns calendar days since the latest past session per course', () {
      final sessions = [
        session(courseId: 'c1', start: DateTime(2026, 5, 20, 10)),
        session(courseId: 'c1', start: DateTime(2026, 5, 10, 10)),
        session(courseId: 'c2', start: DateTime(2026, 5, 21, 18)),
      ];

      final result = CourseSessionRecency.daysSinceLastSessionByCourse(
        sessions,
        reference: reference,
      );

      expect(result['c1'], 2);
      expect(result['c2'], 1);
    });

    test('ignores cancelled sessions and future sessions', () {
      final sessions = [
        session(
          courseId: 'c1',
          start: DateTime(2026, 5, 1),
          status: 'cancelled',
        ),
        session(courseId: 'c1', start: DateTime(2026, 5, 25)),
        session(courseId: 'c2', start: DateTime(2026, 5, 15)),
      ];

      final result = CourseSessionRecency.daysSinceLastSessionByCourse(
        sessions,
        reference: reference,
      );

      expect(result.containsKey('c1'), isFalse);
      expect(result['c2'], 7);
    });
  });

  group('CourseSessionRecency labels and nudges', () {
    test('formats user-facing recency copy', () {
      expect(CourseSessionRecency.labelFor(null), 'No sessions yet');
      expect(CourseSessionRecency.labelFor(0), 'Last session today');
      expect(CourseSessionRecency.labelFor(1), 'Last session yesterday');
      expect(CourseSessionRecency.labelFor(14), 'Last session 14 days ago');
    });

    test('nudges when never booked or stale', () {
      expect(CourseSessionRecency.shouldNudge(null), isTrue);
      expect(CourseSessionRecency.shouldNudge(6), isFalse);
      expect(CourseSessionRecency.shouldNudge(7), isTrue);
      expect(
        CourseSessionRecency.nudgeLabel(null),
        'Book your first session',
      );
      expect(CourseSessionRecency.nudgeLabel(10), 'Time to book again');
    });
  });
}
