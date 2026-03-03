import 'dart:async';

import 'package:lotti/database/sync_db.dart';
import 'package:lotti/services/domain_logging.dart';

/// Periodic health summary for the sync pipeline.
///
/// When sync domain logging is enabled, emits a compact health line every
/// interval (default 5 minutes) with outbox and sequence log counts.
class SyncHealthReporter {
  SyncHealthReporter({
    required SyncDatabase syncDatabase,
    required DomainLogger domainLogger,
    Duration interval = const Duration(minutes: 5),
  })  : _syncDatabase = syncDatabase,
        _domainLogger = domainLogger,
        _interval = interval;

  final SyncDatabase _syncDatabase;
  final DomainLogger _domainLogger;
  final Duration _interval;
  Timer? _timer;
  bool _isDisposed = false;

  /// Start the periodic health reporting timer.
  void start() {
    if (_isDisposed) return;
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _reportHealth());
  }

  Future<void> _reportHealth() async {
    if (_isDisposed) return;
    if (!_domainLogger.enabledDomains.contains(LogDomains.sync)) return;

    try {
      final results = await Future.wait([
        _syncDatabase.getPendingOutboxCount(),
        _syncDatabase.getMissingSequenceCount(),
        _syncDatabase.getRequestedSequenceCount(),
        _syncDatabase.getSentCountSince(DateTime.now().subtract(_interval)),
      ]);

      final pendingOutbox = results[0];
      final missingEntries = results[1];
      final requestedEntries = results[2];
      final sentRecent = results[3];

      _domainLogger.log(
        LogDomains.sync,
        'health: outbox.pending=$pendingOutbox '
        'outbox.sentRecent=$sentRecent '
        'seq.missing=$missingEntries '
        'seq.requested=$requestedEntries',
        subDomain: 'health',
      );
    } catch (e, st) {
      _domainLogger.error(
        LogDomains.sync,
        'health report failed',
        error: e,
        stackTrace: st,
        subDomain: 'health',
      );
    }
  }

  /// Dispose of the reporter and cancel the timer.
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _timer = null;
  }
}
