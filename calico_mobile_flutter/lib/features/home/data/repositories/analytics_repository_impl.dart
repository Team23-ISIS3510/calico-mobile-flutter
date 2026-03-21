import '../../../../core/network/api_client.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../models/available_tutor_model.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final ApiClient _apiClient;

  const AnalyticsRepositoryImpl(this._apiClient);

  @override
  Future<AvailableTutorModel?> getReturningTutor(
    String studentId,
    String courseId,
  ) async {
    final data = await _apiClient.get(
      '/analytics/returning-tutor',
      query: {'student': studentId, 'course': courseId},
    );
    final raw = data['tutor'];
    if (raw == null) return null;
    return AvailableTutorModel.fromJson(raw as Map<String, dynamic>);
  }

  @override
  Future<List<AvailableTutorModel>> getAvailableTutors(String courseId) async {
    final data = await _apiClient.get(
      '/analytics/bookable-tutors',
      query: {'course': courseId},
    );
    final raw = data['tutors'] as List<dynamic>? ?? [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(AvailableTutorModel.fromJson)
        .toList();
  }
}
