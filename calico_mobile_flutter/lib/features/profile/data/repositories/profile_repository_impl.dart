import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ApiClient _apiClient;
  static const String _cachePrefix = 'profile_cache_';

  const ProfileRepositoryImpl(this._apiClient);

  @override
  Future<UserProfile> getProfile(String userId) async {
    try {
      final data = await _apiClient.get('/users/$userId');
      final profile = UserProfile.fromJson(data);
      await _saveCachedProfile(userId, profile);
      return profile;
    } catch (_) {
      final cached = await _readCachedProfile(userId);
      if (cached != null) return cached;
      rethrow;
    }
  }

  @override
  Future<UserProfile> updateProfile(
    String userId, {
    String? description,
    List<String>? courses,
  }) async {
    final data = await _apiClient.patch(
      '/users/$userId',
      body: {
        if (description != null) 'description': description,
        if (courses != null) 'courses': courses,
      },
    );
    final profile = UserProfile.fromJson(data);
    await _saveCachedProfile(userId, profile);
    return profile;
  }

  Future<void> _saveCachedProfile(String userId, UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_cachePrefix$userId',
        jsonEncode(profile.toJson()),
      );
    } catch (_) {
      // Best-effort cache only.
    }
  }

  Future<UserProfile?> _readCachedProfile(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cachePrefix$userId');
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return UserProfile.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }
}
