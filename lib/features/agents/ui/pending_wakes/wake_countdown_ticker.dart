import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Page-scoped 1Hz tick. Emits a monotonically increasing `DateTime`
/// (from `clock.now()`) every second so per-row countdowns can derive
/// "seconds remaining" from `dueAt - tick` without each row spawning
/// its own `Timer`. With ~1K rows this collapses N timers down to
/// one, and lets each row use `ref.watch(... .select((tick) =>
/// secondsRemaining))` to skip rebuilds when the visible countdown
/// hasn't changed.
///
/// `autoDispose` so the timer stops as soon as the Pending Wakes page
/// leaves the tree (other tabs in the IndexedStack stay mounted, so
/// `keepAlive` is intentionally NOT used — we only want the tick when
/// the body is being looked at).
final StreamProvider<DateTime> wakeCountdownTickerProvider =
    StreamProvider.autoDispose<DateTime>((ref) {
      final controller = StreamController<DateTime>()..add(clock.now());
      // Seed once above so first-build subscribers don't have to wait
      // a full second for an initial value.
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        controller.add(clock.now());
      });
      ref.onDispose(() {
        timer.cancel();
        controller.close();
      });
      return controller.stream;
    });

/// Format `dueAt - now` as a zero-padded countdown. Below one hour the
/// hour cell is dropped and the result reads `MM:SS`; once we cross
/// the hour line the hour cell is added back as `HH:MM:SS`. The
/// minute and second cells stay two-digit zero-padded so the visible
/// width stays constant from one tick to the next within a band —
/// combined with `FontFeature.tabularFigures()` at the call site, the
/// label doesn't "breathe" as the seconds digit changes glyph width.
/// Returns `'00:00'` when overdue. Hours are clamped to two digits
/// (anything ≥ 100h shows as `99:59:59`); the wake throttle window
/// is much smaller than that in practice.
String formatWakeCountdown(DateTime dueAt, DateTime now) {
  final remaining = dueAt.difference(now);
  if (remaining <= Duration.zero) return '00:00';

  final totalSeconds = remaining.inSeconds;
  final clamped = totalSeconds > 99 * 3600 + 59 * 60 + 59
      ? 99 * 3600 + 59 * 60 + 59
      : totalSeconds;
  final hours = clamped ~/ 3600;
  final minutes = (clamped % 3600) ~/ 60;
  final seconds = clamped % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  if (hours == 0) return '$mm:$ss';
  final hh = hours.toString().padLeft(2, '0');
  return '$hh:$mm:$ss';
}
