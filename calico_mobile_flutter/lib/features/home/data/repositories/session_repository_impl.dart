import '../../../../core/network/api_client.dart';
import '../../domain/entities/session_entity.dart';
import '../../domain/repositories/session_repository.dart';
import '../models/session_model.dart';

class SessionRepositoryImpl implements SessionRepository {
  final ApiClient _apiClient;

  const SessionRepositoryImpl(this._apiClient);

  @override
  Future<List<SessionEntity>> getStudentSessions(String studentId) async {
    if (studentId.isEmpty) return [];
    final data = await _apiClient.get('/tutoring-sessions/student/$studentId');
    final raw = data['sessions'] as List<dynamic>? ?? [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((json) => SessionModel.fromJson(json).toEntity())
        .toList();
  }
}
