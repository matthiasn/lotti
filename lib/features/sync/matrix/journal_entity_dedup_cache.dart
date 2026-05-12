import 'dart:collection';

import 'package:lotti/features/sync/vector_clock.dart';
import 'package:meta/meta.dart';

/// LRU cache of recently-processed journal entity fingerprints, keyed by
/// `entryId`. Used by `SyncEventProcessor` to short-circuit replays of the
/// same `(entryId, vectorClock)` pair without re-running the apply pipeline.
///
/// The dedup key is the **pair**, not the id alone — a new vector clock for
/// a known entryId is treated as a legitimate subsequent write, not a
/// duplicate. Only exact-pair replays (e.g. Matrix redeliveries of the same
/// logical write) are dropped.
class JournalEntityDedupCache {
  JournalEntityDedupCache({int capacity = _defaultCapacity})
    : assert(capacity > 0, 'capacity must be positive'),
      _capacity = capacity;

  /// Default cache size. Matches the original in-processor limit and is
  /// sized so that a single catch-up wave (typically dozens to low hundreds
  /// of events) stays fully cached.
  static const int _defaultCapacity = 500;

  final int _capacity;
  final LinkedHashMap<String, String> _fingerprints =
      LinkedHashMap<String, String>();

  /// Returns true when `entryId` was already marked with `vectorClock`.
  /// Touches the entry to most-recently-used on hit. A null clock is never
  /// a duplicate (the apply path treats clock-less messages as one-shot).
  bool isDuplicate(String entryId, VectorClock? vectorClock) {
    if (vectorClock == null) return false;
    final fingerprint = fingerprintOf(vectorClock);
    final cached = _fingerprints[entryId];
    if (cached == null || cached != fingerprint) {
      return false;
    }
    _fingerprints
      ..remove(entryId)
      ..[entryId] = fingerprint;
    return true;
  }

  /// Records or refreshes `(entryId, vectorClock)` as most-recently-used.
  /// Evicts the LRU entry when over capacity. Null clocks are ignored.
  void markProcessed(String entryId, VectorClock? vectorClock) {
    if (vectorClock == null) return;
    final fingerprint = fingerprintOf(vectorClock);
    _fingerprints
      ..remove(entryId)
      ..[entryId] = fingerprint;
    if (_fingerprints.length > _capacity) {
      _fingerprints.remove(_fingerprints.keys.first);
    }
  }

  /// Deterministic fingerprint of a vector clock's `(hostId, counter)`
  /// entries. Insertion-order-independent (entries are sorted by hostId).
  static String fingerprintOf(VectorClock vectorClock) {
    final entries = vectorClock.vclock.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.map((entry) => '${entry.key}:${entry.value}').join('|');
  }

  @visibleForTesting
  int get size => _fingerprints.length;

  @visibleForTesting
  int get capacity => _capacity;

  @visibleForTesting
  List<String> get orderedKeys => _fingerprints.keys.toList(growable: false);
}
