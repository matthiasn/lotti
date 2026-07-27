import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';

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
    this.repair,
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

  void start() {
    if (_disposed || _started) return;
    _started = true;
    _subscribeToOutboxChanges();
    final connectivity =
        connectivityChanges ?? Connectivity().onConnectivityChanged;
    _connectivitySubscription = connectivity.listen((results) {
      final connected = results.any(_isConnected);
      if (connected) unawaited(handleConnectivityRestored());
    });
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
      if (!_repairComplete) {
        await repair?.call();
        _repairComplete = true;
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
      if (jobs.isEmpty) {
        _scheduleGeneration += 1;
        return;
      }
      final next = jobs.first;
      final due = _effectiveDue(next);
      final delay = due.isAfter(now) ? due.difference(now) : Duration.zero;
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

  static bool _isConnected(ConnectivityResult result) => switch (result) {
    ConnectivityResult.wifi ||
    ConnectivityResult.mobile ||
    ConnectivityResult.ethernet ||
    ConnectivityResult.vpn => true,
    _ => false,
  };

  // Unit tests inject a deterministic scheduler; this is the platform timer
  // adapter used only by the long-lived application runtime.
  // coverage:ignore-start
  static void _defaultSchedule(Duration delay, void Function() callback) {
    Timer(delay, callback);
  }

  // coverage:ignore-end
}
