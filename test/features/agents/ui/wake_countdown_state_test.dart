import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/wake_countdown_state.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('WakeCountdownState', () {
    Widget wrap(Widget child, {bool tickerModeEnabled = true}) {
      return makeTestableWidget2(
        Scaffold(
          body: TickerMode(
            enabled: tickerModeEnabled,
            child: child,
          ),
        ),
      );
    }

    testWidgets('renders initial countdown seconds based on clock', (
      tester,
    ) async {
      final start = DateTime(2024, 3, 15, 12);
      final nextWakeAt = start.add(const Duration(seconds: 90));

      await withClock(Clock(() => start), () async {
        await tester.pumpWidget(wrap(_CountdownProbe(nextWakeAt: nextWakeAt)));
        await tester.pump();

        expect(find.text('90'), findsOneWidget);
      });
    });

    testWidgets('decrements every second while ticker is enabled', (
      tester,
    ) async {
      final start = DateTime(2024, 3, 15, 12);
      var now = start;
      final nextWakeAt = start.add(const Duration(seconds: 5));

      await withClock(Clock(() => now), () async {
        await tester.pumpWidget(wrap(_CountdownProbe(nextWakeAt: nextWakeAt)));
        await tester.pump();
        expect(find.text('5'), findsOneWidget);

        now = start.add(const Duration(seconds: 2));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('3'), findsOneWidget);

        now = start.add(const Duration(seconds: 4));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('1'), findsOneWidget);
      });
    });

    testWidgets(
      'freezes display while ticker mode is disabled and snaps to live '
      'remaining when re-enabled',
      (tester) async {
        final start = DateTime(2024, 3, 15, 12);
        var now = start;
        final nextWakeAt = start.add(const Duration(seconds: 60));

        await withClock(Clock(() => now), () async {
          await tester.pumpWidget(
            wrap(_CountdownProbe(nextWakeAt: nextWakeAt)),
          );
          await tester.pump();
          expect(find.text('60'), findsOneWidget);

          // Disable the ticker → mixin must cancel its periodic timer.
          // The test framework auto-asserts no pending timers leak past
          // the end of the test, which catches the previous bug where
          // the timer kept firing every second despite being gated.
          await tester.pumpWidget(
            wrap(
              _CountdownProbe(nextWakeAt: nextWakeAt),
              tickerModeEnabled: false,
            ),
          );
          await tester.pump();

          // Time passes while the ticker is off — display must stay
          // frozen because the timer body never ran.
          now = start.add(const Duration(seconds: 25));
          await tester.pump(const Duration(seconds: 1));
          expect(find.text('60'), findsOneWidget);

          // Re-enable: resync should snap to the live remaining count
          // and start the timer again.
          await tester.pumpWidget(
            wrap(_CountdownProbe(nextWakeAt: nextWakeAt)),
          );
          await tester.pump();
          expect(find.text('35'), findsOneWidget);

          // And ticking resumes from the snapped value.
          now = start.add(const Duration(seconds: 27));
          await tester.pump(const Duration(seconds: 1));
          expect(find.text('33'), findsOneWidget);
        });
      },
    );

    testWidgets('hides countdown and fires onCountdownExpired exactly once', (
      tester,
    ) async {
      final start = DateTime(2024, 3, 15, 12);
      var now = start;
      final nextWakeAt = start.add(const Duration(seconds: 2));
      var expiredCalls = 0;

      await withClock(Clock(() => now), () async {
        await tester.pumpWidget(
          wrap(
            _CountdownProbe(
              nextWakeAt: nextWakeAt,
              onExpired: () => expiredCalls++,
            ),
          ),
        );
        await tester.pump();
        expect(find.text('2'), findsOneWidget);
        expect(expiredCalls, 0);

        now = start.add(const Duration(seconds: 3));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump();

        expect(find.text('expired'), findsOneWidget);
        expect(expiredCalls, 1);

        // No further pumps should re-trigger the expiry callback because
        // the timer self-cancelled on the expiry tick.
        await tester.pump(const Duration(seconds: 1));
        expect(expiredCalls, 1);
      });
    });

    testWidgets('resyncCountdown picks up new nextWakeAt on widget update', (
      tester,
    ) async {
      final start = DateTime(2024, 3, 15, 12);
      await withClock(Clock(() => start), () async {
        await tester.pumpWidget(
          wrap(
            _CountdownProbe(
              nextWakeAt: start.add(const Duration(seconds: 10)),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('10'), findsOneWidget);

        await tester.pumpWidget(
          wrap(
            _CountdownProbe(
              nextWakeAt: start.add(const Duration(seconds: 200)),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('200'), findsOneWidget);
      });
    });

    testWidgets('matches generated ticker and nextWakeAt update scenarios', (
      tester,
    ) async {
      for (final scenario in _generatedCountdownScenarios()) {
        final start = DateTime(2024, 3, 15, 12);
        var now = start;

        DateTime targetFromOffset(int offsetSeconds) =>
            start.add(Duration(seconds: offsetSeconds));

        await withClock(Clock(() => now), () async {
          final initialTarget = targetFromOffset(
            scenario.initialOffsetSeconds,
          );

          await tester.pumpWidget(
            wrap(_CountdownProbe(nextWakeAt: initialTarget)),
          );
          await tester.pump();

          var expectedSeconds = _remainingCountdownSeconds(
            now,
            initialTarget,
          );
          _expectCountdownSeconds(
            expectedSeconds,
            reason: 'initial $scenario',
          );

          if (scenario.disableTickerBeforeElapsed) {
            await tester.pumpWidget(
              wrap(
                _CountdownProbe(nextWakeAt: initialTarget),
                tickerModeEnabled: false,
              ),
            );
            await tester.pump();

            final frozenSeconds = expectedSeconds;
            now = start.add(Duration(seconds: scenario.elapsedSeconds));
            await tester.pump(const Duration(seconds: 1));
            _expectCountdownSeconds(
              frozenSeconds,
              reason: 'disabled elapsed $scenario',
            );
          } else {
            now = start.add(Duration(seconds: scenario.elapsedSeconds));
            await tester.pump(const Duration(seconds: 1));
            expectedSeconds = _remainingCountdownSeconds(now, initialTarget);
            _expectCountdownSeconds(
              expectedSeconds,
              reason: 'enabled elapsed $scenario',
            );
          }

          final updatedTarget = targetFromOffset(
            scenario.updatedOffsetSeconds,
          );
          await tester.pumpWidget(
            wrap(_CountdownProbe(nextWakeAt: updatedTarget)),
          );
          await tester.pump();

          expectedSeconds = _remainingCountdownSeconds(now, updatedTarget);
          _expectCountdownSeconds(
            expectedSeconds,
            reason: 'updated $scenario',
          );

          if (expectedSeconds > 0) {
            now = now.add(const Duration(seconds: 1));
            await tester.pump(const Duration(seconds: 1));
            expectedSeconds = _remainingCountdownSeconds(now, updatedTarget);
            _expectCountdownSeconds(
              expectedSeconds,
              reason: 'updated tick $scenario',
            );
          }

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
        });
      }
    });

    testWidgets(
      'starts in expired state when nextWakeAt is already past and emits '
      'onCountdownExpired post-frame without scheduling a periodic timer',
      (tester) async {
        final now = DateTime(2024, 3, 15, 12);
        var expiredCalls = 0;

        await withClock(Clock(() => now), () async {
          await tester.pumpWidget(
            wrap(
              _CountdownProbe(
                nextWakeAt: now.subtract(const Duration(seconds: 1)),
                onExpired: () => expiredCalls++,
              ),
            ),
          );
          await tester.pump();

          expect(find.text('expired'), findsOneWidget);
          expect(expiredCalls, 1);

          // Pumping further must not re-fire onCountdownExpired because
          // no timer was started for an already-past target.
          await tester.pump(const Duration(seconds: 5));
          expect(expiredCalls, 1);
        });
      },
    );

    testWidgets('cancels the timer cleanly on dispose', (tester) async {
      final start = DateTime(2024, 3, 15, 12);
      final nextWakeAt = start.add(const Duration(seconds: 30));

      await withClock(Clock(() => start), () async {
        await tester.pumpWidget(wrap(_CountdownProbe(nextWakeAt: nextWakeAt)));
        await tester.pump();
        expect(find.text('30'), findsOneWidget);

        // Detaching the widget tree disposes the state. If the periodic
        // timer is not cancelled in `dispose`, the flutter_test runtime
        // detects the leaked timer at the end of the test and fails.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      });
    });
  });
}

class _GeneratedCountdownScenario {
  const _GeneratedCountdownScenario({
    required this.initialOffsetSeconds,
    required this.elapsedSeconds,
    required this.updatedOffsetSeconds,
    required this.disableTickerBeforeElapsed,
  });

  final int initialOffsetSeconds;
  final int elapsedSeconds;
  final int updatedOffsetSeconds;
  final bool disableTickerBeforeElapsed;

  @override
  String toString() {
    return '_GeneratedCountdownScenario('
        'initialOffsetSeconds: $initialOffsetSeconds, '
        'elapsedSeconds: $elapsedSeconds, '
        'updatedOffsetSeconds: $updatedOffsetSeconds, '
        'disableTickerBeforeElapsed: $disableTickerBeforeElapsed)';
  }
}

List<_GeneratedCountdownScenario> _generatedCountdownScenarios() {
  final scenarios = <_GeneratedCountdownScenario>[];

  for (final initialOffsetSeconds in const <int>[-1, 0, 1, 7, 90]) {
    for (final elapsedSeconds in const <int>[0, 2, 30]) {
      for (final updatedOffsetSeconds in const <int>[-1, 0, 5, 120]) {
        for (final disableTickerBeforeElapsed in const <bool>[false, true]) {
          scenarios.add(
            _GeneratedCountdownScenario(
              initialOffsetSeconds: initialOffsetSeconds,
              elapsedSeconds: elapsedSeconds,
              updatedOffsetSeconds: updatedOffsetSeconds,
              disableTickerBeforeElapsed: disableTickerBeforeElapsed,
            ),
          );
        }
      }
    }
  }

  return scenarios;
}

int _remainingCountdownSeconds(DateTime now, DateTime nextWakeAt) {
  final remaining = nextWakeAt.difference(now);
  if (remaining <= Duration.zero) {
    return 0;
  }

  return remaining.inSeconds;
}

void _expectCountdownSeconds(int seconds, {required String reason}) {
  expect(
    find.text(seconds <= 0 ? 'expired' : '$seconds'),
    findsOneWidget,
    reason: reason,
  );
}

/// Minimal harness widget that mixes in [WakeCountdownState] so the
/// mixin's behavior can be exercised without coupling to the real pill
/// widgets. The build output deliberately shows raw seconds (or
/// `expired`) so the tests can assert on plain text.
class _CountdownProbe extends StatefulWidget {
  const _CountdownProbe({
    required this.nextWakeAt,
    this.onExpired,
  });

  final DateTime nextWakeAt;
  final VoidCallback? onExpired;

  @override
  State<_CountdownProbe> createState() => _CountdownProbeState();
}

class _CountdownProbeState extends State<_CountdownProbe>
    with WakeCountdownState<_CountdownProbe> {
  @override
  DateTime get nextWakeAt => widget.nextWakeAt;

  @override
  void didUpdateWidget(covariant _CountdownProbe oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nextWakeAt != widget.nextWakeAt) {
      resyncCountdown();
    }
  }

  @override
  void onCountdownExpired() => widget.onExpired?.call();

  @override
  Widget build(BuildContext context) {
    return Text(
      countdownSeconds <= 0 ? 'expired' : '$countdownSeconds',
      textDirection: TextDirection.ltr,
    );
  }
}
