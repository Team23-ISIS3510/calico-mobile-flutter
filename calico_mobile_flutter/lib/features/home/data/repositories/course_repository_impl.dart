import 'dart:convert';

import '../../../../core/cache/lru_cache.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/app_database.dart';
import '../../domain/entities/course_entity.dart';
import '../../domain/repositories/course_repository.dart';
import '../models/course_model.dart';

class CourseRepositoryImpl implements CourseRepository {
  final ApiClient _apiClient;
  final AppDatabaseService _db;

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

  CourseRepositoryImpl(this._apiClient, {AppDatabaseService? db})
      : _db = db ?? AppDatabaseService.instance;

  /// Drops the cached course list so the next [getCourses] call hits the server.
  /// Call this when a pull-to-refresh explicitly requests fresh data. Only the
  /// L1 LRU is invalidated — the SQLite L2 row remains as the offline fallback
  /// and will be overwritten on the next successful fetch.
  static void invalidate() => _courseCache.invalidate(_cacheKey);

  /// Remote-first read with L2 SQLite fallback.
  ///
  /// 1. L1 (LRU) hit → return.
  /// 2. Try API. On success: write to L1 + L2 SQLite, return.
  /// 3. On API failure: read L2 SQLite. If present, populate L1 and return.
  /// 4. Otherwise rethrow so the caller can show an error UI.
  @override
  Future<List<CourseEntity>> getCourses() async {
    final cached = _courseCache.get(_cacheKey);
    if (cached != null) return cached;

    try {
      final data = await _apiClient.get('/courses');
      final raw = data['courses'] as List<dynamic>? ?? [];
      final courses = raw
          .whereType<Map<String, dynamic>>()
          .map((json) => CourseModel.fromJson(json).toEntity())
          .toList();
      _courseCache.put(_cacheKey, courses);
      await _safeUpsertCatalog(courses);
      return courses;
    } catch (_) {
      final fromDisk = await _readCatalogFromDisk();
      if (fromDisk != null) {
        _courseCache.put(_cacheKey, fromDisk);
        return fromDisk;
      }
      rethrow;
    }
  }

  // ── L2 SQLite helpers ──────────────────────────────────────────────────────

  Future<void> _safeUpsertCatalog(List<CourseEntity> courses) async {
    try {
      await _db.upsert(
        AppDatabaseService.tableCoursesCatalog,
        {
          'id': _cacheKey,
          'payload': jsonEncode(courses.map(_courseToCacheJson).toList()),
          'last_updated': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (_) {
      // Best-effort: a write failure must never break the remote-success path.
    }
  }

  Future<List<CourseEntity>?> _readCatalogFromDisk() async {
    try {
      final row = await _db.queryOne(
        AppDatabaseService.tableCoursesCatalog,
        where: 'id = ?',
        whereArgs: [_cacheKey],
      );
      if (row == null) return null;
      final decoded = jsonDecode(row['payload'] as String) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_courseFromCacheJson)
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }
}

// ── Serialization ───────────────────────────────────────────────────────────

Map<String, dynamic> _courseToCacheJson(CourseEntity c) => {
      'id': c.id,
      'name': c.name,
      'code': c.code,
      'credits': c.credits,
      'faculty': c.faculty,
      'prerequisites': c.prerequisites,
    };

CourseEntity _courseFromCacheJson(Map<String, dynamic> j) => CourseEntity(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      code: j['code'] as String? ?? '',
      credits: (j['credits'] as num?)?.toInt() ?? 0,
      faculty: j['faculty'] as String? ?? '',
      prerequisites: (j['prerequisites'] as List<dynamic>?)
              ?.whereType<String>()
              .toList(growable: false) ??
          const <String>[],
    );
