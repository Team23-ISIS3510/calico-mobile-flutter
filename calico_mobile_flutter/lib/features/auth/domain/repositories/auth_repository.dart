import '../models/register_request.dart';

/// Contract that any auth backend must satisfy.
/// The presentation layer depends only on this abstraction, never on the impl.
abstract class AuthRepository {
  Future<void> register(RegisterRequest request);
}
