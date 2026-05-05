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

/// Format `dueAt - now` as a compact countdown — `1h 02m 05s`,
/// `2m 5s`, or `5s`. Returns `'0s'` when overdue. Same shape the
/// legacy `_PendingWakeCard` rendered.
String formatWakeCountdown(DateTime dueAt, DateTime now) {
  final remaining = dueAt.difference(now);
  if (remaining <= Duration.zero) return '0s';

  final totalSeconds = remaining.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final parts = <String>[];
  if (hours > 0) parts.add('${hours}h');
  if (minutes > 0 || hours > 0) parts.add('${minutes}m');
  parts.add('${seconds}s');
  return parts.join(' ');
}
