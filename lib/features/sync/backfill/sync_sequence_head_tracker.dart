import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';

/// Tracks recent origin announcements and bounded repair scans. Announcements
/// are observations, not receipts. They expire when an origin stops announcing;
/// after a restart, a subsequent announcement restores this volatile state.
class SyncSequenceHeadTracker {
  SyncSequenceHeadTracker({
    required this._database,
    required this._sequenceLog,
    required this._freshness,
  });

  final SyncDatabase _database;
  final SyncSequenceLogService _sequenceLog;
  final Duration _freshness;
  final _heads = <String, _AnnouncedHead>{};
  int _scanStart = 0;
  int _requestStart = 0;

  /// Retains the maximum announced counter without reviving stale scan state.
  void observe(String hostId, int counter) {
    _prune();
    if (hostId.isEmpty || counter < 1) return;
    final head = _heads[hostId];
    if (head == null) {
      _heads[hostId] = _AnnouncedHead(counter, clock.now());
    } else {
      head
        ..counter = math.max(head.counter, counter)
        ..seenAt = clock.now();
    }
  }

  bool get hasFreshHeads {
    _prune();
    return _heads.isNotEmpty;
  }

  void _prune() {
    final cutoff = clock.now().subtract(_freshness);
    _heads.removeWhere((_, head) => !head.seenAt.isAfter(cutoff));
  }

  /// Advances scan cursors fairly, spending at most [limit] counters per pass.
  /// Snapshot-covered ranges are left to onboarding's own delivery protocol.
  Future<void> materialize({
    required int limit,
    required int perHost,
    Map<String, int> suppressedCoverage = const {},
  }) async {
    _prune();
    final hosts = _heads.keys.toList();
    if (hosts.isEmpty) return;
    var remaining = limit;
    final start = _scanStart % hosts.length;
    for (var i = 0; i < hosts.length && remaining > 0; i++) {
      final index = (start + i) % hosts.length;
      final hostId = hosts[index];
      final head = _heads[hostId];
      if (head == null) continue;
      // Coverage promises future delivery, not durable receipt. Do not move
      // the scan cursor over it: a failed snapshot must leave it discoverable.
      if ((suppressedCoverage[hostId] ?? 0) > head.scannedTo) continue;
      final allowance = math.min(remaining, perHost);
      head.scannedTo = await _sequenceLog.materializeAnnouncedHead(
        hostId: hostId,
        head: head.counter,
        limit: allowance,
        afterCounter: head.scannedTo,
      );
      remaining -= allowance;
      _scanStart = index + 1;
    }
  }

  /// Old or exhausted gaps become eligible again only while their origin is
  /// announcing. Cooldown and pending/in-flight request dedup remain enforced.
  /// Pagination skips full pages already queued or covered by onboarding.
  Future<List<SyncSequenceLogItem>> loadRepairBatch({
    required int limit,
    required int perHost,
    required Duration retryCooldown,
    Map<String, int> suppressedCoverage = const {},
  }) async {
    _prune();
    final hosts = _heads.keys.toList();
    if (hosts.isEmpty) return [];
    final pending = await _database.getPendingBackfillEntries();
    final selected = <SyncSequenceLogItem>[];
    final start = _requestStart % hosts.length;
    for (var i = 0; i < hosts.length && selected.length < limit; i++) {
      final index = (start + i) % hosts.length;
      final hostId = hosts[index];
      final head = _heads[hostId];
      if (head == null) continue;
      final allowance = math.min(limit - selected.length, perHost);
      var chosen = 0;
      var offset = 0;
      while (chosen < allowance) {
        final page = await _database.getAnnouncedHeadRepairEntries(
          hostId: hostId,
          head: head.counter,
          limit: allowance,
          offset: offset,
          retryCooldown: retryCooldown,
          afterCounter: suppressedCoverage[hostId] ?? 0,
        );
        if (page.isEmpty) break;
        offset += page.length;
        for (final row in page) {
          if (row.counter <= (suppressedCoverage[hostId] ?? 0) ||
              pending.contains((hostId: hostId, counter: row.counter))) {
            continue;
          }
          selected.add(row);
          if (++chosen == allowance) break;
        }
        if (page.length < allowance) break;
      }
      _requestStart = index + 1;
    }
    return selected;
  }
}

class _AnnouncedHead {
  _AnnouncedHead(this.counter, this.seenAt);

  int counter;
  DateTime seenAt;
  int scannedTo = 0;
}
