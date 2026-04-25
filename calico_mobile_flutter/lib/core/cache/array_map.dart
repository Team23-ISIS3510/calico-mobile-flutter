// WHY ArrayMap?
//
// ArrayMap stores key-value pairs in two parallel sorted arrays — one for
// keys, one for values — and uses binary search for lookups.
//
// MEMORY advantage over HashMap for small collections:
//   HashMap allocates a backing bucket array (default 16 slots × 8 bytes =
//   128 B fixed overhead) plus a node per entry (~32 B). ArrayMap allocates
//   only two plain arrays of exactly n elements: ~16 B per entry, zero fixed
//   overhead. For 10 entries ArrayMap ≈ 160 B vs HashMap ≈ 480 B.
//
// SPEED for n ≤ ~20:
//   Binary search on n=10 needs ≤ 4 comparisons. HashMap hashes the key,
//   probes the bucket, and may follow a pointer chain — faster in theory
//   but with higher constant cost. Below ~20 entries binary search wins on
//   real hardware because both keys and values sit in contiguous memory,
//   which the CPU prefetcher handles efficiently (no pointer chasing).
//
// This mirrors Android's android.util.ArrayMap, which exists because the
// Android system process holds thousands of small Bundle/Intent maps; the
// per-map fixed overhead of HashMap adds up at that scale.
//
// USE WHEN:
//   • The map holds ≤ ~20 entries for its entire lifetime.
//   • Reads dominate writes (insert is O(n) due to the sorted-array shift).
//   • Memory matters — many such maps alive simultaneously, or entries are
//     replaced infrequently but read on every frame/render.
//
// AVOID WHEN:
//   • n > ~50: O(log n) search starts losing to hash O(1) in practice.
//   • High write frequency makes the O(n) insert cost meaningful.
//   • Keys are not Comparable (binary search requires total ordering).
//
// Compared to LRUCache (also in this package): LRUCache is a fixed-capacity
// evicting cache with a TTL per entry — right for hot remote data that must
// stay fresh. ArrayMap is a plain in-memory map with no eviction — right for
// small, bounded collections where you control all mutations yourself.

class ArrayMap<K extends Comparable<K>, V> {
  final List<K> _keys = [];
  final List<V> _values = [];

  int get length => _keys.length;
  bool get isEmpty => _keys.isEmpty;
  bool get isNotEmpty => _keys.isNotEmpty;

  // Binary search. Returns the index of [key] when found, or
  // -(insertionPoint + 1) when absent — same convention as Java's
  // Arrays.binarySearch, which lets callers derive the insertion index
  // without a second scan.
  int _search(K key) {
    int lo = 0, hi = _keys.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >>> 1;
      final cmp = _keys[mid].compareTo(key);
      if (cmp == 0) return mid;
      if (cmp < 0) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return -(lo + 1);
  }

  V? operator [](K key) {
    final i = _search(key);
    return i >= 0 ? _values[i] : null;
  }

  // O(log n) to find the slot, O(n) to shift the array on a new key.
  // Acceptable because writes here are rare compared to reads.
  void operator []=(K key, V value) {
    final i = _search(key);
    if (i >= 0) {
      _values[i] = value;
    } else {
      final ins = -i - 1;
      _keys.insert(ins, key);
      _values.insert(ins, value);
    }
  }

  bool containsKey(K key) => _search(key) >= 0;

  V? remove(K key) {
    final i = _search(key);
    if (i < 0) return null;
    _keys.removeAt(i);
    return _values.removeAt(i);
  }

  void clear() {
    _keys.clear();
    _values.clear();
  }

  Iterable<MapEntry<K, V>> get entries sync* {
    for (int i = 0; i < _keys.length; i++) {
      yield MapEntry(_keys[i], _values[i]);
    }
  }

  Iterable<K> get keys => _keys;
  Iterable<V> get values => _values;
}
