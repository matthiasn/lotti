import 'package:meta/meta.dart';

class RetryTracker {
  RetryTracker({
    required this.ttl,
    required this.maxEntries,
  });

  final Duration ttl;
  final int maxEntries;

  final Map<String, _RetryInfo> _map = <String, _RetryInfo>{};

  int size() => _map.length;

  int attempts(String id) => _map[id]?.attempts ?? 0;

  /// Returns the nextDue if the event is currently blocked, otherwise null.
  DateTime? blockedUntil(String id, DateTime now) {
    final rs = _map[id];
    if (rs == null) return null;
    return now.isBefore(rs.nextDue) ? rs.nextDue : null;
  }

  void scheduleNext(String id, int attempts, DateTime nextDue) {
    _map[id] = _RetryInfo(attempts, nextDue);
  }

  void clear(String id) {
    _map.remove(id);
  }

  void markAllDueNow(DateTime now) {
    if (_map.isEmpty) return;
    for (final e in _map.entries) {
      _map[e.key] = _RetryInfo(e.value.attempts, now);
    }
  }

  void prune(DateTime now) {
    if (_map.isEmpty) return;
    _map.removeWhere((_, info) => now.difference(info.nextDue) > ttl);
    if (_map.length <= maxEntries) return;
    final entries = _map.entries.toList()
      ..sort((a, b) => a.value.nextDue.compareTo(b.value.nextDue));
    final toRemove = _map.length - maxEntries;
    for (var i = 0; i < toRemove; i++) {
      _map.remove(entries[i].key);
    }
  }
}

@immutable
class _RetryInfo {
  const _RetryInfo(this.attempts, this.nextDue);
  final int attempts;
  final DateTime nextDue;
}

class CircuitBreaker {
  CircuitBreaker({
    required this.failureThreshold,
    required this.cooldown,
  });

  final int failureThreshold;
  final Duration cooldown;

  DateTime? _openUntil;
  int _consecutiveFailures = 0;

  /// Returns the remaining cooldown if the circuit is open, otherwise null.
  Duration? remainingCooldown(DateTime now) {
    final openUntil = _openUntil;
    if (openUntil == null) return null;
    if (now.isBefore(openUntil)) {
      return openUntil.difference(now);
    }
    return null;
  }

  /// Records [count] failures, opening the circuit if the threshold is
  /// reached. Returns true if the circuit transitioned to open.
  bool recordFailures(int count, DateTime now) {
    _consecutiveFailures += count;
    if (_consecutiveFailures >= failureThreshold) {
      _openUntil = now.add(cooldown);
      return true;
    }
    return false;
  }

  /// Resets the consecutive failure counter, closing the circuit on next check.
  void reset() {
    _consecutiveFailures = 0;
  }

  bool isOpen(DateTime now) => remainingCooldown(now) != null;
}
