import '../models/register_request.dart';

/// Contract that any auth backend must satisfy.
/// The presentation layer depends only on this abstraction, never on the impl.
abstract class AuthRepository {
  /// Creates the user and returns the new user's Firebase UID.
  Future<String> register(RegisterRequest request);
}
