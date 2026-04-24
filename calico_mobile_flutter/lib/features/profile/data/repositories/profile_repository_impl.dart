// WHY SHAREDPREFERENCES?
// The user profile is a single JSON document keyed by userId.
// SharedPreferences is the right fit because:
//   - Data is small (< 1 KB) — no need for a full relational database
//   - Key-value access is O(1); no query language needed
//   - Built-in platform storage (NSUserDefaults on iOS, SharedPreferences on Android)
//
// TRADE-OFF: not encrypted, so avoid storing auth tokens here.
// Acceptable for non-sensitive profile fields (name, description, email).
//
// TWO KEYS PER USER:
//   cached_profile_<userId>         — last successful GET response (JSON)
//   pending_profile_update_<userId> — description edit saved while offline

import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ApiClient _apiClient;

  ProfileRepositoryImpl(this._apiClient);

  bool _lastLoadFromCache = false;

  @override
  bool get lastLoadFromCache => _lastLoadFromCache;

  // ── Key helpers ───────────────────────────────────────────────────────────

  static String _cacheKey(String userId) => 'cached_profile_$userId';
  static String _pendingKey(String userId) => 'pending_profile_update_$userId';

  // ── Repository interface ──────────────────────────────────────────────────

  @override
  Future<UserProfile> getProfile(String userId) async {
    try {
      final data = await _apiClient.get('/users/$userId');
      final profile = UserProfile.fromJson(data);
      // Persist the fresh response so we can serve it offline next time.
      await _writeCache(_cacheKey(userId), data);
      _lastLoadFromCache = false;
      return profile;
    } catch (_) {
      // API call failed (offline / timeout / 5xx) — fall back to cache.
      final cached = await _readCache(_cacheKey(userId));
      if (cached != null) {
        _lastLoadFromCache = true;
        return UserProfile.fromJson(cached);
      }
      _lastLoadFromCache = false;
      rethrow; // No cache available — surface the error to the UI.
    }
  }

  @override
  Future<UserProfile> updateProfile(
    String userId, {
    String? description,
    List<String>? courses,
  }) async {
    final results = await Connectivity().checkConnectivity();
    final isOnline = results.any((r) => r != ConnectivityResult.none);

    if (!isOnline) {
      // Save the pending edit so syncPendingUpdate can POST it later.
      if (description != null) await _writePendingUpdate(userId, description);

      // Return an optimistic profile: cache + new description so the UI
      // reflects the change immediately without waiting for connectivity.
      final cached = await _readCache(_cacheKey(userId));
      if (cached != null) {
        final patched = Map<String, dynamic>.from(cached);
        if (description != null) patched['description'] = description;
        return UserProfile.fromJson(patched);
      }
      throw Exception('Profile update saved locally — will sync when online.');
    }

    // Online path — PATCH and re-cache the server response.
    final data = await _apiClient.patch(
      '/users/$userId',
      body: {
        if (description != null) 'description': description,
        if (courses != null) 'courses': courses,
      },
    );
    final profile = UserProfile.fromJson(data);
    await _writeCache(_cacheKey(userId), data);
    return profile;
  }

  /// Sends any pending offline description edit to the server, then clears it.
  @override
  Future<void> syncPendingUpdate(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingKey(userId));
      if (raw == null) return;

      final update = jsonDecode(raw) as Map<String, dynamic>;
      final description = update['description'] as String?;
      if (description == null) return;

      await _apiClient.patch(
        '/users/$userId',
        body: {'description': description},
      );
      await prefs.remove(_pendingKey(userId));
    } catch (_) {
      // Sync failed — leave the key in place; retry on next connectivity event.
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _writeCache(String key, Map<String, dynamic> value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(value));
    } catch (_) {
      // Cache write failure must never crash the app.
    }
  }

  Future<Map<String, dynamic>?> _readCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> _writePendingUpdate(
    String userId,
    String description,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _pendingKey(userId),
        jsonEncode({'description': description}),
      );
    } catch (_) {}
  }
}
