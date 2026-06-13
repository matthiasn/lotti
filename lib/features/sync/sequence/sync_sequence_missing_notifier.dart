import 'package:lotti/features/sync/sequence/sync_sequence_tracer.dart';

/// Owns the "missing entries detected" notification state for the sync
/// sequence log.
///
/// Gap detection on the receive path may discover newly missing counters; the
/// owner of this notifier signals that via [emitMissingEntriesDetected]. The
/// automatic backfill nudge can be deferred across an ordered replay batch
/// using [runWithDeferredMissingEntries] so transient in-burst holes do not
/// trigger redundant repair chatter — the callback fires once when the
/// outermost deferred scope unwinds.
///
/// This is the single owner of the mutable depth/pending flags so the receive
/// collaborator and the facade observe the same notification state.
class SyncSequenceMissingNotifier {
  SyncSequenceMissingNotifier({required this._tracer});

  final SyncSequenceTracer _tracer;

  /// Invoked when new missing entries are detected (and not currently
  /// deferred). The owner wires the automatic backfill nudge here.
  void Function()? onMissingEntriesDetected;

  int _deferredDepth = 0;
  bool _pending = false;

  /// Whether emission is currently deferred (inside a
  /// [runWithDeferredMissingEntries] scope).
  bool get isDeferred => _deferredDepth > 0;

  /// Run [action] with missing-entries emission deferred. If new missing
  /// entries are flagged via [flagMissingEntriesDetected] while deferred, the
  /// callback fires exactly once when the outermost scope unwinds.
  Future<T> runWithDeferredMissingEntries<T>(
    Future<T> Function() action,
  ) async {
    _deferredDepth++;
    try {
      return await action();
    } finally {
      _deferredDepth--;
      if (_deferredDepth == 0 && _pending) {
        _pending = false;
        emitMissingEntriesDetected();
      }
    }
  }

  /// Record that new missing entries were detected. Defers the nudge when
  /// inside a deferred scope, otherwise emits immediately.
  void flagMissingEntriesDetected() {
    if (isDeferred) {
      _pending = true;
    } else {
      emitMissingEntriesDetected();
    }
  }

  /// Invoke [onMissingEntriesDetected], swallowing and logging any exception
  /// it throws so a faulty listener cannot break the receive path.
  void emitMissingEntriesDetected() {
    final callback = onMissingEntriesDetected;
    if (callback == null) return;
    try {
      callback();
    } catch (e, st) {
      _tracer.error(e, st, subDomain: 'missingEntriesDetected');
    }
  }
}
