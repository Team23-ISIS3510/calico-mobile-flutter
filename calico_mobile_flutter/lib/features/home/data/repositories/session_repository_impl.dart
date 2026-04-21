import '../../../../core/network/api_client.dart';
import '../../domain/repositories/session_repository.dart';
import '../models/session_model.dart';

/// Calls GET /tutoring-sessions/student/:studentId and maps to [SessionModel].
class SessionRepositoryImpl implements SessionRepository {
  final ApiClient _apiClient;

  const SessionRepositoryImpl(this._apiClient);

  @override
  Future<List<SessionModel>> getStudentSessions(String studentId) async {
    if (studentId.isEmpty) return [];
    final data = await _apiClient.get('/tutoring-sessions/student/$studentId');
    final raw = data['sessions'] as List<dynamic>? ?? [];
    final now = DateTime.now();
    return raw
        .whereType<Map<String, dynamic>>()
        .map(SessionModel.fromJson)
        .where((s) {
          final end = s.endDateTime ?? s.startDateTime;
          return end == null || end.isAfter(now);
        })
        .toList();
  }
}
