/// Envelope used by repositories that support offline fallback.
///
/// [data] is always the payload to render. [isFromCache] is `true` when the
/// remote call failed and the local SQLite cache was used. [lastUpdated] is
/// the timestamp of the last successful remote fetch for that payload (may be
/// `null` when the data was just fetched fresh and the timestamp is implicit).
class CachedResult<T> {
  final T data;
  final bool isFromCache;
  final DateTime? lastUpdated;

  const CachedResult({
    required this.data,
    this.isFromCache = false,
    this.lastUpdated,
  });
}
