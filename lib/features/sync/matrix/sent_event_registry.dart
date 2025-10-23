import 'dart:collection';

import 'package:clock/clock.dart';
import 'package:meta/meta.dart';

/// Identifies the origin of a sent event for diagnostics.
enum SentEventSource {
  text,
  file,
}

extension SentEventSourceLabel on SentEventSource {
  String get label => switch (this) {
        SentEventSource.text => 'text',
        SentEventSource.file => 'file',
      };
}

/// In-memory registry of Matrix event IDs emitted by this device.
///
/// Not thread-safe; relies on Dart's single-threaded event loop.
/// The registry keeps a bounded, FIFO-evicted set of IDs and evicts entries
/// after a configurable TTL. Timeline playback can use this to short-circuit
/// echoed events without re-applying database work.
class SentEventRegistry {
  SentEventRegistry({
    this.ttl = const Duration(minutes: 5),
    this.maxEntries = 5000,
    this.pruneInterval = const Duration(seconds: 30),
    Clock? clockSource,
  })  : assert(!ttl.isNegative, 'ttl must not be negative'),
        assert(maxEntries > 0, 'maxEntries must be positive'),
        assert(!pruneInterval.isNegative, 'pruneInterval must not be negative'),
        _clock = clockSource ?? clock,
        _nextPruneAt = (clockSource ?? clock).now();

  final Duration ttl;
  final int maxEntries;
  final Duration pruneInterval;
  final Clock _clock;

  final LinkedHashMap<String, _RegistryEntry> _entries =
      LinkedHashMap<String, _RegistryEntry>();
  DateTime _nextPruneAt;

  /// Registers [eventId] with a fresh expiry.
  void register(
    String eventId, {
    SentEventSource? source,
  }) {
    assert(eventId.isNotEmpty, 'Matrix event IDs must not be empty');
    if (eventId.isEmpty) return;
    final now = _clock.now();
    _maybePrune(now, force: _entries.length >= maxEntries);

    // Refresh order when re-registering an existing id.
    final existing = _entries.remove(eventId);
    final expiry = now.add(ttl);
    _entries[eventId] = _RegistryEntry(
      expiry: expiry,
      source: source ?? existing?.source,
    );

    // Enforce maxEntries (FIFO) after refresh.
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  /// Returns `true` when [eventId] was previously registered and has not
  /// expired. The entry remains in the registry until it naturally expires.
  bool consume(String eventId) {
    assert(eventId.isNotEmpty, 'Matrix event IDs must not be empty');
    if (eventId.isEmpty) return false;
    final now = _clock.now();
    _maybePrune(now);

    final entry = _entries[eventId];
    if (entry == null) {
      // Opportunistically prune if we missed due to interval checks.
      _maybePrune(now, force: true);
      return false;
    }
    if (entry.expiry.isBefore(now)) {
      _entries.remove(eventId);
      _maybePrune(now, force: true);
      return false;
    }
    return true;
  }

  /// Removes expired entries relative to [now] (or current time).
  void prune([DateTime? now]) {
    _prune(now ?? _clock.now());
  }

  /// Removes all entries (primarily for tests).
  void clear() {
    _entries.clear();
    _nextPruneAt = _clock.now().add(pruneInterval);
  }

  /// Number of tracked event IDs (including pending expirations).
  int get length => _entries.length;

  @visibleForTesting
  DateTime get debugNextPruneAt => _nextPruneAt;

  @visibleForTesting
  SentEventSource? debugSource(String eventId) => _entries[eventId]?.source;

  void _maybePrune(DateTime now, {bool force = false}) {
    if (!force && now.isBefore(_nextPruneAt)) return;
    _prune(now);
    _nextPruneAt = now.add(pruneInterval);
  }

  void _prune(DateTime now) {
    _entries.removeWhere((_, entry) => entry.expiry.isBefore(now));
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }
}

class _RegistryEntry {
  _RegistryEntry({
    required this.expiry,
    this.source,
  });

  final DateTime expiry;
  final SentEventSource? source;
}
