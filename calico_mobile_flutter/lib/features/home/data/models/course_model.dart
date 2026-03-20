class CourseModel {
  final String id;
  final String name;
  final String code;
  final int credits;
  final String faculty;
  final List<String> prerequisites;

  const CourseModel({
    required this.id,
    required this.name,
    required this.code,
    required this.credits,
    required this.faculty,
    this.prerequisites = const [],
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      credits: (json['credits'] as num?)?.toInt() ?? 0,
      faculty: json['faculty']?.toString() ?? '',
      prerequisites: (json['prerequisites'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
