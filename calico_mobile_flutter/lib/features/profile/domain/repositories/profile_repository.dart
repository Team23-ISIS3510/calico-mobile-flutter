import '../models/user_profile.dart';

abstract class ProfileRepository {
  Future<UserProfile> getProfile(String userId);
  Future<UserProfile> updateProfile(
    String userId, {
    String? description,
    List<String>? courses,
  });
}
