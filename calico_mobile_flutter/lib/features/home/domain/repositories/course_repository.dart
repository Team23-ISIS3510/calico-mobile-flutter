import '../entities/course_entity.dart';

abstract class CourseRepository {
  Future<List<CourseEntity>> getCourses();
}
