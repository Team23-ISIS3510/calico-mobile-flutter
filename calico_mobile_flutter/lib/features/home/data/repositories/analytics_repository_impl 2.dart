import '../../../../core/network/api_client.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../models/available_tutor_model.dart';

/// Calls GET /analytics/available-tutors?course=<courseId>
/// and maps the response to a list of [AvailableTutorModel].
class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final ApiClient _apiClient;

  const AnalyticsRepositoryImpl(this._apiClient);

  @override
  Future<List<AvailableTutorModel>> getAvailableTutors(String courseId) async {
    final data = await _apiClient.get(
      '/analytics/available-tutors',
      query: {'course': courseId},
    );
    final raw = data['tutors'] as List<dynamic>? ?? [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(AvailableTutorModel.fromJson)
        .toList();
  }
}
