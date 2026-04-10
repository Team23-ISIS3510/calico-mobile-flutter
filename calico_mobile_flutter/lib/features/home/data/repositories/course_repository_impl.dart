import '../../../../core/network/api_client.dart';
import '../../domain/entities/course_entity.dart';
import '../../domain/repositories/course_repository.dart';
import '../models/course_model.dart';

class CourseRepositoryImpl implements CourseRepository {
  final ApiClient _apiClient;

  const CourseRepositoryImpl(this._apiClient);

  @override
  Future<List<CourseEntity>> getCourses() async {
    final data = await _apiClient.get('/courses');
    final raw = data['courses'] as List<dynamic>? ?? [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((json) => CourseModel.fromJson(json).toEntity())
        .toList();
  }
}
