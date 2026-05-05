import 'package:flutter/foundation.dart';
import '../../features/home/domain/entities/course_entity.dart';

class FilterParams {
  final List<CourseEntity> courses;
  final String query;

  const FilterParams({required this.courses, required this.query});
}

List<CourseEntity> _filterCourses(FilterParams params) {
  debugPrint('_filterCourses running on isolate for: ${params.query}');
  if (params.query.trim().isEmpty) return params.courses;
  final q = params.query.toLowerCase();
  return params.courses
      .where(
        (c) =>
            c.name.toLowerCase().contains(q) ||
            c.code.toLowerCase().contains(q),
      )
      .toList();
}

Future<List<CourseEntity>> filterCoursesInIsolate(
  List<CourseEntity> courses,
  String query,
) async {
  return compute(_filterCourses, FilterParams(courses: courses, query: query));
}
