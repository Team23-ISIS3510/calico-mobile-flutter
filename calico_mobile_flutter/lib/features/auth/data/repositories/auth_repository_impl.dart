import '../../../../core/network/api_client.dart';
import '../../domain/models/register_request.dart';
import '../../domain/repositories/auth_repository.dart';

/// Concrete implementation that talks to the NestJS backend.
/// Serialises RegisterRequest → JSON and delegates to ApiClient.
class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _apiClient;

  const AuthRepositoryImpl(this._apiClient);

  @override
  Future<String> register(RegisterRequest request) async {
    final data = await _apiClient.post(
      '/auth/register',
      body: {
        'name': request.name,
        'email': request.email,
        'password': request.password,
        'phone': request.phone,
        'isTutor': request.isTutor,
        if (request.courses != null) 'courses': request.courses,
      },
    );
    // Backend returns UserResponseDto directly — id is the Firebase UID.
    return data['id']?.toString() ?? '';
  }
}
