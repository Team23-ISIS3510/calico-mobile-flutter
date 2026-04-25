import '../../../../core/cache/lru_cache.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/course_entity.dart';
import '../../domain/repositories/course_repository.dart';
import '../models/course_model.dart';

class CourseRepositoryImpl implements CourseRepository {
  final ApiClient _apiClient;

  // LRU cache: holds the single course list under a fixed key.
  //
  // maxSize=1 — the app has only one course list endpoint (/courses) and the
  // entire catalogue fits in a single entry. A larger maxSize would waste
  // memory slots that can never be filled.
  //
  // ttl=10 min — the course catalogue (names, codes, credits) changes far less
  // frequently than tutor availability. Ten minutes eliminates redundant fetches
  // during a normal session (home → course detail → back → home) while still
  // refreshing automatically after an extended pause.
  //
  // Static so the cache outlives individual widget rebuilds. Without static, the
  // cache would be discarded every time the HomeController is recreated.
  static final LRUCache<String, List<CourseEntity>> _courseCache = LRUCache(
    maxSize: 1,
    ttl: const Duration(minutes: 10),
  );

  static const _cacheKey = 'all';

  const CourseRepositoryImpl(this._apiClient);

  @override
  Future<List<CourseEntity>> getCourses() async {
    final cached = _courseCache.get(_cacheKey);
    if (cached != null) return cached;

    final data = await _apiClient.get('/courses');
    final raw = data['courses'] as List<dynamic>? ?? [];
    final courses = raw
        .whereType<Map<String, dynamic>>()
        .map((json) => CourseModel.fromJson(json).toEntity())
        .toList();
    _courseCache.put(_cacheKey, courses);
    return courses;
  }
}
