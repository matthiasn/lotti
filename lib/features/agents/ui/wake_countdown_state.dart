import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Drives a one-second countdown towards [nextWakeAt] for a stateful
/// widget while honoring the ambient [TickerMode]. When the enclosing
/// subtree's tickers are disabled (e.g. an inactive `IndexedStack`
/// child) the periodic timer is cancelled outright so the widget
/// stops contributing to idle CPU. Re-enabling the ticker resyncs
/// the seconds against wall-clock and restarts the timer.
mixin WakeCountdownState<T extends StatefulWidget> on State<T> {
  Timer? _timer;
  int _seconds = 0;
  ValueListenable<TickerModeData>? _tickerModeNotifier;
  bool _tickerModeEnabled = true;
  bool _expiredNotified = false;

  /// The wall-clock target the countdown is counting down to.
  DateTime get nextWakeAt;

  /// Number of remaining seconds — read this from `build()`.
  int get countdownSeconds => _seconds;

  /// Override to be notified once when the countdown reaches zero.
  /// Invoked post-frame so callers can trigger rebuilds without
  /// colliding with the active build phase.
  void onCountdownExpired() {}

  /// Subclasses must call this from their `didUpdateWidget` whenever
  /// [nextWakeAt] could have changed.
  void resyncCountdown() {
    _seconds = _remainingSeconds();
    if (_seconds > 0) {
      _expiredNotified = false;
    }
    _syncTimer();
  }

  @override
  void initState() {
    super.initState();
    _seconds = _remainingSeconds();
    _syncTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tickerModeNotifier = TickerMode.getValuesNotifier(context);
    if (_tickerModeNotifier != tickerModeNotifier) {
      _tickerModeNotifier?.removeListener(_handleTickerModeChanged);
      _tickerModeNotifier = tickerModeNotifier
        ..addListener(_handleTickerModeChanged);
    }
    _syncTickerMode();
  }

  @override
  void dispose() {
    _tickerModeNotifier?.removeListener(_handleTickerModeChanged);
    _timer?.cancel();
    super.dispose();
  }

  int _remainingSeconds() {
    final remaining = nextWakeAt.difference(clock.now());
    if (remaining <= Duration.zero) {
      return 0;
    }
    return remaining.inSeconds;
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;

    if (_seconds <= 0) {
      _scheduleExpiredCallback();
      return;
    }
    if (!_tickerModeEnabled) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final updated = _remainingSeconds();
      if (updated == _seconds) {
        return;
      }

      setState(() => _seconds = updated);
      if (updated <= 0) {
        timer.cancel();
        _timer = null;
        _scheduleExpiredCallback();
      }
    });
  }

  void _handleTickerModeChanged() {
    if (!mounted) {
      return;
    }
    setState(_syncTickerMode);
  }

  void _syncTickerMode() {
    _tickerModeEnabled =
        _tickerModeNotifier?.value.enabled ?? TickerModeData.fallback.enabled;
    if (!_tickerModeEnabled) {
      _timer?.cancel();
      _timer = null;
      return;
    }

    final updated = _remainingSeconds();
    if (updated != _seconds) {
      _seconds = updated;
    }
    _syncTimer();
  }

  void _scheduleExpiredCallback() {
    if (_expiredNotified) {
      return;
    }
    _expiredNotified = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        onCountdownExpired();
      }
    });
  }
}
