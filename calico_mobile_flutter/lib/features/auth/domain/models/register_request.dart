/// Value object like the backend's RegisterDto.
/// Lives in domain so every layer can reference it without touching HTTP/Flutter.
class RegisterRequest {
  final String name;
  final String email;
  final String password;
  final String phone;
  final bool isTutor;
  final List<String>? courses;

  const RegisterRequest({
    required this.name,
    required this.email,
    required this.password,
    this.phone = '',
    this.isTutor = false,
    this.courses,
  });
}
