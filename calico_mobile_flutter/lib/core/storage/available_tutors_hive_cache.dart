import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../features/home/domain/entities/tutor_entity.dart';

/// Hive-backed cache for the "Top Rated & Available Soon" carousel.
///
/// Keyed by `courseId`. Each value is a JSON blob with the cache timestamp
/// and the serialized tutor list, so the repository can surface a
/// [DateTime?] lastUpdated via [CachedResult] when it falls back to cache.
///
/// Why Hive and not SQLite here: the workload is a pure key → blob lookup
/// with no relational queries, and the list is rewritten whole on every
/// successful fetch. Hive reads raw bytes directly, which is a touch faster
/// than SQLite's statement parser for this shape.
class AvailableTutorsHiveCache {
  AvailableTutorsHiveCache({String boxName = 'available_tutors_cache'})
      : _boxName = boxName;

  static final AvailableTutorsHiveCache instance = AvailableTutorsHiveCache();

  final String _boxName;
  Box<String>? _cachedBox;

  Future<Box<String>> _box() async {
    final cached = _cachedBox;
    if (cached != null && cached.isOpen) return cached;
    final box = Hive.isBoxOpen(_boxName)
        ? Hive.box<String>(_boxName)
        : await Hive.openBox<String>(_boxName);
    _cachedBox = box;
    return box;
  }

  Future<AvailableTutorsCacheEntry?> read(String courseId) async {
    try {
      final box = await _box();
      final raw = box.get(courseId);
      if (raw == null) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final cachedAt = _parseIso(decoded['cachedAt']);
      final rawList = (decoded['tutors'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(_tutorFromJson)
          .toList();
      return AvailableTutorsCacheEntry(tutors: rawList, cachedAt: cachedAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String courseId, List<TutorEntity> tutors) async {
    try {
      final box = await _box();
      final payload = jsonEncode({
        'cachedAt': DateTime.now().toUtc().toIso8601String(),
        'tutors': tutors.map(_tutorToJson).toList(),
      });
      await box.put(courseId, payload);
    } catch (_) {
      // Cache writes are best-effort — never block the remote path.
    }
  }

  Future<void> clear() async {
    try {
      final box = await _box();
      await box.clear();
    } catch (_) {
      // Ignore — nothing to recover from.
    }
  }
}

class AvailableTutorsCacheEntry {
  const AvailableTutorsCacheEntry({
    required this.tutors,
    required this.cachedAt,
  });

  final List<TutorEntity> tutors;
  final DateTime? cachedAt;
}

// ── Serialization (kept local to avoid coupling with the SQLite path) ───────

Map<String, dynamic> _tutorToJson(TutorEntity t) => {
      'id': t.id,
      'name': t.name,
      'rating': t.rating,
      'hourlyRate': t.hourlyRate,
      'profileImage': t.profileImage,
      'location': t.location,
      'nextSlotStart': t.nextSlotStart?.toIso8601String(),
      'nextSlotEnd': t.nextSlotEnd?.toIso8601String(),
      'parentAvailabilityId': t.parentAvailabilityId,
      'nextSlotIndex': t.nextSlotIndex,
      'availableSlotsCount': t.availableSlotsCount,
      'bookingCount': t.bookingCount,
    };

TutorEntity _tutorFromJson(Map<String, dynamic> j) => TutorEntity(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      rating: (j['rating'] as num?)?.toDouble() ?? 0.0,
      hourlyRate: (j['hourlyRate'] as num?)?.toDouble(),
      profileImage: j['profileImage'] as String?,
      location: j['location'] as String? ?? 'Virtual',
      nextSlotStart: _parseIso(j['nextSlotStart']),
      nextSlotEnd: _parseIso(j['nextSlotEnd']),
      parentAvailabilityId: j['parentAvailabilityId'] as String?,
      nextSlotIndex: (j['nextSlotIndex'] as num?)?.toInt(),
      availableSlotsCount: (j['availableSlotsCount'] as num?)?.toInt() ?? 0,
      bookingCount: (j['bookingCount'] as num?)?.toInt(),
    );

DateTime? _parseIso(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}
