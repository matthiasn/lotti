import 'dart:async';

import 'package:lotti/features/sync/matrix/pipeline_v2/attachment_index.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:meta/meta.dart';

/// DescriptorCatchUpManager
///
/// Purpose
/// - Tracks pending JSON paths that failed due to missing attachment descriptors
///   and proactively runs a descriptor-focused catch-up when the pending set is
///   stable for a short period. This catch-up scans a large live snapshot and
///   records any `relativePath` descriptors into the shared AttachmentIndex to
///   unblock SmartJournalEntityLoader.
///
/// Responsibilities
/// - Maintain a set of pending jsonPaths (stores both with/without leading '/').
/// - Debounce and run descriptor catch-up using the current room timeline.
/// - On hits, nudge the caller via `retryNow` and `scheduleLiveScan`.
/// - Provide lightweight counters (pending size, runs) for metrics.
class DescriptorCatchUpManager {
  DescriptorCatchUpManager({
    required LoggingService logging,
    required AttachmentIndex attachmentIndex,
    required SyncRoomManager roomManager,
    required void Function() scheduleLiveScan,
    required Future<void> Function() retryNow,
    DateTime Function()? now,
  })  : _logging = logging,
        _attachmentIndex = attachmentIndex,
        _roomManager = roomManager,
        _scheduleLiveScan = scheduleLiveScan,
        _retryNow = retryNow,
        _now = now ?? DateTime.now;

  final LoggingService _logging;
  final AttachmentIndex _attachmentIndex;
  final SyncRoomManager _roomManager;
  final void Function() _scheduleLiveScan;
  final Future<void> Function() _retryNow;
  final DateTime Function() _now;

  final Set<String> _pending = <String>{};
  Timer? _timer;
  DateTime? _lastChanged;
  int _runs = 0;
  bool _isRunning = false;

  static const Duration _delay = Duration(seconds: 2);

  /// Adds a jsonPath (stores both variants) and schedules a stability check.
  void addPending(String jsonPath) {
    final v = _variants(jsonPath);
    var changed = false;
    for (final s in v) {
      if (_pending.add(s)) changed = true;
    }
    if (changed) {
      _markChanged();
    }
  }

  /// Removes a jsonPath (both variants). Returns true if anything was removed.
  bool removeIfPresent(String jsonPath) {
    final v = _variants(jsonPath);
    var removed = false;
    for (final s in v) {
      removed = _pending.remove(s) || removed;
    }
    if (removed) _markChanged();
    return removed;
  }

  /// True if the pending set contains a jsonPath (in either variant form).
  bool contains(String jsonPath) {
    final v = _variants(jsonPath);
    for (final s in v) {
      if (_pending.contains(s)) return true;
    }
    return false;
  }

  int get pendingLength => _pending.length;
  int get runs => _runs;

  void dispose() {
    _timer?.cancel();
  }

  void _markChanged() {
    _lastChanged = _now();
    _scheduleCheck();
  }

  void _scheduleCheck() {
    if (_pending.isEmpty) return;
    _timer?.cancel();
    _timer = Timer(_delay, () {
      final last = _lastChanged;
      if (last == null) return;
      final now = _now();
      final stable = now.difference(last) >= _delay;
      if (stable && _pending.isNotEmpty) {
        // Avoid overlapping runs; if one is in-flight, reschedule a new check.
        if (_isRunning) {
          _scheduleCheck();
        } else {
          // Fire and forget; internal logs capture exceptions.
          unawaited(_guardedRunCatchUp());
        }
      } else {
        _scheduleCheck();
      }
    });
  }

  Future<void> _guardedRunCatchUp() async {
    if (_isRunning) return; // Double-guard
    _isRunning = true;
    try {
      await _runCatchUp();
    } finally {
      _isRunning = false;
      // If changes accumulated while running, schedule another pass.
      if (_pending.isNotEmpty) {
        _scheduleCheck();
      }
    }
  }

  Future<void> _runCatchUp() async {
    try {
      final room = _roomManager.currentRoom;
      if (room == null) return;
      _logging.captureEvent(
        'descriptorCatchUp.start pending=${_pending.length}',
        domain: 'MATRIX_SYNC_V2',
        subDomain: 'descriptorCatchUp',
      );
      final snapshot = await room.getTimeline(limit: 1000);
      var recorded = 0;
      var pendingHits = 0;
      try {
        final events = List<Event>.from(snapshot.events)
          ..sort(TimelineEventOrdering.compare);
        for (final e in events) {
          final rp = e.content['relativePath'];
          if (rp is String && rp.isNotEmpty) {
            _attachmentIndex.record(e);
            recorded++;
            if (contains(rp)) {
              pendingHits++;
            }
          }
        }
      } finally {
        try {
          snapshot.cancelSubscriptions();
        } catch (e, st) {
          // Log cleanup failures to aid debugging; do not rethrow.
          _logging.captureException(
            e,
            domain: 'MATRIX_SYNC_V2',
            subDomain: 'descriptorCatchUp.cleanup',
            stackTrace: st,
          );
        }
      }
      _runs++;
      _logging.captureEvent(
        'descriptorCatchUp.summary recorded=$recorded pendingHits=$pendingHits',
        domain: 'MATRIX_SYNC_V2',
        subDomain: 'descriptorCatchUp',
      );
      if (pendingHits > 0) {
        await _retryNow();
        _scheduleLiveScan();
      }
    } catch (e, st) {
      _logging.captureException(
        e,
        domain: 'MATRIX_SYNC_V2',
        subDomain: 'descriptorCatchUp',
        stackTrace: st,
      );
    }
  }

  /// Test-only: forces a catch-up run immediately (if a room is available).
  @visibleForTesting
  Future<void> debugRunNow() => _runCatchUp();

  Iterable<String> _variants(String p) sync* {
    if (p.isEmpty) return;
    if (p.startsWith('/')) {
      yield p;
      yield p.substring(1);
    } else {
      yield p;
      yield '/$p';
    }
  }
}
