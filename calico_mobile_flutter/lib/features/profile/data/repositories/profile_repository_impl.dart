import '../../../../core/network/api_client.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ApiClient _apiClient;

  const ProfileRepositoryImpl(this._apiClient);

  @override
  Future<UserProfile> getProfile(String userId) async {
    final data = await _apiClient.get('/users/$userId');
    return UserProfile.fromJson(data);
  }

  @override
  Future<UserProfile> updateProfile(
    String userId, {
    String? description,
    List<String>? courses,
  }) async {
    print('Updating profile: description=$description, courses=$courses');
    final data = await _apiClient.patch(
      '/users/$userId',
      body: {
        if (description != null) 'description': description,
        if (courses != null) 'courses': courses,
      },
    );
    print('Response: $data');
    return UserProfile.fromJson(data);
  }
}
