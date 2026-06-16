import 'dart:async';

import 'package:clock/clock.dart';

import 'package:lotti/features/user_activity/state/user_activity_service.dart';

/// Turns the raw activity stream from [UserActivityService] into a binary
/// "is it safe to run background work right now?" gate.
///
/// [canProcess] is `true` once no activity has happened for [idleThreshold]
/// (default 1s) and `false` while the user is actively interacting; each
/// activity event flips it to `false` and restarts the idle timer. Background
/// callers `await` [waitUntilIdle] so chatty/heavy work (sync send, inbound
/// apply) yields to live user input. The initial state is computed from
/// `lastActivity`, and `clock.now()` is used throughout so `fakeAsync` /
/// `withClock` fully control the idle computation in tests.
class UserActivityGate {
  UserActivityGate({
    required this._activityService,
    this.idleThreshold = const Duration(seconds: 1),
  }) : _controller = StreamController<bool>.broadcast() {
    // clock.now() so fakeAsync/withClock control the idle computation.
    final elapsed = clock.now().difference(_activityService.lastActivity);
    final isIdle = elapsed >= idleThreshold;
    _canProcess = isIdle;
    _controller.add(_canProcess);

    if (!isIdle) {
      _scheduleTimer(idleThreshold - elapsed);
    }

    _activitySubscription = _activityService.activityStream.listen(
      _handleActivity,
    );
  }

  final UserActivityService _activityService;
  final Duration idleThreshold;
  final StreamController<bool> _controller;
  StreamSubscription<DateTime>? _activitySubscription;
  Timer? _idleTimer;
  late bool _canProcess;

  bool get canProcess => _canProcess;

  Stream<bool> get canProcessStream => _controller.stream.distinct();

  Future<void> waitUntilIdle() async {
    if (_canProcess) {
      return;
    }
    await canProcessStream.firstWhere((value) => value);
  }

  void _handleActivity(DateTime _) {
    _setCanProcess(false);
    _scheduleTimer(idleThreshold);
  }

  void _scheduleTimer(Duration duration) {
    _idleTimer?.cancel();
    if (duration.isNegative || duration == Duration.zero) {
      _setCanProcess(true);
      return;
    }
    _idleTimer = Timer(duration, () {
      _setCanProcess(true);
    });
  }

  void _setCanProcess(bool value) {
    if (_canProcess == value) {
      return;
    }
    _canProcess = value;
    if (!_controller.isClosed) {
      _controller.add(_canProcess);
    }
  }

  Future<void> dispose() async {
    _idleTimer?.cancel();
    await _activitySubscription?.cancel();
    await _controller.close();
  }
}
