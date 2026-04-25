// WHY HIVE FOR THE TUTOR CAROUSEL?
// The tutor list is fetched on every CourseDetailScreen open and is moderately
// sized (5–20 objects).  Hive is a better fit than SharedPreferences because:
//   - Data is partitioned per-courseId — each key is independent
//   - Hive stores raw bytes, faster reads than parsing JSON from prefs
//   - No SQL schema needed — the data shape matches our existing fromJson()
//
// TRADE-OFF vs SQLite: Hive has no relational queries, but we only need a
// simple key (courseId) → value lookup.
//
// CACHE EXPIRY: 30 minutes.  Tutor availability changes frequently, so we
// balance freshness against unnecessary network round-trips.
//
// STORED FORMAT per key:
//   { "cachedAt": "<ISO-8601>", "tutors": [ <raw API objects> ] }
// Raw API objects are stored (not entities) so AvailableTutorModel.fromJson()
// reconstructs them without needing a Hive TypeAdapter.

import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/tutor_entity.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../models/available_tutor_model.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  final ApiClient _apiClient;

  static const String _boxName = 'recommended_tutors';
  static const Duration _cacheTtl = Duration(minutes: 30);

  const AnalyticsRepositoryImpl(this._apiClient);

  @override
  Future<TutorEntity?> getReturningTutor(
    String studentId,
    String courseId,
  ) async {
    final data = await _apiClient.get(
      '/analytics/returning-tutor',
      query: {'student': studentId, 'course': courseId},
    );
    final raw = data['tutor'];
    if (raw == null) return null;
    return AvailableTutorModel.fromJson(raw as Map<String, dynamic>).toEntity();
  }

  @override
  Future<void> trackCarouselEvent(
    String event,
    String courseId, {
    String? tutorId,
    double? tutorRating,
    int? resultCount,
    int? countdownMinutes,
  }) async {
    try {
      await _apiClient.post(
        '/analytics/event',
        body: {
          'event': event,
          'courseId': courseId,
          'tutorId': ?tutorId,
          'tutorRating': ?tutorRating,
          'resultCount': ?resultCount,
          'countdownMinutes': ?countdownMinutes,
        },
      );
    } catch (_) {
      // Fire-and-forget: never let tracking break the UI.
    }
  }

  @override
  Future<List<TutorEntity>> getAvailableTutors(String courseId) async {
    final box = Hive.box<String>(_boxName);

    // ── 1. Check Hive cache ───────────────────────────────────────────────
    final cached = box.get(courseId);
    if (cached != null) {
      try {
        final entry = jsonDecode(cached) as Map<String, dynamic>;
        final cachedAt = DateTime.parse(entry['cachedAt'] as String);

        if (DateTime.now().difference(cachedAt) < _cacheTtl) {
          // Cache is still fresh — return without hitting the network.
          return _parseRawList(entry['tutors'] as List<dynamic>);
        }
      } catch (_) {
        // Corrupt cache entry — fall through to a fresh fetch.
      }
    }

    // ── 2. Fetch from API ─────────────────────────────────────────────────
    try {
      final data = await _apiClient.get(
        '/analytics/bookable-tutors',
        query: {'course': courseId},
      );
      final rawList = (data['tutors'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();

      // ── 3. Save raw response to Hive ──────────────────────────────────
      try {
        await box.put(
          courseId,
          jsonEncode({
            'cachedAt': DateTime.now().toIso8601String(),
            'tutors': rawList,
          }),
        );
      } catch (_) {
        // Cache write failure must never block the UI.
      }

      return rawList
          .map((j) => AvailableTutorModel.fromJson(j).toEntity())
          .toList();
    } catch (_) {
      // ── 4. Offline fallback: return expired cache rather than empty list ──
      if (cached != null) {
        try {
          final entry = jsonDecode(cached) as Map<String, dynamic>;
          return _parseRawList(entry['tutors'] as List<dynamic>);
        } catch (_) {}
      }
      rethrow;
    }
  }

  List<TutorEntity> _parseRawList(List<dynamic> raw) {
    return raw
        .whereType<Map<String, dynamic>>()
        .map((j) => AvailableTutorModel.fromJson(j).toEntity())
        .toList();
  }
}
