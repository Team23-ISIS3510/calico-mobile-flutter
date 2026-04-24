import 'package:flutter/foundation.dart';
import '../../features/home/domain/entities/course_entity.dart';

/// Holds the inputs for an isolate-based course filter operation.
///
/// All fields are plain Dart primitives or collections so the object is safe to
/// copy across an Isolate boundary. Flutter's [compute] serializes parameters
/// by value (deep copy), so no Flutter or platform objects may appear here.
class FilterParams {
  final List<CourseEntity> courses;
  final String query;

  const FilterParams({required this.courses, required this.query});
}

/// Top-level function executed inside the spawned Isolate.
///
/// Must be top-level (not an instance method or closure) because [compute]
/// needs to serialize a reference to it and send it through a [SendPort].
/// Instance methods capture `this`, which is not transferable across isolate
/// boundaries.
///
/// Runs the name/code string-match entirely in the worker isolate so the main
/// UI thread is never blocked, even when the course list is large.
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

/// Runs the course search/filter in a separate Dart Isolate using [compute].
///
/// **What is an Isolate?**
/// Dart Isolates are independent workers that each own their own memory heap.
/// They cannot share state; they communicate only by passing serializable
/// messages through [SendPort]s. This means truly parallel execution on
/// multi-core devices without the risk of data races.
///
/// **Why [compute]?**
/// [compute] is the idiomatic high-level wrapper that: (1) spawns a fresh
/// Isolate, (2) copies [params] to its heap, (3) calls [_filterCourses] there,
/// and (4) sends the result back and tears down the Isolate. It hides all
/// [SendPort]/[ReceivePort] plumbing behind a single awaitable call.
///
/// **Why filtering is a good candidate**
/// String comparisons over every course entry are CPU-bound. Doing this on the
/// main isolate would block the event loop and cause frame drops while the user
/// is typing. Offloading to a worker isolate keeps the UI at 60 fps.
Future<List<CourseEntity>> filterCoursesInIsolate(
  List<CourseEntity> courses,
  String query,
) async {
  return compute(_filterCourses, FilterParams(courses: courses, query: query));
}
