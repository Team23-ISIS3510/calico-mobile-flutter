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

import '../../../../core/cache/array_map.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ApiClient _apiClient;

  ProfileRepositoryImpl(this._apiClient);

  bool _lastLoadFromCache = false;

  // In-memory L1 layer for pending offline description edits.
  //
  // ArrayMap<userId, pendingDescription> — one entry per user who edited their
  // profile while offline. The collection is always tiny (≤ 1 active user on a
  // personal device), so ArrayMap's O(log n) binary search costs ≤ 1 comparison
  // in practice and its zero fixed-overhead layout beats HashMap's 128-byte
  // minimum bucket array.
  //
  // Two-layer strategy:
  //   L1 — this ArrayMap: checked first during sync. No deserialization cost;
  //         survives the session but not an app restart.
  //   L2 — SharedPreferences (key: pending_profile_update_<userId>): written
  //         in parallel so the edit survives a cold restart. Read only when L1
  //         misses (i.e. the app was killed and relaunched between the offline
  //         edit and the reconnection).
  static final ArrayMap<String, String> _inMemoryPatch = ArrayMap();

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
      // Save the pending edit to both layers so syncPendingUpdate can POST it
      // later: L1 (ArrayMap, in-memory, fast) and L2 (SharedPreferences,
      // survives a cold restart).
      if (description != null) {
        _inMemoryPatch[userId] = description;
        await _writePendingUpdate(userId, description);
      }

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
      body: {'description': ?description, 'courses': ?courses},
    );
    final profile = UserProfile.fromJson(data);
    await _writeCache(_cacheKey(userId), data);
    return profile;
  }

  /// Sends any pending offline description edit to the server, then clears it.
  @override
  Future<void> syncPendingUpdate(String userId) async {
    try {
      // L1: check the in-memory ArrayMap first — no deserialization needed.
      final inMemory = _inMemoryPatch[userId];
      if (inMemory != null) {
        await _apiClient.patch('/users/$userId', body: {'description': inMemory});
        _inMemoryPatch.remove(userId);
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_pendingKey(userId));
        return;
      }

      // L2: L1 missed (app was restarted between edit and reconnect) — fall
      // back to SharedPreferences.
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
      // Sync failed — leave both layers in place; retry on next connectivity event.
    }
  }

  @override
  Future<bool> hasPendingUpdate(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_pendingKey(userId));
    } catch (_) {
      return false;
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

  Future<void> _writePendingUpdate(String userId, String description) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _pendingKey(userId),
        jsonEncode({'description': description}),
      );
    } catch (_) {}
  }
}
