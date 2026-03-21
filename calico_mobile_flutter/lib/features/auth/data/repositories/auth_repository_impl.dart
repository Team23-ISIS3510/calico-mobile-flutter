import '../../../../core/network/api_client.dart';
import '../../domain/models/register_request.dart';
import '../../domain/models/login_request.dart';
import '../../domain/repositories/auth_repository.dart';

/// Concrete implementation that talks to the NestJS backend.
/// Serialises requests → JSON and delegates to ApiClient.
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
    return data['id']?.toString() ?? '';
  }

  @override
  Future<String> login(LoginRequest request) async {
    final data = await _apiClient.post(
      '/auth/login',
      body: {'email': request.email, 'password': request.password},
    );
    // Backend proxies the Firebase Identity Toolkit response which uses
    // 'localId' (not 'id') for the Firebase UID.
    return data['localId']?.toString() ?? '';
  }

  @override
  Future<String> loginWithGoogle(String idToken) async {
    final data = await _apiClient.post(
      '/auth/google',
      body: {'idToken': idToken},
    );
    return data['user']['id']?.toString() ?? '';
  }
}
