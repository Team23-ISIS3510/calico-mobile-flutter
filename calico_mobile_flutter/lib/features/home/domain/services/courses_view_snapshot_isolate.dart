import 'package:flutter/foundation.dart';

import '../entities/course_entity.dart';
import '../entities/session_entity.dart';
import 'course_session_recency.dart';

/// Input for [prepareCoursesViewInIsolate].
///
/// Course identity is passed as parallel `List<String>` arrays (id + name)
/// rather than full [CourseEntity] objects so the payload crossing the
/// isolate boundary stays minimal: the isolate only needs IDs to filter and
/// names to break sort ties.
class CoursesViewSnapshotParams {
  final List<SessionEntity> sessions;
  final Set<String> favoriteIds;
  final List<String> allCourseIds;
  final List<String> allCourseNames;

  const CoursesViewSnapshotParams({
    required this.sessions,
    required this.favoriteIds,
    required this.allCourseIds,
    required this.allCourseNames,
  });
}

/// Output of [prepareCoursesViewInIsolate].
///
/// Serializable, position-independent result that the UI maps back to
/// `List<CourseEntity>` on the main thread in O(n).
class CoursesViewSnapshot {
  /// BQ6 answer: per-course recency in whole calendar days.
  final Map<String, int> daysSinceLastSession;

  /// Favorite course IDs ordered to surface the ones that need attention:
  /// never-booked favorites first, then favorites by `daysSinceLastSession`
  /// DESC (stalest practice first), ties broken alphabetically by course name.
  /// This matches the "Time to book again" nudge — the row most likely to need
  /// a fresh booking shows up at the start of the strip.
  final List<String> sortedFavoriteCourseIds;

  const CoursesViewSnapshot({
    required this.daysSinceLastSession,
    required this.sortedFavoriteCourseIds,
  });

  static const CoursesViewSnapshot empty = CoursesViewSnapshot(
    daysSinceLastSession: {},
    sortedFavoriteCourseIds: [],
  );
}

/// Off-main-thread version of BQ6 + favorites ordering.
///
/// Runs on a background isolate via [compute] so the Courses screen can open
/// without a frame drop when the student has a large session history (hundreds
/// or thousands of past sessions). The function is pure: it only depends on
/// [CourseSessionRecency], which itself has no Flutter / I/O dependencies.
Future<CoursesViewSnapshot> prepareCoursesViewInIsolate({
  required List<SessionEntity> sessions,
  required Set<String> favoriteIds,
  required List<CourseEntity> allCourses,
}) {
  // Short-circuit on the main thread when there is no work — spawning an
  // isolate costs ~1–2 ms even for an empty payload.
  if (favoriteIds.isEmpty && sessions.isEmpty) {
    return Future.value(CoursesViewSnapshot.empty);
  }
  return compute(
    _computeCoursesViewSnapshot,
    CoursesViewSnapshotParams(
      sessions: sessions,
      favoriteIds: favoriteIds,
      allCourseIds: allCourses
          .map((c) => c.id)
          .toList(growable: false),
      allCourseNames: allCourses
          .map((c) => c.name)
          .toList(growable: false),
    ),
  );
}

// Top-level so the Dart VM can capture it for the isolate entry point.
CoursesViewSnapshot _computeCoursesViewSnapshot(
  CoursesViewSnapshotParams params,
) {
  final days = CourseSessionRecency.daysSinceLastSessionByCourse(
    params.sessions,
  );

  // Build (id, name) entries for favorites only, then sort.
  final favorites = <_FavoriteSortEntry>[];
  for (var i = 0; i < params.allCourseIds.length; i++) {
    final id = params.allCourseIds[i];
    if (params.favoriteIds.contains(id)) {
      favorites.add(_FavoriteSortEntry(id, params.allCourseNames[i]));
    }
  }

  // Same ordering as the previous main-thread implementation: never-booked
  // favorites lead, then favorites by days-since DESC (stalest first) so the
  // student is prompted to re-book what they've been neglecting.
  favorites.sort((a, b) {
    final daysA = days[a.id];
    final daysB = days[b.id];
    if (daysA == null && daysB == null) {
      return a.name.compareTo(b.name);
    }
    if (daysA == null) return -1;
    if (daysB == null) return 1;
    final byRecency = daysB.compareTo(daysA);
    return byRecency != 0 ? byRecency : a.name.compareTo(b.name);
  });

  return CoursesViewSnapshot(
    daysSinceLastSession: days,
    sortedFavoriteCourseIds:
        favorites.map((e) => e.id).toList(growable: false),
  );
}

class _FavoriteSortEntry {
  final String id;
  final String name;
  const _FavoriteSortEntry(this.id, this.name);
}
