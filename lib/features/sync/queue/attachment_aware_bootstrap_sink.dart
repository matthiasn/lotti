import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:lotti/features/sync/queue/bootstrap_sink.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:matrix/matrix.dart';

/// Bootstrap sink wrapper that funnels each plaintext paginated event through
/// the coordinator's attachment ingestor before forwarding to the inner sink.
/// This is the catch-up equivalent of the live-stream `_handleLiveEvent`
/// hook: every attachment descriptor observed during
/// `collectHistoryForBootstrap` is recorded + downloaded so the companion
/// sync-payload events that the inner sink enqueues have their JSON on disk
/// by the time the worker applies them.
///
/// Encrypted page events are not useful to attachment ingestion and are
/// skipped here. When the inner [QueueBootstrapSink] successfully re-decrypts
/// one, its `onDecryptedEvent` callback must call [addDecryptedEvent] so the
/// resulting plaintext enters this same bounded worker pool before queue
/// classification.
///
/// Attachment processing is fire-and-forget relative to pagination — the
/// inner sink's return value flows through unchanged and the caller is not
/// delayed by attachment ingestion. *Within* the sink, however, attachment
/// work is bounded: incoming events are pushed onto an internal FIFO that a
/// small pool of long-running workers drains, rather than firing
/// `unawaited(processAttachment(event))` for every event on the page. The
/// latter ran 200 async bodies up to their first await synchronously on the
/// main isolate before yielding, and on slow disks (Parallels-backed Linux)
/// manifested as visible UI stalls during catch-up.
///
/// Workers are started lazily and re-use permits across pages, so a
/// sustained burst does not overflow `kBootstrapAttachmentConcurrency` even
/// if pages arrive faster than individual attachments complete.
class AttachmentAwareBootstrapSink implements BootstrapSink {
  AttachmentAwareBootstrapSink({
    required this._inner,
    required this._processAttachment,
    int concurrency = SyncTuning.bootstrapAttachmentConcurrency,
  }) : _concurrency = concurrency < 1 ? 1 : concurrency;

  final BootstrapSink _inner;
  final Future<void> Function(Event event) _processAttachment;
  final int _concurrency;

  final Queue<Event> _pending = Queue<Event>();
  final Set<Future<void>> _workers = <Future<void>>{};

  @override
  int? get lastAcceptedCount => _inner.lastAcceptedCount;

  @override
  Future<bool> onPage(List<Event> events, BootstrapPageInfo info) async {
    for (final event in events) {
      if (event.type != EventTypes.Encrypted) {
        _add(event);
      }
    }
    return _inner.onPage(events, info);
  }

  /// Adds plaintext revealed by the inner sink's fresh decryption attempt.
  ///
  /// This is synchronous by design: the event is queued before the inner sink
  /// classifies it, while the actual download remains asynchronous and bounded
  /// by [_concurrency].
  void addDecryptedEvent(Event event) {
    assert(event.type != EventTypes.Encrypted, 'expected plaintext event');
    _add(event);
  }

  void _add(Event event) {
    _pending.add(event);
    _ensureWorkers();
  }

  void _ensureWorkers() {
    while (_workers.length < _concurrency && _pending.isNotEmpty) {
      final done = Completer<void>();
      _workers.add(done.future);
      unawaited(_runWorker(done));
    }
  }

  /// Drains [_pending], then leaves [_workers] in the same synchronous step
  /// that found the queue empty. So whenever [_pending] holds an event, at
  /// least one worker is registered to take it — the invariant [drain]
  /// relies on.
  Future<void> _runWorker(Completer<void> done) async {
    while (_pending.isNotEmpty) {
      final event = _pending.removeFirst();
      try {
        await _processAttachment(event);
      } catch (_) {
        // `_processAttachment` already logs via the coordinator's logger
        // (see `queue_pipeline_coordinator._processAttachment`). Swallow
        // here so one bad event can't stop the worker from draining the
        // rest of the page.
      }
    }
    _workers.remove(done.future);
    done.complete();
  }

  /// Awaits all currently-running and queued attachment work. Intended for
  /// coordinator shutdown paths so the ingestor isn't disposed mid-write,
  /// and for tests that need a synchronisation point.
  ///
  /// Safe to call even when nothing is in flight (returns immediately).
  Future<void> drain() async {
    // Queued events always have a registered worker (see [_runWorker]), so
    // waiting until no worker is left also means the queue is empty. Loop
    // because events added while waiting may start new workers.
    while (_workers.isNotEmpty) {
      await Future.wait(_workers.toList());
    }
  }

  @visibleForTesting
  int get inFlightWorkerCount => _workers.length;

  @visibleForTesting
  int get pendingCount => _pending.length;
}
