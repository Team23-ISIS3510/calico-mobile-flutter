import '../../../../core/cache/home_remote_memory_cache_policy.dart';
import '../../../../core/cache/lru_cache.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/tutor_entity.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../models/available_tutor_model.dart';

/// Record value so a cached `null` tutor (no returning tutor) is distinct from
/// an LRU miss, which [LRUCache.get] still represents as `null`.
typedef _ReturningTutorSlot = ({TutorEntity? tutor});

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final ApiClient _apiClient;

  // LRU cache: tutor lists keyed by courseId.
  //
  // maxSize=10 — one slot per course; fits the full catalogue with no eviction
  // under normal use, so every course detail screen gets a fast in-memory hit
  // on re-visit within the same session.
  //
  // ttl=5 min — tutor availability (next slot, booking count) changes as other
  // students book sessions. Five minutes is a reasonable balance: the data
  // stays fresh enough to show accurate slot counts while still cutting most
  // repeated network calls during a single booking flow.
  //
  // Static so the cache survives widget rebuilds and screen navigation. A new
  // AnalyticsRepositoryImpl instance is created every time the home or course-
  // detail screen initialises; without static the cache would be discarded on
  // every navigation pop.
  static final LRUCache<String, List<TutorEntity>> _tutorCache = LRUCache(
    maxSize: 10,
    ttl: const Duration(minutes: 5),
  );

  // LRU cache: returning tutor keyed by (studentId, courseId). See
  // [HomeRemoteMemoryCachePolicy] for maxSize / ttl rationale. Covers both
  // [StudentTutoringRepositoryImpl.getGoToTutor] and course-detail direct calls.
  static final LRUCache<(String, String), _ReturningTutorSlot>
      _returningTutorCache = LRUCache(
    maxSize: HomeRemoteMemoryCachePolicy.returningTutorMaxEntries,
    ttl: HomeRemoteMemoryCachePolicy.returningTutorTtl,
  );

  const AnalyticsRepositoryImpl(this._apiClient);

  @override
  Future<TutorEntity?> getReturningTutor(
    String studentId,
    String courseId,
  ) async {
    final key = (studentId, courseId);
    final hit = _returningTutorCache.get(key);
    if (hit != null) return hit.tutor;

    final data = await _apiClient.get(
      '/analytics/returning-tutor',
      query: {'student': studentId, 'course': courseId},
    );
    final raw = data['tutor'];
    final TutorEntity? tutor = raw == null
        ? null
        : AvailableTutorModel.fromJson(raw as Map<String, dynamic>).toEntity();
    _returningTutorCache.put(key, (tutor: tutor));
    return tutor;
  }

  @override
  Future<List<TutorEntity>> getAvailableTutors(String courseId) async {
    final cached = _tutorCache.get(courseId);
    if (cached != null) return cached;

    final data = await _apiClient.get(
      '/analytics/bookable-tutors',
      query: {'course': courseId},
    );
    final raw = data['tutors'] as List<dynamic>? ?? [];
    final tutors = raw
        .whereType<Map<String, dynamic>>()
        .map((json) => AvailableTutorModel.fromJson(json).toEntity())
        .toList();
    _tutorCache.put(courseId, tutors);
    return tutors;
  }

  @override
  Future<void> trackCarouselEvent(
    String event,
    String courseId, {
    String? tutorId,
    double? tutorRating,
    int? resultCount,
    int? countdownMinutes,
  }) async {
    try {
      await _apiClient.post(
        '/analytics/event',
        body: {
          'event': event,
          'courseId': courseId,
          'tutorId': ?tutorId,
          'tutorRating': ?tutorRating,
          'resultCount': ?resultCount,
          'countdownMinutes': ?countdownMinutes,
        },
      );
    } catch (_) {
      // Fire-and-forget: never let tracking break the UI.
    }
  }
}
