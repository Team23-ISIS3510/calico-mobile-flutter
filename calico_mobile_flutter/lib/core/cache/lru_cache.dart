// WHY LRU (Least Recently Used)?
// When the cache is full we must evict something. LRU discards the entry that
// was accessed least recently, which is a good proxy for "least likely to be
// needed again" under temporal locality: users tend to re-visit the same
// courses and tutors they looked at moments ago.
//
// Alternatives considered:
//   FIFO — evicts the oldest INSERT regardless of how often it was accessed.
//          Simple, but thrashes hot entries that were inserted early.
//   LFU  — evicts the least-frequently accessed entry. Better theoretical
//          optimality but requires a frequency counter per key and is O(log n)
//          to update. Overkill for a small in-memory cache (≤ 10 entries).
//   LRU  — O(1) get/put by combining a HashMap (O(1) lookup) with a doubly-
//          linked list (O(1) move-to-tail). Dart's LinkedHashMap gives us both
//          in a single built-in type. Winner for this use-case.
//
// WHY LinkedHashMap?
// LinkedHashMap maintains insertion order while still offering O(1) average-
// case get/put/remove (same as HashMap). The ordering invariant lets us treat
// the map as an implicit doubly-linked list:
//   - First key  → Least Recently Used  (next eviction candidate)
//   - Last key   → Most  Recently Used  (safe from eviction)
// Accessing an entry means removing it and re-inserting it at the tail — one
// remove + one insert, both O(1). No separate linked-list node needed.
//
// MEMORY vs NETWORK TRADE-OFF
// Every cached entry saves one HTTP round-trip (~200–400 ms on mobile) at the
// cost of a small heap allocation. The entries here are small (<10 KB each),
// so maxSize=10 caps worst-case overhead at roughly 100 KB — acceptable.
// TTL bounds staleness: tutor availability changes minute-to-minute (5 min
// TTL), while the course catalogue is essentially static (10 min TTL).

import 'dart:collection';

class _CacheEntry<V> {
  final V value;
  final DateTime expiresAt;

  _CacheEntry(this.value, Duration ttl)
      : expiresAt = DateTime.now().add(ttl);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Generic LRU cache with per-entry TTL expiry.
///
/// maxSize controls how many entries are held in memory before the least
/// recently used entry is evicted. ttl controls how long each entry stays
/// valid before being treated as a cache miss.
class LRUCache<K, V> {
  // maxSize=10: matches the approximate number of courses in the app.
  // Raising this beyond the catalogue size wastes memory with no benefit.
  final int maxSize;

  // ttl defaults to 5 minutes — appropriate for tutor availability data.
  // Course data overrides this to 10 minutes (more static).
  final Duration ttl;

  // LinkedHashMap preserves insertion/access order so keys.first is always
  // the LRU entry without maintaining a separate data structure.
  final LinkedHashMap<K, _CacheEntry<V>> _cache = LinkedHashMap();

  LRUCache({
    this.maxSize = 10,
    this.ttl = const Duration(minutes: 5),
  });

  /// Returns the cached value for [key], or null on miss/expiry.
  ///
  /// A hit moves the entry to the tail (most recently used position) so it
  /// is safe from the next eviction. An expired hit is removed and treated
  /// as a miss — the caller should re-fetch and call [put].
  V? get(K key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }

    // Promote to MRU: remove then re-insert so the key lands at the tail.
    _cache.remove(key);
    _cache[key] = entry;
    return entry.value;
  }

  /// Stores [value] under [key].
  ///
  /// If [key] already exists it is refreshed in place (moved to tail, TTL
  /// reset). If the cache is at capacity the LRU entry (first key) is evicted
  /// before the new entry is added.
  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      // Refresh existing entry: remove first so the re-insert lands at tail.
      _cache.remove(key);
    } else if (_cache.length >= maxSize) {
      // Evict LRU entry — keys.first is the least recently used because every
      // access and insert moves the touched key to the tail.
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = _CacheEntry(value, ttl);
  }

  /// Removes a single entry, forcing the next [get] to be a cache miss.
  /// Useful when external state changes make a specific entry stale.
  void invalidate(K key) => _cache.remove(key);

  /// Removes all entries. Use when the user logs out or data must be fully
  /// refreshed (e.g. pull-to-refresh).
  void clear() => _cache.clear();
}
