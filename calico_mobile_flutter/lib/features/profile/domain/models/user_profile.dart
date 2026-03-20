class UserProfile {
  final String id;
  final String name;
  final String email;
  final String? description;
  final List<String>? courses;
  final bool isTutor;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.description,
    this.courses,
    required this.isTutor,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Student',
      email: json['email'] ?? '',
      description: json['description'],
      courses: json['courses'] != null
          ? List<String>.from(json['courses'])
          : null,
      isTutor: json['isTutor'] ?? false,
    );
  }
}
