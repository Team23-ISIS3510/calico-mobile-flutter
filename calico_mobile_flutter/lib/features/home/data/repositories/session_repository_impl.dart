import 'dart:convert';

import '../../../../core/cache/home_remote_memory_cache_policy.dart';
import '../../../../core/cache/lru_cache.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/app_database.dart';
import '../../domain/entities/session_entity.dart';
import '../../domain/repositories/session_repository.dart';
import '../models/session_model.dart';

class SessionRepositoryImpl implements SessionRepository {
  final ApiClient _apiClient;
  final AppDatabaseService _db;

  // LRU cache: full session list per student before the home repository filters
  // to "upcoming". See [HomeRemoteMemoryCachePolicy] for tuning.
  static final LRUCache<String, List<SessionEntity>> _sessionsCache = LRUCache(
    maxSize: HomeRemoteMemoryCachePolicy.studentSessionsMaxEntries,
    ttl: HomeRemoteMemoryCachePolicy.studentSessionsTtl,
  );

  SessionRepositoryImpl(this._apiClient, {AppDatabaseService? db})
      : _db = db ?? AppDatabaseService.instance;

  /// Drops the cached session list so the next [getStudentSessions] call hits
  /// the server. Call this after a new session is created (e.g. after sync).
  /// Only the L1 LRU is dropped — the SQLite L2 row remains as the offline
  /// fallback until the next successful fetch overwrites it.
  static void invalidate(String studentId) =>
      _sessionsCache.invalidate(studentId);

  /// Remote-first read with L2 SQLite fallback.
  ///
  /// 1. L1 (LRU) hit → return.
  /// 2. Try API. On success: write to L1 + L2 SQLite, return.
  /// 3. On API failure: read L2 SQLite. If present, populate L1 and return.
  /// 4. Otherwise rethrow so the caller can show an error UI.
  @override
  Future<List<SessionEntity>> getStudentSessions(String studentId) async {
    if (studentId.isEmpty) return [];
    final cached = _sessionsCache.get(studentId);
    if (cached != null) return cached;

    try {
      final data = await _apiClient.get('/tutoring-sessions/student/$studentId');
      final raw = data['sessions'] as List<dynamic>? ?? [];
      final list = raw
          .whereType<Map<String, dynamic>>()
          .map((json) => SessionModel.fromJson(json).toEntity())
          .toList();
      _sessionsCache.put(studentId, list);
      await _safeUpsertSessions(studentId, list);
      return list;
    } catch (_) {
      final fromDisk = await _readSessionsFromDisk(studentId);
      if (fromDisk != null) {
        _sessionsCache.put(studentId, fromDisk);
        return fromDisk;
      }
      rethrow;
    }
  }

  // ── L2 SQLite helpers ──────────────────────────────────────────────────────

  Future<void> _safeUpsertSessions(
    String studentId,
    List<SessionEntity> sessions,
  ) async {
    try {
      await _db.upsert(
        AppDatabaseService.tableStudentSessionsFull,
        {
          'student_id': studentId,
          'payload': jsonEncode(sessions.map(_sessionToCacheJson).toList()),
          'last_updated': DateTime.now().millisecondsSinceEpoch,
        },
      );
    } catch (_) {
      // Best-effort: a write failure must never break the remote-success path.
    }
  }

  Future<List<SessionEntity>?> _readSessionsFromDisk(String studentId) async {
    try {
      final row = await _db.queryOne(
        AppDatabaseService.tableStudentSessionsFull,
        where: 'student_id = ?',
        whereArgs: [studentId],
      );
      if (row == null) return null;
      final decoded = jsonDecode(row['payload'] as String) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_sessionFromCacheJson)
          .toList(growable: false);
    } catch (_) {
      return null;
    }
  }
}

// ── Serialization ───────────────────────────────────────────────────────────

Map<String, dynamic> _sessionToCacheJson(SessionEntity s) => {
      'id': s.id,
      'tutorId': s.tutorId,
      'studentId': s.studentId,
      'startDateTime': s.startDateTime?.toIso8601String(),
      'endDateTime': s.endDateTime?.toIso8601String(),
      'courseId': s.courseId,
      'courseName': s.courseName,
      'tutorName': s.tutorName,
      'tutorEmail': s.tutorEmail,
      'status': s.status,
    };

SessionEntity _sessionFromCacheJson(Map<String, dynamic> j) => SessionEntity(
      id: j['id'] as String? ?? '',
      tutorId: j['tutorId'] as String? ?? '',
      studentId: j['studentId'] as String? ?? '',
      startDateTime: _parseIso(j['startDateTime']),
      endDateTime: _parseIso(j['endDateTime']),
      courseId: j['courseId'] as String?,
      courseName: j['courseName'] as String?,
      tutorName: j['tutorName'] as String?,
      tutorEmail: j['tutorEmail'] as String?,
      status: j['status'] as String? ?? 'pending',
    );

DateTime? _parseIso(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}
