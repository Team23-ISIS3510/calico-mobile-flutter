import '../entities/session_entity.dart';

/// BQ17 — For a given student, how many days have passed since their last
/// tutoring session in each favorite course?
///
/// Pure domain logic: maps session history to per-course recency in calendar
/// days. The Courses screen renders these values directly on favorite chips.
class CourseSessionRecency {
  CourseSessionRecency._();

  /// Days without a session before we suggest booking again.
  static const int nudgeThresholdDays = 7;

  static const Set<String> _excludedStatuses = {
    'cancelled',
    'rejected',
    'declined',
    'no_show',
  };

  /// Returns the number of whole calendar days since the most recent past
  /// tutoring session per [courseId]. A missing key means no qualifying session.
  static Map<String, int> daysSinceLastSessionByCourse(
    Iterable<SessionEntity> sessions, {
    DateTime? reference,
  }) {
    final now = _dateOnly(reference ?? DateTime.now());
    final latestByCourse = <String, DateTime>{};

    for (final session in sessions) {
      final courseId = session.courseId;
      final start = session.startDateTime;
      if (courseId == null ||
          courseId.isEmpty ||
          start == null ||
          !_countsAsPastSession(session, reference: reference)) {
        continue;
      }

      final sessionDay = _dateOnly(start);
      if (sessionDay.isAfter(now)) continue;

      final current = latestByCourse[courseId];
      if (current == null || sessionDay.isAfter(current)) {
        latestByCourse[courseId] = sessionDay;
      }
    }

    return {
      for (final entry in latestByCourse.entries)
        entry.key: now.difference(entry.value).inDays,
    };
  }

  /// [daysSince] is `null` when the student has never had a qualifying session
  /// in that course.
  static String labelFor(int? daysSince) {
    if (daysSince == null) return 'No sessions yet';
    if (daysSince == 0) return 'Last session today';
    if (daysSince == 1) return 'Last session yesterday';
    return 'Last session $daysSince days ago';
  }

  /// Whether the UI should nudge the student to book again.
  static bool shouldNudge(int? daysSince) =>
      daysSince == null || daysSince >= nudgeThresholdDays;

  static String nudgeLabel(int? daysSince) =>
      daysSince == null ? 'Book your first session' : 'Time to book again';

  static bool _countsAsPastSession(
    SessionEntity session, {
    DateTime? reference,
  }) {
    final status = session.status.toLowerCase();
    if (_excludedStatuses.contains(status)) return false;

    final start = session.startDateTime;
    if (start == null) return false;

    final now = reference ?? DateTime.now();
    return !start.isAfter(now);
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
