import '../models/user_profile.dart';

abstract class ProfileRepository {
  Future<UserProfile> getProfile(String userId);

  Future<UserProfile> updateProfile(
    String userId, {
    String? description,
    List<String>? courses,
  });

  /// True when the last [getProfile] call returned data from the local cache
  /// rather than a fresh server response.  Drives the 'Showing saved data'
  /// badge in the UI.
  bool get lastLoadFromCache;

  /// If a description edit was saved offline, POST it now and clear the
  /// pending key.  No-op when there is nothing pending or still offline.
  Future<void> syncPendingUpdate(String userId);
}
