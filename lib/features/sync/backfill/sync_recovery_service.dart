import 'dart:async';

import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/services/domain_logging.dart';

/// Retries durable sync recovery work without requiring another app launch.
///
/// Each pass must inspect durable state and tolerate repetition. Passes never
/// overlap, and shutdown waits for the active pass before its stores close.
class SyncRecoveryService {
  SyncRecoveryService({
    required this._recover,
    required this._logging,
    this._interval = SyncTuning.backfillRequestInterval,
  });

  final Future<void> Function() _recover;
  final DomainLogger _logging;
  final Duration _interval;
  Timer? _timer;
  Future<void>? _running;
  bool _disposed = false;

  /// Starts periodic recovery and returns the first pass for startup tracking.
  /// Repeated starts share an active pass and do not create extra timers.
  Future<void> start() {
    if (_disposed) return Future<void>.value();
    _timer ??= Timer.periodic(_interval, (_) => unawaited(_run()));
    return _run();
  }

  Future<void> _run() {
    if (_disposed) return Future<void>.value();
    // Future.sync also captures callbacks that throw before returning a Future.
    // Its continuations run after _running is assigned, so even those failures
    // clear the flight and allow the next timer tick to retry.
    return _running ??= Future<void>.sync(_recover)
        .catchError((Object error, StackTrace stackTrace) {
          _logging.error(
            LogDomain.sync,
            error,
            stackTrace: stackTrace,
            subDomain: 'sync.recovery',
          );
        })
        .whenComplete(() => _running = null);
  }

  /// Stops new passes and drains the current one before database disposal.
  Future<void> dispose() async {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    await _running;
  }
}
