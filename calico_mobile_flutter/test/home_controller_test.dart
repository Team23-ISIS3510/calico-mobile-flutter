import 'package:flutter_test/flutter_test.dart';
import 'package:calico_mobile_flutter/core/utils/course_filter_isolate.dart';
import 'package:calico_mobile_flutter/features/home/domain/entities/course_entity.dart';

void main() {
  // compute() spawns a real Isolate under the hood; the Flutter test binding
  // must be initialized first so the isolate infrastructure is available in
  // the VM test environment.
  TestWidgetsFlutterBinding.ensureInitialized();

  final courses = [
    const CourseEntity(
      id: '1',
      name: 'Calculus I',
      code: 'MATH101',
      credits: 3,
      faculty: 'Sciences',
    ),
    const CourseEntity(
      id: '2',
      name: 'Physics II',
      code: 'PHYS202',
      credits: 4,
      faculty: 'Sciences',
    ),
    const CourseEntity(
      id: '3',
      name: 'Data Structures',
      code: 'ISIS2203',
      credits: 3,
      faculty: 'Engineering',
    ),
  ];

  group('filterCoursesInIsolate', () {
    test('returns all courses on empty query', () async {
      final result = await filterCoursesInIsolate(courses, '');
      expect(result.length, 3);
    });

    test('filters by name (case-insensitive)', () async {
      final result = await filterCoursesInIsolate(courses, 'calc');
      expect(result.length, 1);
      expect(result.first.code, 'MATH101');
    });

    test('filters by code', () async {
      final result = await filterCoursesInIsolate(courses, 'ISIS');
      expect(result.length, 1);
      expect(result.first.name, 'Data Structures');
    });

    test('returns empty list when nothing matches', () async {
      final result = await filterCoursesInIsolate(courses, 'zzz');
      expect(result.isEmpty, true);
    });
  });
}
