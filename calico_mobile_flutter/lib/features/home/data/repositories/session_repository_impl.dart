import '../../../../core/cache/home_remote_memory_cache_policy.dart';
import '../../../../core/cache/lru_cache.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/session_entity.dart';
import '../../domain/repositories/session_repository.dart';
import '../models/session_model.dart';

class SessionRepositoryImpl implements SessionRepository {
  final ApiClient _apiClient;

  // LRU cache: full session list per student before the home repository filters
  // to "upcoming". See [HomeRemoteMemoryCachePolicy] for tuning.
  static final LRUCache<String, List<SessionEntity>> _sessionsCache = LRUCache(
    maxSize: HomeRemoteMemoryCachePolicy.studentSessionsMaxEntries,
    ttl: HomeRemoteMemoryCachePolicy.studentSessionsTtl,
  );

  const SessionRepositoryImpl(this._apiClient);

  @override
  Future<List<SessionEntity>> getStudentSessions(String studentId) async {
    if (studentId.isEmpty) return [];
    final cached = _sessionsCache.get(studentId);
    if (cached != null) return cached;

    final data = await _apiClient.get('/tutoring-sessions/student/$studentId');
    final raw = data['sessions'] as List<dynamic>? ?? [];
    final list = raw
        .whereType<Map<String, dynamic>>()
        .map((json) => SessionModel.fromJson(json).toEntity())
        .toList();
    _sessionsCache.put(studentId, list);
    return list;
  }
}
