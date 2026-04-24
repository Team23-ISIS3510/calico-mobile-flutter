import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/app_database.dart';
import '../../../../core/storage/cached_result.dart';
import '../../domain/entities/session_entity.dart';
import '../../domain/entities/tutor_entity.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../../domain/repositories/session_repository.dart';
import '../../domain/repositories/student_tutoring_repository.dart';

class StudentTutoringRepositoryImpl implements StudentTutoringRepository {
  final AnalyticsRepository _analytics;
  final SessionRepository _sessions;
  final ApiClient _apiClient;
  final AppDatabaseService _db;

  StudentTutoringRepositoryImpl(
    this._analytics,
    this._sessions,
    this._apiClient, {
    AppDatabaseService? db,
  }) : _db = db ?? AppDatabaseService.instance;

  @override
  Future<CachedResult<List<TutorEntity>>> getAvailableTutorsNext4Hours(
    String courseId,
  ) async {
    try {
      final tutors = await _analytics.getAvailableTutors(courseId);
      final now = DateTime.now();
      await _safeUpsert(
        AppDatabaseService.tableAvailableTutors,
        {
          'course_id': courseId,
          'payload': jsonEncode(tutors.map(_tutorToCacheJson).toList()),
          'last_updated': now.millisecondsSinceEpoch,
        },
      );
      return CachedResult(data: tutors, lastUpdated: now);
    } catch (_) {
      final cached = await _readAvailableTutorsCache(courseId);
      if (cached != null) return cached;
      rethrow;
    }
  }

  @override
  Future<CachedResult<TutorEntity?>> getGoToTutor(
    String studentId,
    String courseId,
  ) async {
    try {
      final tutor = await _analytics.getReturningTutor(studentId, courseId);
      final now = DateTime.now();
      await _safeUpsert(
        AppDatabaseService.tableGoToTutor,
        {
          'student_id': studentId,
          'course_id': courseId,
          'payload': jsonEncode({
            'tutor': tutor == null ? null : _tutorToCacheJson(tutor),
          }),
          'last_updated': now.millisecondsSinceEpoch,
        },
      );
      return CachedResult(data: tutor, lastUpdated: now);
    } catch (_) {
      final cached = await _readGoToTutorCache(studentId, courseId);
      if (cached != null) return cached;
      rethrow;
    }
  }

  @override
  Future<CachedResult<List<SessionEntity>>> getUpcomingSessions(
    String studentId,
  ) async {
    if (studentId.isEmpty) {
      return const CachedResult<List<SessionEntity>>(data: <SessionEntity>[]);
    }

    try {
      final list = await _sessions.getStudentSessions(studentId);
      final now = DateTime.now();
      final upcoming = list
          .where((session) {
            final start = session.startDateTime;
            return start != null && start.isAfter(now);
          })
          .toList()
        ..sort((a, b) {
          final aStart =
              a.startDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bStart =
              b.startDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
          return aStart.compareTo(bStart);
        });

      await _safeUpsert(
        AppDatabaseService.tableUpcomingSessions,
        {
          'student_id': studentId,
          'payload': jsonEncode(upcoming.map(_sessionToCacheJson).toList()),
          'last_updated': now.millisecondsSinceEpoch,
        },
      );
      return CachedResult(data: upcoming, lastUpdated: now);
    } catch (_) {
      final cached = await _readUpcomingSessionsCache(studentId);
      if (cached != null) return cached;
      rethrow;
    }
  }

  @override
  Future<void> sendMotionEmergencyAlert({
    required String toEmail,
    String? toName,
    required String studentName,
    required String alertReason,
    String? location,
  }) async {
    await _apiClient.post(
      '/notifications/emergency-alert/email',
      body: {
        'toEmail': toEmail,
        'toName': toName,
        'studentName': studentName,
        'alertReason': alertReason,
        'location': location,
      },
    );
  }

  @override
  Future<void> trackCarouselEvent(
    String event,
    String courseId, {
    String? tutorId,
    double? tutorRating,
    int? resultCount,
    int? countdownMinutes,
  }) {
    return _analytics.trackCarouselEvent(
      event,
      courseId,
      tutorId: tutorId,
      tutorRating: tutorRating,
      resultCount: resultCount,
      countdownMinutes: countdownMinutes,
    );
  }

  // ── Cache helpers ─────────────────────────────────────────────────────────

  Future<void> _safeUpsert(String table, Map<String, Object?> values) async {
    try {
      await _db.upsert(table, values);
    } catch (_) {
      // Best-effort cache write. Never let storage failures break the
      // remote-success path.
    }
  }

  Future<CachedResult<List<TutorEntity>>?> _readAvailableTutorsCache(
    String courseId,
  ) async {
    try {
      final row = await _db.queryOne(
        AppDatabaseService.tableAvailableTutors,
        where: 'course_id = ?',
        whereArgs: [courseId],
      );
      if (row == null) return null;
      final decoded = jsonDecode(row['payload'] as String) as List<dynamic>;
      final tutors = decoded
          .whereType<Map<String, dynamic>>()
          .map(_tutorFromCacheJson)
          .toList();
      return CachedResult(
        data: tutors,
        isFromCache: true,
        lastUpdated: _millisToDate(row['last_updated']),
      );
    } catch (_) {
      return null;
    }
  }

  Future<CachedResult<TutorEntity?>?> _readGoToTutorCache(
    String studentId,
    String courseId,
  ) async {
    try {
      final row = await _db.queryOne(
        AppDatabaseService.tableGoToTutor,
        where: 'student_id = ? AND course_id = ?',
        whereArgs: [studentId, courseId],
      );
      if (row == null) return null;
      final decoded = jsonDecode(row['payload'] as String)
          as Map<String, dynamic>;
      final raw = decoded['tutor'];
      final tutor = raw == null
          ? null
          : _tutorFromCacheJson(raw as Map<String, dynamic>);
      return CachedResult<TutorEntity?>(
        data: tutor,
        isFromCache: true,
        lastUpdated: _millisToDate(row['last_updated']),
      );
    } catch (_) {
      return null;
    }
  }

  Future<CachedResult<List<SessionEntity>>?> _readUpcomingSessionsCache(
    String studentId,
  ) async {
    try {
      final row = await _db.queryOne(
        AppDatabaseService.tableUpcomingSessions,
        where: 'student_id = ?',
        whereArgs: [studentId],
      );
      if (row == null) return null;
      final decoded = jsonDecode(row['payload'] as String) as List<dynamic>;
      final sessions = decoded
          .whereType<Map<String, dynamic>>()
          .map(_sessionFromCacheJson)
          .toList();
      return CachedResult(
        data: sessions,
        isFromCache: true,
        lastUpdated: _millisToDate(row['last_updated']),
      );
    } catch (_) {
      return null;
    }
  }
}

// ── Serialization ───────────────────────────────────────────────────────────

Map<String, dynamic> _tutorToCacheJson(TutorEntity t) => {
      'id': t.id,
      'name': t.name,
      'rating': t.rating,
      'hourlyRate': t.hourlyRate,
      'profileImage': t.profileImage,
      'location': t.location,
      'nextSlotStart': t.nextSlotStart?.toIso8601String(),
      'nextSlotEnd': t.nextSlotEnd?.toIso8601String(),
      'parentAvailabilityId': t.parentAvailabilityId,
      'nextSlotIndex': t.nextSlotIndex,
      'availableSlotsCount': t.availableSlotsCount,
      'bookingCount': t.bookingCount,
    };

TutorEntity _tutorFromCacheJson(Map<String, dynamic> j) => TutorEntity(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      rating: (j['rating'] as num?)?.toDouble() ?? 0.0,
      hourlyRate: (j['hourlyRate'] as num?)?.toDouble(),
      profileImage: j['profileImage'] as String?,
      location: j['location'] as String? ?? 'Virtual',
      nextSlotStart: _parseIso(j['nextSlotStart']),
      nextSlotEnd: _parseIso(j['nextSlotEnd']),
      parentAvailabilityId: j['parentAvailabilityId'] as String?,
      nextSlotIndex: (j['nextSlotIndex'] as num?)?.toInt(),
      availableSlotsCount: (j['availableSlotsCount'] as num?)?.toInt() ?? 0,
      bookingCount: (j['bookingCount'] as num?)?.toInt(),
    );

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

DateTime? _millisToDate(Object? value) {
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  return null;
}
