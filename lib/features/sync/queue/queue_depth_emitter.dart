import 'dart:async';

import 'package:lotti/features/sync/queue/inbound_queue_models.dart';

/// Owns the broadcast [QueueDepthSignal] stream for `InboundQueue`:
/// loads a [QueueStats] snapshot via [_loadStats], maps it to a
/// depth signal, and coalesces rapid successive triggers so only one
/// stats scan is in flight at a time.
///
/// Also owns the transaction hold-back protocol ([holdDuring]):
/// emissions scheduled while a batch body runs are deferred to a
/// single post-body emission, because firing them unawaited inside a
/// drift transaction zone captures the transaction's executor, which
/// is invalid after commit and trips drift's "transaction used after
/// being closed" guard.
class QueueDepthEmitter {
  QueueDepthEmitter({required this._loadStats});

  final Future<QueueStats> Function() _loadStats;

  final StreamController<QueueDepthSignal> _depthCtl =
      StreamController<QueueDepthSignal>.broadcast();

  int _holdDepth = 0;
  bool _holdDirty = false;
  bool _emitInFlight = false;
  bool _emitPendingRerun = false;

  Stream<QueueDepthSignal> get changes => _depthCtl.stream;

  /// Closes the stream; subsequent [schedule] calls become no-ops and
  /// in-flight stats loads are discarded silently.
  Future<void> dispose() => _depthCtl.close();

  /// Fire-and-forget emission trigger. While a [holdDuring] body is
  /// running, the trigger only marks the hold dirty so the body's
  /// finalizer fires one post-commit emission instead.
  void schedule() {
    if (_depthCtl.isClosed) return;
    if (_holdDepth > 0) {
      _holdDirty = true;
      return;
    }
    unawaited(_emit());
  }

  /// Runs [body] while holding back intermediate [schedule] calls;
  /// fires a single emission after [body] completes if anything inside
  /// it would have emitted.
  ///
  /// Only the OUTERMOST caller owns the dirty flag. A nested
  /// [holdDuring] (enqueueBatch from inside an outer batch, for
  /// example) must not clear a dirty bit the outer batch already set,
  /// or the outer finalizer would skip its post-commit emission.
  /// The deferred emission fires after [body] returns — outside any
  /// transaction zone the body opened — so the stats scan uses the
  /// root executor, not a now-closed transaction executor.
  Future<T> holdDuring<T>(Future<T> Function() body) async {
    final isOutermost = _holdDepth == 0;
    _holdDepth++;
    if (isOutermost) {
      _holdDirty = false;
    }
    try {
      return await body();
    } finally {
      _holdDepth--;
      if (isOutermost && _holdDirty) {
        _holdDirty = false;
        unawaited(_emit());
      }
    }
  }

  Future<void> _emit() async {
    // Coalesce rapid successive calls so only one stats() scan is in
    // flight at a time; callers that arrive during the scan simply flip
    // the "rerun" flag so the final state is eventually emitted.
    if (_depthCtl.isClosed) return;
    if (_emitInFlight) {
      _emitPendingRerun = true;
      return;
    }
    _emitInFlight = true;
    try {
      do {
        _emitPendingRerun = false;
        QueueStats snapshot;
        try {
          snapshot = await _loadStats();
        } catch (_) {
          // The stats call issues multiple aggregate queries; if
          // dispose() closes the controller (and the test tears down
          // the DB) during one of those async gaps, drift throws.
          // Swallow here because the emission is strictly diagnostic.
          if (_depthCtl.isClosed) return;
          rethrow;
        }
        // Re-check after the async gap — dispose() may have closed the
        // controller while we were computing stats (common in test
        // teardown, where the assertion completes before the fire-and-
        // forget emit that was kicked off from enqueue/commit).
        if (_depthCtl.isClosed) return;
        _depthCtl.add(
          QueueDepthSignal(
            total: snapshot.total,
            byProducer: snapshot.byProducer,
            oldestEnqueuedAt: snapshot.oldestEnqueuedAt,
            abandoned: snapshot.abandoned,
          ),
        );
      } while (_emitPendingRerun && !_depthCtl.isClosed);
    } finally {
      _emitInFlight = false;
    }
  }
}
