import 'dart:async';

import 'package:lotti/features/user_activity/state/user_activity_service.dart';

class UserActivityGate {
  UserActivityGate({
    required UserActivityService activityService,
    this.idleThreshold = const Duration(seconds: 1),
  })  : _activityService = activityService,
        _controller = StreamController<bool>.broadcast() {
    final elapsed = DateTime.now().difference(_activityService.lastActivity);
    final isIdle = elapsed >= idleThreshold;
    _canProcess = isIdle;
    _controller.add(_canProcess);

    if (!isIdle) {
      _scheduleTimer(idleThreshold - elapsed);
    }

    _activitySubscription =
        _activityService.activityStream.listen(_handleActivity);
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
    // Time-bounded wait to avoid indefinite starvation when the user remains
    // continuously active. After the deadline, proceed once and let callers
    // re-check idleness on the next iteration.
    const maxWaitForProgress = Duration(seconds: 2);
    final completer = Completer<void>();
    late StreamSubscription<bool> sub;
    Timer? hardDeadline;
    void complete() {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }

    sub = canProcessStream.listen((value) {
      if (value) {
        hardDeadline?.cancel();
        unawaited(sub.cancel());
        complete();
      }
    });
    hardDeadline = Timer(maxWaitForProgress, () async {
      await sub.cancel();
      complete();
    });
    await completer.future;
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
