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
  int _scheduleGeneration = 0;
  bool _disposed = false;
  bool _repairComplete = false;

  void start() {
    if (_disposed || _outboxSubscription != null) return;
    _outboxSubscription = repository.changes.listen((_) => nudge());
    final connectivity =
        connectivityChanges ?? Connectivity().onConnectivityChanged;
    _connectivitySubscription = connectivity.listen((results) {
      final connected = results.any(_isConnected);
      if (connected) unawaited(handleConnectivityRestored());
    });
    unawaited(nudge());
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
    });
  }

  Future<void> drainAndSchedule() async {
    try {
      if (!_repairComplete) {
        await repair?.call();
        _repairComplete = true;
      }
      await drain();
      final now = _now();
      final jobs = (await repository.getAll()).where(_canSchedule).toList()
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
      // A startup repair, filesystem read, or processor failure must not escape
      // an unawaited app-start nudge and permanently stop the runtime.
      _scheduleNext(failureRetryDelay);
    }
  }

  bool _canSchedule(DayProcessingJob job) => switch (job.status) {
    DayProcessingJobStatus.queued ||
    DayProcessingJobStatus.running ||
    DayProcessingJobStatus.waitingForNetwork => true,
    _ => false,
  };

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

  static void _defaultSchedule(Duration delay, void Function() callback) {
    Timer(delay, callback);
  }
}
