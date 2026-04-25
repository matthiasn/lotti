import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:matrix/matrix.dart';

/// Bootstrap sink wrapper that funnels each paginated event through the
/// coordinator's attachment ingestor *before* forwarding to the inner sink.
/// This is the catch-up equivalent of the live-stream `_handleLiveEvent`
/// hook: every attachment descriptor observed during
/// `collectHistoryForBootstrap` is recorded + downloaded so the companion
/// sync-payload events that the inner sink enqueues have their JSON on disk
/// by the time the worker applies them.
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
    required BootstrapSink inner,
    required Future<void> Function(Event event) processAttachment,
    int concurrency = SyncTuning.bootstrapAttachmentConcurrency,
  }) : _inner = inner,
       _processAttachment = processAttachment,
       _concurrency = concurrency < 1 ? 1 : concurrency;

  final BootstrapSink _inner;
  final Future<void> Function(Event event) _processAttachment;
  final int _concurrency;

  final Queue<Event> _pending = Queue<Event>();
  final Set<Future<void>> _workers = <Future<void>>{};

  @override
  int? get lastAcceptedCount => _inner.lastAcceptedCount;

  @override
  Future<bool> onPage(List<Event> events, BootstrapPageInfo info) async {
    // Enqueue the page and make sure we have workers draining it. Do this
    // before delegating to the inner sink so attachment work for page N
    // can overlap with the inner sink's work on page N and the network
    // fetch for page N+1.
    _pending.addAll(events);
    _ensureWorkers();
    return _inner.onPage(events, info);
  }

  void _ensureWorkers() {
    while (_workers.length < _concurrency && _pending.isNotEmpty) {
      late Future<void> worker;
      worker = _runWorker().whenComplete(() => _workers.remove(worker));
      _workers.add(worker);
    }
  }

  Future<void> _runWorker() async {
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
  }

  /// Awaits all currently-running and queued attachment work. Intended for
  /// coordinator shutdown paths so the ingestor isn't disposed mid-write,
  /// and for tests that need a synchronisation point.
  ///
  /// Safe to call even when nothing is in flight (returns immediately).
  Future<void> drain() async {
    // Snapshot-and-wait until both the pending queue has been drained and
    // every worker has exited. A single pass of `Future.wait(_workers)` is
    // not enough because a worker can finish and the next call to
    // `_ensureWorkers` is empty-handed only if `_pending` is also empty.
    while (_pending.isNotEmpty || _workers.isNotEmpty) {
      if (_workers.isEmpty) {
        _ensureWorkers();
      }
      if (_workers.isEmpty) return;
      await Future.wait(_workers.toList());
    }
  }

  @visibleForTesting
  int get inFlightWorkerCount => _workers.length;

  @visibleForTesting
  int get pendingCount => _pending.length;
}
