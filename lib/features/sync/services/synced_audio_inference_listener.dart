import 'dart:async';

import 'package:lotti/features/sync/services/synced_audio_inference_dispatcher.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';

/// Subscribes to [UpdateNotifications.syncUpdateStream] (sync-only — never
/// the general `updateStream`, which carries local + UI-only emissions) and
/// hands every id in each batch to [SyncedAudioInferenceDispatcher].
///
/// The notifications stream already batches `fromSync: true` calls inside
/// its own 1s window, so the listener does **not** add a second debounce —
/// it just unfolds the batch into one dispatcher call per id. Dispatcher
/// calls are sequenced (not parallel) so the per-entity log lines stay
/// monotonic and the writer transaction inside `runTranscription` doesn't
/// contend with itself.
class SyncedAudioInferenceListener {
  SyncedAudioInferenceListener({
    required UpdateNotifications updateNotifications,
    required SyncedAudioInferenceDispatcher dispatcher,
    DomainLogger? domainLogger,
  }) : _updateNotifications = updateNotifications,
       _dispatcher = dispatcher,
       _domainLogger = domainLogger;

  final UpdateNotifications _updateNotifications;
  final SyncedAudioInferenceDispatcher _dispatcher;
  final DomainLogger? _domainLogger;

  StreamSubscription<void>? _subscription;

  /// Starts the listener. Idempotent — a second call is a no-op.
  void start() {
    if (_subscription != null) return;
    // `Stream.listen` does NOT await an async onData callback, so two batches
    // arriving back-to-back would execute `_onBatch` concurrently and break
    // the documented sequential-dispatch contract — and overlap inside
    // `runTranscription`'s journal-writer transaction. `asyncMap` serializes
    // the chain by holding the next event until the prior future completes.
    _subscription = _updateNotifications.syncUpdateStream
        .asyncMap(_onBatch)
        .listen(
          (_) {},
          onError: (Object error, StackTrace stackTrace) {
            _domainLogger?.error(
              LogDomains.sync,
              'syncUpdateStream emitted an error',
              error: error,
              stackTrace: stackTrace,
              subDomain: 'syncedAudioInferenceListener',
            );
          },
        );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  Future<void> _onBatch(Set<String> ids) async {
    for (final id in ids) {
      // Run sequentially: keeps per-id log lines ordered, avoids contending
      // for the journal writer transaction inside runTranscription, and
      // matches the cadence of UpdateNotifications' own 1s batching window.
      await _dispatcher.maybeDispatch(id);
    }
  }
}
