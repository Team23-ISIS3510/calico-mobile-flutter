import '../../../../core/cache/lru_cache.dart';
import '../../../../core/network/api_client.dart';
import '../../../home/data/models/available_tutor_model.dart';
import '../../domain/repositories/tutor_search_repository.dart';

// LRU eviction policy: when the cache holds 10 entries and a new key arrives,
// the least-recently-used entry is evicted first. This matches mobile usage
// patterns — users rarely revisit a course they searched more than 10 queries
// ago, so the evicted entry is almost certainly stale anyway.
//
// TTL = 5 minutes: tutor availability (slots, ratings) changes frequently.
// Shorter TTL risks too many network round-trips on slow connections; longer
// risks showing a tutor whose last slot was just booked by someone else.
// 5 minutes is the same TTL used by the home-screen tutor cache, keeping the
// behaviour consistent across the app.

class TutorSearchRepositoryImpl implements TutorSearchRepository {
  final ApiClient _client;

  // Cache key format: 'search_<courseId>_<minRating>_<locationType>'
  // maxSize=10: covers the typical number of distinct filter combinations a
  // student will try in one session without exceeding ~100 KB of heap.
  final LRUCache<String, List<AvailableTutorModel>> _cache = LRUCache(
    maxSize: 10,
    ttl: const Duration(minutes: 5),
  );

  TutorSearchRepositoryImpl(this._client);

  @override
  Future<List<AvailableTutorModel>> searchTutors({
    required String courseId,
    double minRating = 0.0,
    String locationType = 'all',
  }) async {
    final key = 'search_${courseId}_${minRating}_$locationType';

    // Cache hit — return immediately, no network call needed.
    final cached = _cache.get(key);
    if (cached != null) return cached;

    // Cache miss — fetch from the API, store the result, then return.
    final query = <String, String>{'course': courseId};
    if (minRating > 0) query['minRating'] = minRating.toString();
    if (locationType != 'all') query['locationType'] = locationType;

    final data = await _client.get(
      '/analytics/bookable-tutors',
      query: query,
    );

    final raw = data['tutors'] as List<dynamic>? ?? [];
    var tutors = raw
        .map((e) => AvailableTutorModel.fromJson(e as Map<String, dynamic>))
        .toList();

    // Client-side location filter — the API may not support it natively.
    // 'all' = no filter, 'virtual' = only virtual, anything else = non-virtual.
    if (locationType == 'virtual') {
      tutors = tutors
          .where((t) => t.location.toLowerCase().contains('virtual'))
          .toList();
    } else if (locationType != 'all') {
      tutors = tutors
          .where((t) => !t.location.toLowerCase().contains('virtual'))
          .toList();
    }

    _cache.put(key, tutors);
    return tutors;
  }

  @override
  void invalidateForCourse(String courseId) {
    // LRUCache doesn't expose its key set, so we invalidate each known
    // combination (the four rating thresholds × three location types the UI
    // exposes). The TTL will expire any remaining combinations within 5 min.
    _invalidateKnownKeys(courseId);
  }

  void _invalidateKnownKeys(String courseId) {
    // Covers the four minRating values exposed in the UI (0, 3, 4, 4.5)
    // and three location types (all, virtual, campus).
    const ratings = [0.0, 3.0, 4.0, 4.5];
    const locations = ['all', 'virtual', 'campus'];
    for (final r in ratings) {
      for (final l in locations) {
        _cache.invalidate('search_${courseId}_${r}_$l');
      }
    }
  }
}
