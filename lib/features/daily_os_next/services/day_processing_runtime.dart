import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:lotti/utils/network_reachability.dart';

typedef DayProcessingDrain = Future<int> Function();
typedef DayProcessingSchedule =
    void Function(Duration delay, void Function() callback);

/// Long-lived cooperative runner that nudges the processing outbox at startup,
/// after local mutations, and when connectivity returns.
class DayProcessingRuntime {
  DayProcessingRuntime({
    required this.repository,
    required this.drain,
    this.connectivityChanges,
    this.prune,
    this.repair,
    this.onRepairFailed,
    this.networkProbeInterval = const Duration(minutes: 1),
    this.failureRetryDelay = const Duration(seconds: 30),
    DateTime Function()? now,
    DayProcessingSchedule? schedule,
  }) : _now = now ?? DateTime.now,
       _schedule = schedule ?? _defaultSchedule;

  final DayProcessingOutboxRepository repository;
  final DayProcessingDrain drain;
  final Stream<List<ConnectivityResult>>? connectivityChanges;
  final DateTime Function() _now;
  final DayProcessingSchedule _schedule;
  final Future<int> Function()? repair;

  /// Once-per-start retention pass. Retried until it succeeds, then never
  /// again for this runtime — a failing [repair] does not repeat it.
  final Future<void> Function()? prune;

  /// Told about each failed [prune] or [repair] attempt; the runtime itself
  /// only retries.
  final void Function(Object error, StackTrace stackTrace)? onRepairFailed;
  final Duration networkProbeInterval;
  final Duration failureRetryDelay;

  StreamSubscription<void>? _outboxSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Future<void>? _nudgeFuture;
  bool _followUpNudgeRequested = false;
  int _scheduleGeneration = 0;
  bool _started = false;
  bool _disposed = false;
  bool _repairComplete = false;
  bool _pruneComplete = false;

  void start() {
    if (_disposed || _started) return;
    _started = true;
    _subscribeToOutboxChanges();
    final connectivity =
        connectivityChanges ?? Connectivity().onConnectivityChanged;
    _connectivitySubscription = connectivity.listen(
      (results) {
        if (reachesNetwork(results)) {
          unawaited(handleConnectivityRestored());
        }
      },
      // On Linux without NetworkManager the platform stream errors as soon as
      // it is listened to. The periodic network probe still re-checks waiting
      // jobs, so the error only means this trigger is unavailable.
      onError: (Object _) {},
    );
    unawaited(nudge());
  }

  void _subscribeToOutboxChanges() {
    if (_disposed || !_started || _outboxSubscription != null) return;
    _outboxSubscription = repository.changes.listen((_) {
      if (_nudgeFuture != null) {
        // The subscription is paused while the drain owns repository
        // mutations, so a signal observed here came after that mutation phase
        // and may have landed after its due-queue read.
        _followUpNudgeRequested = true;
      }
      unawaited(nudge());
    });
  }

  Future<void> handleConnectivityRestored() async {
    try {
      await repository.signalConnectivityRestored();
      await nudge();
    } catch (_) {
      _scheduleNext(failureRetryDelay);
    }
  }

  Future<void> nudge() {
    if (_disposed) return Future<void>.value();
    final inFlight = _nudgeFuture;
    if (inFlight != null) return inFlight;
    final future = drainAndSchedule();
    _nudgeFuture = future;
    return future.whenComplete(() {
      if (identical(_nudgeFuture, future)) _nudgeFuture = null;
      if (_followUpNudgeRequested && !_disposed) {
        _followUpNudgeRequested = false;
        unawaited(nudge());
      }
    });
  }

  Future<void> drainAndSchedule() async {
    final wasListening = _outboxSubscription != null;
    try {
      // Claiming and terminalizing jobs publish repository changes of their
      // own. They cannot represent new work, and treating them as external
      // nudges causes a redundant full drain after every successful pass.
      // Pause only for the runtime-owned mutation phase, then resubscribe
      // before inspecting due work so external writes cannot be lost.
      if (wasListening) {
        await _outboxSubscription?.cancel();
        _outboxSubscription = null;
      }
      if (!_pruneComplete) {
        try {
          await prune?.call();
          _pruneComplete = true;
        } catch (error, stackTrace) {
          onRepairFailed?.call(error, stackTrace);
        }
      }
      if (!_repairComplete) {
        try {
          await repair?.call();
          _repairComplete = true;
        } catch (error, stackTrace) {
          // Repair rebuilds lost transcription intents; it is not a gate.
          // A repair that failed on every pass used to stop the drain from
          // ever running, leaving every parse and draft queued forever. It
          // is retried on the next pass instead — scheduled below even when
          // the outbox is empty.
          onRepairFailed?.call(error, stackTrace);
        }
      }
      await drain();
      if (wasListening) _subscribeToOutboxChanges();
      final now = _now();
      // Only rows that can still be scheduled, bounded by outstanding work
      // rather than install age (ADR 0044). The effective-due ordering stays
      // here rather than in SQL because it depends on this runtime's own
      // [networkProbeInterval], and the rule should have one implementation.
      final jobs = (await repository.getSchedulable()).toList()
        ..sort((a, b) => _effectiveDue(a).compareTo(_effectiveDue(b)));
      // A pending repair needs a pass of its own: nothing else wakes the
      // runtime when the outbox is empty. An earlier job deadline or network
      // probe still wins — that pass retries the repair first anyway.
      final repairRetry = _repairComplete && _pruneComplete
          ? null
          : failureRetryDelay;
      if (jobs.isEmpty) {
        if (repairRetry != null) {
          _scheduleNext(repairRetry);
        } else {
          _scheduleGeneration += 1;
        }
        return;
      }
      final next = jobs.first;
      final due = _effectiveDue(next);
      final delay = due.isAfter(now) ? due.difference(now) : Duration.zero;
      if (repairRetry != null && repairRetry < delay) {
        _scheduleNext(repairRetry);
        return;
      }
      _scheduleNext(
        delay,
        probeNetwork: next.status == DayProcessingJobStatus.waitingForNetwork,
      );
    } catch (_) {
      if (wasListening) _subscribeToOutboxChanges();
      // A startup repair, filesystem read, or processor failure must not escape
      // an unawaited app-start nudge and permanently stop the runtime.
      _scheduleNext(failureRetryDelay);
    }
  }

  DateTime _effectiveDue(DayProcessingJob job) {
    final retryBoundary = job.retryNotBefore;
    var due = job.status == DayProcessingJobStatus.running
        ? job.leaseUntil ?? job.nextAttemptAt
        : job.status == DayProcessingJobStatus.waitingForNetwork
        ? job.updatedAt.add(networkProbeInterval)
        : job.nextAttemptAt;
    if (retryBoundary != null && retryBoundary.isAfter(due)) {
      due = retryBoundary;
    }
    return due;
  }

  void _scheduleNext(Duration delay, {bool probeNetwork = false}) {
    final generation = ++_scheduleGeneration;
    _schedule(delay, () {
      if (_disposed || generation != _scheduleGeneration) return;
      if (probeNetwork) {
        unawaited(handleConnectivityRestored());
      } else {
        unawaited(nudge());
      }
    });
  }

  Future<void> dispose() async {
    _disposed = true;
    _started = false;
    _followUpNudgeRequested = false;
    _scheduleGeneration += 1;
    await _outboxSubscription?.cancel();
    await _connectivitySubscription?.cancel();
  }

  // Unit tests inject a deterministic scheduler; this is the platform timer
  // adapter used only by the long-lived application runtime.
  // coverage:ignore-start
  static void _defaultSchedule(Duration delay, void Function() callback) {
    Timer(delay, callback);
  }

  // coverage:ignore-end
}
