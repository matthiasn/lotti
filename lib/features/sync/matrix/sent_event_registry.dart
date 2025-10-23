import 'dart:collection';

import 'package:clock/clock.dart';

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
/// The registry keeps a bounded set of IDs and evicts entries after a short TTL
/// (minutes). When timeline playback echoes an event with a matching ID, we can
/// skip the expensive ingest path and advance the read marker immediately.
class SentEventRegistry {
  SentEventRegistry({
    this.ttl = const Duration(minutes: 2),
    this.maxEntries = 5000,
    Clock? clockSource,
  })  : assert(!ttl.isNegative, 'ttl must not be negative'),
        assert(maxEntries > 0, 'maxEntries must be positive'),
        _clock = clockSource ?? clock;

  final Duration ttl;
  final int maxEntries;
  final Clock _clock;

  final LinkedHashMap<String, _RegistryEntry> _entries =
      LinkedHashMap<String, _RegistryEntry>();

  /// Registers [eventId] with a new expiry.
  void register(
    String eventId, {
    SentEventSource? source,
  }) {
    if (eventId.isEmpty) return;
    final now = _clock.now();
    _prune(now);
    if (!_entries.containsKey(eventId)) {
      while (_entries.length >= maxEntries) {
        _entries.remove(_entries.keys.first);
      }
    }
    _entries[eventId] = _RegistryEntry(
      expiry: now.add(ttl),
      source: source,
    );
  }

  /// Consumes [eventId] if present and not expired.
  ///
  /// Returns `true` when the event ID originated from this registry and still
  /// falls within the TTL window.
  bool consume(String eventId) {
    if (eventId.isEmpty) return false;
    final now = _clock.now();
    final entry = _entries.remove(eventId);
    if (entry == null) {
      _prune(now);
      return false;
    }
    if (entry.expiry.isBefore(now)) {
      return false;
    }
    return true;
  }

  /// Removes expired entries relative to the provided [now] (or current time).
  void prune([DateTime? now]) {
    _prune(now ?? _clock.now());
  }

  /// Removes all entries (test/helper).
  void clear() {
    _entries.clear();
  }

  /// Number of tracked event IDs (including pending expirations).
  int get length => _entries.length;

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
    required this.source,
  });

  final DateTime expiry;
  final SentEventSource? source;
}
