import 'package:flutter_test/flutter_test.dart';
import 'package:calico_mobile_flutter/core/cache/lru_cache.dart';

void main() {
  group('LRUCache', () {
    // ── Basic get/put ───────────────────────────────────────────────────────

    test('returns null on a cold cache (miss)', () {
      final cache = LRUCache<String, int>(maxSize: 3);
      expect(cache.get('a'), isNull);
    });

    test('returns value immediately after put (hit)', () {
      final cache = LRUCache<String, int>(maxSize: 3);
      cache.put('a', 1);
      expect(cache.get('a'), 1);
    });

    // ── LRU eviction ────────────────────────────────────────────────────────

    test('evicts the least recently used entry when maxSize is exceeded', () {
      // Fill to capacity: a, b, c (a is LRU, c is MRU)
      final cache = LRUCache<String, int>(maxSize: 3);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);

      // Adding a 4th entry must evict 'a' (LRU)
      cache.put('d', 4);

      expect(cache.get('a'), isNull); // evicted
      expect(cache.get('b'), 2);
      expect(cache.get('c'), 3);
      expect(cache.get('d'), 4);
    });

    test('accessing an entry promotes it to MRU and protects it from eviction',
        () {
      final cache = LRUCache<String, int>(maxSize: 3);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);

      // Touch 'a' — it moves to MRU, so 'b' becomes LRU
      cache.get('a');

      // Adding a 4th entry should now evict 'b', not 'a'
      cache.put('d', 4);

      expect(cache.get('a'), 1); // protected by recent access
      expect(cache.get('b'), isNull); // evicted
      expect(cache.get('c'), 3);
      expect(cache.get('d'), 4);
    });

    test('re-putting an existing key refreshes it to MRU', () {
      final cache = LRUCache<String, int>(maxSize: 3);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);

      // Re-insert 'a' with a new value — it should move to MRU
      cache.put('a', 99);

      // Adding 'd' should evict 'b' (now the LRU), not 'a'
      cache.put('d', 4);

      expect(cache.get('a'), 99); // updated and protected
      expect(cache.get('b'), isNull); // evicted
    });

    // ── TTL expiry ──────────────────────────────────────────────────────────

    test('returns null after the TTL has elapsed', () async {
      final cache = LRUCache<String, int>(
        maxSize: 3,
        ttl: const Duration(milliseconds: 10),
      );
      cache.put('a', 1);

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(cache.get('a'), isNull); // expired
    });

    test('returns value when TTL has not yet elapsed', () async {
      final cache = LRUCache<String, int>(
        maxSize: 3,
        ttl: const Duration(seconds: 10),
      );
      cache.put('a', 1);

      // A tiny delay — well within the 10-second TTL
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(cache.get('a'), 1);
    });

    test('expired entry is removed so it does not block a fresh put', () async {
      final cache = LRUCache<String, int>(
        maxSize: 1,
        ttl: const Duration(milliseconds: 10),
      );
      cache.put('a', 1);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Cache appears empty (expired) — putting a new key should not evict
      // anything; the new entry should be stored cleanly.
      cache.put('b', 2);
      expect(cache.get('b'), 2);
    });

    // ── invalidate / clear ──────────────────────────────────────────────────

    test('invalidate removes a specific key', () {
      final cache = LRUCache<String, int>(maxSize: 3);
      cache.put('a', 1);
      cache.put('b', 2);

      cache.invalidate('a');

      expect(cache.get('a'), isNull);
      expect(cache.get('b'), 2); // unaffected
    });

    test('clear removes all entries', () {
      final cache = LRUCache<String, int>(maxSize: 3);
      cache.put('a', 1);
      cache.put('b', 2);
      cache.put('c', 3);

      cache.clear();

      expect(cache.get('a'), isNull);
      expect(cache.get('b'), isNull);
      expect(cache.get('c'), isNull);
    });

    // ── Edge cases ──────────────────────────────────────────────────────────

    test('maxSize=1 evicts the only entry when a second key is added', () {
      final cache = LRUCache<String, int>(maxSize: 1);
      cache.put('a', 1);
      cache.put('b', 2); // 'a' must be evicted

      expect(cache.get('a'), isNull);
      expect(cache.get('b'), 2);
    });

    test('stores different value types correctly', () {
      final cache = LRUCache<String, List<String>>(maxSize: 2);
      cache.put('courses', ['MATH101', 'PHYS202']);

      expect(cache.get('courses'), ['MATH101', 'PHYS202']);
    });
  });
}
