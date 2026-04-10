class CourseEntity {
  final String id;
  final String name;
  final String code;
  final int credits;
  final String faculty;
  final List<String> prerequisites;

  const CourseEntity({
    required this.id,
    required this.name,
    required this.code,
    required this.credits,
    required this.faculty,
    this.prerequisites = const [],
  });
}
