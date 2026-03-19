import '../../../../core/network/api_client.dart';
import '../../domain/repositories/course_repository.dart';
import '../models/course_model.dart';

/// Calls GET /courses and maps the response list to [CourseModel].
class CourseRepositoryImpl implements CourseRepository {
  final ApiClient _apiClient;

  const CourseRepositoryImpl(this._apiClient);

  @override
  Future<List<CourseModel>> getCourses() async {
    final data = await _apiClient.get('/courses');
    final raw = data['courses'] as List<dynamic>? ?? [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(CourseModel.fromJson)
        .toList();
  }
}
