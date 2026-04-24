import 'dart:isolate';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/session_entity.dart';
import '../../domain/entities/tutor_entity.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../../domain/repositories/session_repository.dart';
import '../../domain/repositories/student_tutoring_repository.dart';

class StudentTutoringRepositoryImpl implements StudentTutoringRepository {
  final AnalyticsRepository _analytics;
  final SessionRepository _sessions;
  final ApiClient _apiClient;

  const StudentTutoringRepositoryImpl(
    this._analytics,
    this._sessions,
    this._apiClient,
  );

  @override
  Future<List<TutorEntity>> getAvailableTutorsNext4Hours(String courseId) {
    return _analytics.getAvailableTutors(courseId);
  }

  @override
  Future<TutorEntity?> getGoToTutor(String studentId, String courseId) {
    return _analytics.getReturningTutor(studentId, courseId);
  }

  @override
  Future<List<SessionEntity>> getUpcomingSessions(String studentId) async {
    if (studentId.isEmpty) return Future.value(<SessionEntity>[]);

    final list = await _sessions.getStudentSessions(studentId);
    final payload = {
      'nowMs': DateTime.now().millisecondsSinceEpoch,
      'sessions': list.map(_sessionToPayload).toList(),
    };

    final receivePort = ReceivePort();
    await Isolate.spawn(
      _upcomingSessionsIsolateEntry,
      {
        'sendPort': receivePort.sendPort,
        'payload': payload,
      },
    );

    final result = await receivePort.first;
    receivePort.close();

    if (result is Map && result['error'] != null) {
      throw Exception(
        'Isolate processing failed: ${result['error']}',
      );
    }

    final processed = (result as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return processed.map(_payloadToSession).toList();
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
}

Map<String, dynamic> _sessionToPayload(SessionEntity session) {
  return {
    'id': session.id,
    'tutorId': session.tutorId,
    'studentId': session.studentId,
    'startMs': session.startDateTime?.millisecondsSinceEpoch,
    'endMs': session.endDateTime?.millisecondsSinceEpoch,
    'courseId': session.courseId,
    'courseName': session.courseName,
    'tutorName': session.tutorName,
    'tutorEmail': session.tutorEmail,
    'status': session.status,
  };
}

SessionEntity _payloadToSession(Map<String, dynamic> payload) {
  final startMs = payload['startMs'] as int?;
  final endMs = payload['endMs'] as int?;

  return SessionEntity(
    id: payload['id']?.toString() ?? '',
    tutorId: payload['tutorId']?.toString() ?? '',
    studentId: payload['studentId']?.toString() ?? '',
    startDateTime: startMs != null
        ? DateTime.fromMillisecondsSinceEpoch(startMs)
        : null,
    endDateTime: endMs != null
        ? DateTime.fromMillisecondsSinceEpoch(endMs)
        : null,
    courseId: payload['courseId']?.toString(),
    courseName: payload['courseName']?.toString(),
    tutorName: payload['tutorName']?.toString(),
    tutorEmail: payload['tutorEmail']?.toString(),
    status: payload['status']?.toString() ?? 'pending',
  );
}

List<Map<String, dynamic>> _filterAndSortUpcomingSessionsPayload(
  Map<String, dynamic> payload,
) {
  final nowMs = payload['nowMs'] as int;
  final sessions = (payload['sessions'] as List)
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  final upcoming = sessions.where((session) {
    final startMs = session['startMs'] as int?;
    return startMs != null && startMs > nowMs;
  }).toList();

  upcoming.sort((a, b) {
    final aMs = a['startMs'] as int? ?? 0;
    final bMs = b['startMs'] as int? ?? 0;
    return aMs.compareTo(bMs);
  });

  return upcoming;
}

void _upcomingSessionsIsolateEntry(Map<String, dynamic> message) {
  final sendPort = message['sendPort'] as SendPort;
  final payload = Map<String, dynamic>.from(message['payload'] as Map);

  try {
    final result = _filterAndSortUpcomingSessionsPayload(payload);
    sendPort.send(result);
  } catch (e) {
    sendPort.send({'error': e.toString()});
  }
}
