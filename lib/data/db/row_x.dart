/// Row-access helpers for `Map<String, Object?>` query results.
///
/// Centralizes the audit-column decoding that used to be copy-pasted in every
/// repository `_fromRow`.
library;

extension RowX on Map<String, Object?> {
  /// Parse a required int-timestamp column into a UTC [DateTime].
  DateTime dateTime(String key) {
    final v = this[key];
    if (v is! int) {
      throw StateError('RowX.dateTime($key): expected int, got $v');
    }
    return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true);
  }

  /// Parse an optional int-timestamp column; null stays null.
  DateTime? nullableDateTime(String key) {
    final v = this[key];
    if (v == null) return null;
    return dateTime(key);
  }

  /// Int with default when the column is missing/null.
  int intOr(String key, int fallback) => (this[key] as int?) ?? fallback;

  /// Bool stored as 0/1.
  bool boolOr(String key, [bool fallback = false]) {
    final v = this[key];
    if (v == null) return fallback;
    return v == 1;
  }
}
