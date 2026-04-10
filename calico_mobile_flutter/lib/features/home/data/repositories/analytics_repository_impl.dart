import '../../../../core/network/api_client.dart';
import '../../domain/entities/tutor_entity.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../models/available_tutor_model.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final ApiClient _apiClient;

  const AnalyticsRepositoryImpl(this._apiClient);

  @override
  Future<TutorEntity?> getReturningTutor(
    String studentId,
    String courseId,
  ) async {
    final data = await _apiClient.get(
      '/analytics/returning-tutor',
      query: {'student': studentId, 'course': courseId},
    );
    final raw = data['tutor'];
    if (raw == null) return null;
    return AvailableTutorModel.fromJson(raw as Map<String, dynamic>).toEntity();
  }

  @override
  Future<void> trackCarouselEvent(
    String event,
    String courseId, {
    String? tutorId,
    double? tutorRating,
    int? resultCount,
    int? countdownMinutes,
  }) async {
    try {
      await _apiClient.post('/analytics/event', body: {
        'event': event,
        'courseId': courseId,
        if (tutorId != null) 'tutorId': tutorId,
        if (tutorRating != null) 'tutorRating': tutorRating,
        if (resultCount != null) 'resultCount': resultCount,
        if (countdownMinutes != null) 'countdownMinutes': countdownMinutes,
      });
    } catch (_) {
      // Fire-and-forget: never let tracking break the UI
    }
  }

  @override
  Future<List<TutorEntity>> getAvailableTutors(String courseId) async {
    final data = await _apiClient.get(
      '/analytics/bookable-tutors',
      query: {'course': courseId},
    );
    final raw = data['tutors'] as List<dynamic>? ?? [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((json) => AvailableTutorModel.fromJson(json).toEntity())
        .toList();
  }
}
