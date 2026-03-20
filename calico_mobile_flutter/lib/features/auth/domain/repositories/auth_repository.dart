import '../models/register_request.dart';
import '../models/login_request.dart';

/// Contract that any auth backend must satisfy.
/// The presentation layer depends only on this abstraction, never on the impl.

abstract class AuthRepository {
  Future<String> register(RegisterRequest request);
  Future<String> login(LoginRequest request);
  Future<String> loginWithGoogle(String idToken);
}
