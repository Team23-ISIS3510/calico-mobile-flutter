// Autonomous tuning for the L1 in-memory layer that sits *above* the existing
// L2 disk caches (SQLite go-to / upcoming, Hive carousel) and L3 HTTP.
//
// ── How this maps to Android / iOS primitives ─────────────────────────────
//
// LRU (LinkedHashMap inside [LRUCache]):
//   Same eviction story as android.util.LruCache: bounded entry count, O(1)
//   get/put, least-recently-used dropped when full.
//
// ArrayMap:
//   Already used in [HomeController] for small derived maps (courseId →
//   session counts). We do not duplicate ArrayMap here — the policy below only
//   covers *remote-shaped* blobs (tutor, session list) keyed for LRU.
//
// SparseArray:
//   Android optimizes int → Object without autoboxing. Our domain keys are
//   opaque string ids (student, course), not dense integers, so a string-keyed
//   LRU (HashMap/LinkedHashMap) is the correct analogue; a SparseArray would
//   not buy anything unless we redesigned keys to numeric surrogates.
//
// NSCache:
//   iOS evicts under memory pressure in addition to count limits. Flutter/Dart
//   does not expose a reliable process-level memory-pressure hook for caches,
//   so we approximate NSCache with an explicit [maxSize] (count limit) plus
//   [ttl] (time limit) — bounding both footprint and staleness deterministically.

/// Named constants for L1 caches backing home-related HTTP reads.
///
/// Values are chosen to complement (not replace) what is already implemented:
/// - [StudentTutoringRepositoryImpl] still persists successful payloads to L2.
/// - L1 only avoids duplicate network work during a single app session when
///   the user navigates home ↔ course detail or triggers overlapping loads.
class HomeRemoteMemoryCachePolicy {
  HomeRemoteMemoryCachePolicy._();

  // ── Returning tutor (`/analytics/returning-tutor`) ───────────────────────
  //
  // maxSize 24 — upper bound on hot (studentId, courseId) pairs in one session
  // (several courses opened from home + LRU eviction of cold pairs). Matches
  // the same order of magnitude as the bookable-tutors LRU (10 courses) but
  // allows a few extra tuples before eviction because the key is 2D.
  //
  // ttl 4 minutes — slightly shorter than the bookable-tutors carousel TTL
  // (5 min): "who is your returning tutor" is relationship-level data and
  // changes less often than slot-level availability, but we still want it to
  // refresh a bit sooner than the carousel so the two layers rarely disagree
  // for long after a backend change.
  static const int returningTutorMaxEntries = 24;
  static const Duration returningTutorTtl = Duration(minutes: 4);

  // ── Full student session list (`/tutoring-sessions/student/:id`) ─────────
  //
  // This list is filtered/sorted into "upcoming" inside
  // [StudentTutoringRepositoryImpl]; caching here dedupes the expensive HTTP
  // and JSON parse when the same student is loaded repeatedly.
  //
  // maxSize 4 — one slot per signed-in profile the app might remember in a
  // single session; aligns with the small bounded maps used elsewhere for
  // per-user state (e.g. profile patch ArrayMap commentary).
  //
  // ttl 90 seconds — sessions change on book/cancel/reschedule much more often
  // than course metadata or returning-tutor identity. A short TTL prevents
  // stale "upcoming" counts while still absorbing burst traffic (pull-to-
  // refresh double-taps, concurrent [Future.wait] callers).
  static const int studentSessionsMaxEntries = 4;
  static const Duration studentSessionsTtl = Duration(seconds: 90);
}
