/// Value object matching the backend's LoginDto.
/// Lives in domain so every layer can reference it without touching HTTP/Flutter.
class LoginRequest {
  final String email;
  final String password;

  const LoginRequest({
    required this.email,
    required this.password,
  });
}