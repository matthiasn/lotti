import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/task_agent_automation_row.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../widget_test_utils.dart';

void main() {
  final now = DateTime(2026, 7, 16, 9);

  Widget subject({
    bool automaticUpdatesEnabled = false,
    bool automationBusy = false,
    bool inferenceAvailable = true,
    bool isRunning = false,
    bool showCountdown = false,
    DateTime? nextWakeAt,
    bool hasReportContent = false,
    bool isStale = false,
    ValueChanged<bool>? onAutomaticUpdatesChanged,
    VoidCallback? onRunNow,
    VoidCallback? onSkipScheduledUpdate,
    VoidCallback? onCountdownExpired,
  }) {
    return TaskAgentAutomationRow(
      automaticUpdatesEnabled: automaticUpdatesEnabled,
      automationBusy: automationBusy,
      inferenceAvailable: inferenceAvailable,
      isRunning: isRunning,
      showCountdown: showCountdown,
      nextWakeAt: nextWakeAt,
      hasReportContent: hasReportContent,
      isStale: isStale,
      onAutomaticUpdatesChanged: onAutomaticUpdatesChanged ?? (_) {},
      onRunNow: onRunNow,
      onSkipScheduledUpdate: onSkipScheduledUpdate ?? () {},
      onCountdownExpired: onCountdownExpired ?? () {},
    );
  }

  /// Pumps [child] at an explicit measure. The view — not `MediaQuery` — is
  /// what actually sizes the surface, so the fit decision under test sees the
  /// width the test names.
  Future<void> pumpRow(
    WidgetTester tester,
    Widget child, {
    double width = 730,
    Locale? locale,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    tester.view
      ..physicalSize = Size(width, 1200)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return tester.pumpWidget(
      makeTestableWidget(
        child,
        mediaQueryData: MediaQueryData(
          size: Size(width, 1200),
          textScaler: textScaler,
        ),
        locale: locale,
      ),
    );
  }

  Finder trigger() => find.byKey(const ValueKey('taskAgentWakeButton'));
  Finder toggle() => find.byKey(const Key('taskAgentAutomaticUpdatesCheckbox'));
  Finder scheduleLabel() =>
      find.byKey(const ValueKey('taskAgentScheduleLabel'));

  DsTokens tokensOf(WidgetTester tester) =>
      tester.element(find.byType(TaskAgentAutomationRow)).designTokens;

  group('manual trigger', () {
    testWidgets('is labelled, glyphed and fires the callback', (tester) async {
      var runs = 0;
      await pumpRow(tester, subject(onRunNow: () => runs++));

      expect(find.text('Update now'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      await tester.tap(trigger());
      expect(runs, 1);
    });

    testWidgets('stays live and in the same slot while a wake is scheduled', (
      tester,
    ) async {
      var runs = 0;
      var skips = 0;
      late Offset idleOffset;

      await withClock(Clock.fixed(now), () async {
        await pumpRow(tester, subject(onRunNow: () => runs++));
        idleOffset = tester.getTopLeft(trigger());

        await pumpRow(
          tester,
          subject(
            automaticUpdatesEnabled: true,
            showCountdown: true,
            nextWakeAt: now.add(const Duration(minutes: 1, seconds: 30)),
            onRunNow: () => runs++,
            onSkipScheduledUpdate: () => skips++,
          ),
        );

        // The scheduled update is information beside the action, not instead
        // of it: the trigger keeps its slot and stays pressable.
        expect(find.text('Update now'), findsOneWidget);
        expect(tester.getTopLeft(trigger()), idleOffset);
        expect(find.textContaining('1:30'), findsOneWidget);

        await tester.tap(trigger());
        expect(runs, 1);
        expect(skips, 0, reason: 'running by hand must not cancel the wake');
      });
    });

    testWidgets('swaps to the thinking label in place while running', (
      tester,
    ) async {
      await pumpRow(tester, subject(onRunNow: () {}));
      final idleRect = tester.getRect(trigger());

      await pumpRow(tester, subject(isRunning: true, onRunNow: () {}));

      expect(find.text('Thinking…'), findsOneWidget);
      expect(find.text('Update now'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Same slot, same height — a run in flight must not reflow the row.
      expect(trigger(), findsOneWidget);
      expect(tester.getRect(trigger()).height, idleRect.height);
      expect(
        tester.widget<DesignSystemButton>(trigger()).onPressed,
        isNull,
        reason: 'a run already in flight has nothing to re-trigger',
      );
    });

    testWidgets('is disabled, not hidden, when no AI setup is available', (
      tester,
    ) async {
      await pumpRow(
        tester,
        subject(inferenceAvailable: false, onRunNow: () {}),
      );

      expect(trigger(), findsOneWidget);
      expect(tester.widget<DesignSystemButton>(trigger()).onPressed, isNull);
      final toggleWidget = tester.widget<DesignSystemToggle>(toggle());
      expect(toggleWidget.enabled, isFalse);
      expect(
        toggleWidget.tooltipMessage,
        'Choose an AI setup before turning on automatic updates.',
      );
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    });
  });

  group('automatic-updates switch', () {
    testWidgets('reports changes and keeps a full-size interaction slot', (
      tester,
    ) async {
      bool? changedTo;
      await pumpRow(
        tester,
        subject(onAutomaticUpdatesChanged: (value) => changedTo = value),
      );

      await tester.tap(toggle());
      expect(changedTo, isTrue);

      final tokens = tokensOf(tester);
      expect(
        tester.getSize(
          find.byKey(const ValueKey('taskAgentAutomaticUpdatesTarget')),
        ),
        Size.square(tokens.spacing.step9),
      );
    });

    testWidgets('is disabled while an automation write is in flight', (
      tester,
    ) async {
      await pumpRow(tester, subject(automationBusy: true));
      expect(tester.widget<DesignSystemToggle>(toggle()).enabled, isFalse);
    });
  });

  group('freshness', () {
    testWidgets('is omitted entirely without report content', (tester) async {
      await pumpRow(tester, subject());

      expect(find.byKey(const ValueKey('taskAgentStaleGlyph')), findsNothing);
      expect(find.byKey(const ValueKey('taskAgentFreshGlyph')), findsNothing);
      expect(
        find.byKey(const ValueKey('taskAgentFreshnessLabel')),
        findsNothing,
      );
    });

    testWidgets('carries a word, not just a glyph, in both states', (
      tester,
    ) async {
      for (final (stale, glyphKey, label, tooltip) in [
        (
          true,
          'taskAgentStaleGlyph',
          'Out of date',
          'This summary is out of date',
        ),
        (
          false,
          'taskAgentFreshGlyph',
          'Up to date',
          'Summary is up to date',
        ),
      ]) {
        await pumpRow(
          tester,
          subject(hasReportContent: true, isStale: stale, onRunNow: () {}),
        );

        expect(find.byKey(ValueKey(glyphKey)), findsOneWidget);
        expect(find.text(label), findsOneWidget);
        expect(
          tester
              .widget<Tooltip>(
                find.ancestor(
                  of: find.byKey(ValueKey(glyphKey)),
                  matching: find.byType(Tooltip),
                ),
              )
              .message,
          tooltip,
        );
      }
    });

    testWidgets('shares the trigger baseline when they fit one line', (
      tester,
    ) async {
      await pumpRow(
        tester,
        subject(hasReportContent: true, isStale: true, onRunNow: () {}),
      );

      expect(
        tester.getCenter(find.text('Out of date')).dy,
        moreOrLessEquals(tester.getCenter(trigger()).dy, epsilon: 2),
      );
    });
  });

  group('schedule line', () {
    testWidgets('offers Skip, which cancels only the pending wake', (
      tester,
    ) async {
      var skips = 0;
      await withClock(Clock.fixed(now), () async {
        await pumpRow(
          tester,
          subject(
            automaticUpdatesEnabled: true,
            showCountdown: true,
            nextWakeAt: now.add(const Duration(minutes: 1, seconds: 30)),
            onRunNow: () {},
            onSkipScheduledUpdate: () => skips++,
          ),
        );

        // A worded action, not a bare glyph beside the switch it does not
        // control.
        expect(find.text('Skip'), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsNothing);
        await tester.tap(
          find.byKey(const ValueKey('taskAgentSkipScheduledUpdate')),
        );
        expect(skips, 1);
      });
    });

    testWidgets('resyncs in place when the deadline moves', (tester) async {
      await withClock(Clock.fixed(now), () async {
        await pumpRow(
          tester,
          subject(
            automaticUpdatesEnabled: true,
            showCountdown: true,
            nextWakeAt: now.add(const Duration(minutes: 1, seconds: 30)),
            onRunNow: () {},
          ),
        );
        expect(find.textContaining('1:30'), findsOneWidget);

        await pumpRow(
          tester,
          subject(
            automaticUpdatesEnabled: true,
            showCountdown: true,
            nextWakeAt: now.add(const Duration(seconds: 45)),
            onRunNow: () {},
          ),
        );
        expect(find.textContaining('0:45'), findsOneWidget);
        expect(find.textContaining('1:30'), findsNothing);
      });
    });

    testWidgets('reports expiry once for an already-passed deadline', (
      tester,
    ) async {
      var expiries = 0;
      await withClock(Clock.fixed(now), () async {
        await pumpRow(
          tester,
          subject(
            automaticUpdatesEnabled: true,
            showCountdown: true,
            nextWakeAt: now.subtract(const Duration(seconds: 1)),
            onRunNow: () {},
            onCountdownExpired: () => expiries++,
          ),
        );
        await tester.pump();
      });

      expect(find.textContaining('Next update in'), findsNothing);
      expect(expiries, 1);
    });

    testWidgets('says what happens next when nothing is pending', (
      tester,
    ) async {
      await pumpRow(
        tester,
        subject(automaticUpdatesEnabled: true, onRunNow: () {}),
      );

      // The line is reserved rather than appearing and disappearing as the
      // user flips the switch.
      expect(find.text('Updates when this task changes'), findsOneWidget);
    });

    testWidgets('is absent while automatic updates are off', (tester) async {
      await pumpRow(tester, subject(onRunNow: () {}));
      expect(scheduleLabel(), findsNothing);
    });

    testWidgets('never reports an expiry it does not have', (tester) async {
      var expiries = 0;
      await pumpRow(
        tester,
        subject(
          automaticUpdatesEnabled: true,
          onRunNow: () {},
          onCountdownExpired: () => expiries++,
        ),
      );
      await tester.pump();

      // "Updates when this task changes" has no deadline behind it; treating
      // it as an expired countdown would loop the card through rebuilds.
      expect(find.text('Updates when this task changes'), findsOneWidget);
      expect(expiries, 0);
    });
  });

  group('responsive behaviour', () {
    testWidgets('drops schedule prose before it drops the countdown value', (
      tester,
    ) async {
      await withClock(Clock.fixed(now), () async {
        await pumpRow(
          tester,
          subject(
            hasReportContent: true,
            automaticUpdatesEnabled: true,
            showCountdown: true,
            nextWakeAt: now.add(const Duration(minutes: 1, seconds: 30)),
            onRunNow: () {},
          ),
          width: 320,
          locale: const Locale('de'),
          textScaler: const TextScaler.linear(1.3),
        );

        // The sentence gives way, but the time itself is still on screen and
        // is not truncated.
        expect(find.text('Nächste Aktualisierung in 1:30'), findsNothing);
        expect(find.textContaining('1:30'), findsOneWidget);
        final label = tester.widget<Text>(scheduleLabel());
        expect(label.overflow, isNot(TextOverflow.ellipsis));
        expect(label.softWrap, isFalse);
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('stacks the trigger and the switch when they cannot share', (
      tester,
    ) async {
      await withClock(Clock.fixed(now), () async {
        await pumpRow(
          tester,
          subject(
            hasReportContent: true,
            automaticUpdatesEnabled: true,
            showCountdown: true,
            nextWakeAt: now.add(const Duration(minutes: 1, seconds: 30)),
            onRunNow: () {},
          ),
          width: 320,
          locale: const Locale('de'),
          textScaler: const TextScaler.linear(1.3),
        );

        expect(
          find.byKey(const ValueKey('taskAgentAutomationRowStacked')),
          findsOneWidget,
        );
        // Stacked, everything shares the leading edge instead of being flung
        // to opposite ends of a wrapped run.
        final left = tester.getTopLeft(
          find.byKey(const ValueKey('taskAgentStatusCluster')),
        );
        expect(tester.getTopLeft(trigger()).dx, moreOrLessEquals(left.dx));
        expect(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('taskAgentAutomationSetting')),
              )
              .dx,
          moreOrLessEquals(left.dx),
        );
      });
    });

    testWidgets('keeps one line when the measure genuinely allows it', (
      tester,
    ) async {
      await withClock(Clock.fixed(now), () async {
        await pumpRow(
          tester,
          subject(
            hasReportContent: true,
            automaticUpdatesEnabled: true,
            showCountdown: true,
            nextWakeAt: now.add(const Duration(minutes: 1, seconds: 30)),
            onRunNow: () {},
          ),
          // Generous: the test font is far wider per glyph than Inter, so a
          // production-realistic 730px here would stack for the wrong reason.
          width: 1400,
        );

        expect(
          find.byKey(const ValueKey('taskAgentAutomationRowWide')),
          findsOneWidget,
        );
        expect(
          tester.getCenter(scheduleLabel()).dy,
          moreOrLessEquals(tester.getCenter(toggle()).dy, epsilon: 1),
        );
      });
    });

    testWidgets(
      'survives every width, locale and text scale without overflow',
      (
        tester,
      ) async {
        for (final (width, locale, scale) in [
          (320.0, 'de', 1.3),
          (320.0, 'en', 1.0),
          (390.0, 'de', 1.2),
          (730.0, 'de', 1.3),
          (900.0, 'en', 1.0),
        ]) {
          for (final state in ['idle', 'running', 'countdown']) {
            await withClock(Clock.fixed(now), () async {
              await pumpRow(
                tester,
                subject(
                  hasReportContent: true,
                  isStale: state == 'idle',
                  isRunning: state == 'running',
                  automaticUpdatesEnabled: state == 'countdown',
                  showCountdown: state == 'countdown',
                  nextWakeAt: state == 'countdown'
                      ? now.add(const Duration(minutes: 1, seconds: 30))
                      : null,
                  onRunNow: () {},
                ),
                width: width,
                locale: Locale(locale),
                textScaler: TextScaler.linear(scale),
              );
            });

            expect(
              tester.takeException(),
              isNull,
              reason: '$state at ${width}px $locale ×$scale overflowed',
            );
            expect(
              trigger(),
              findsOneWidget,
              reason: 'trigger vanished at ${width}px $locale ×$scale',
            );
            expect(
              toggle(),
              findsOneWidget,
              reason: 'switch vanished at ${width}px $locale ×$scale',
            );
          }
        }
      },
    );
  });

  testWidgets('a ticking countdown moves nothing around it', (tester) async {
    var clockNow = DateTime(2026, 7, 16, 9);
    await withClock(Clock(() => clockNow), () async {
      await pumpRow(
        tester,
        subject(
          hasReportContent: true,
          automaticUpdatesEnabled: true,
          showCountdown: true,
          nextWakeAt: clockNow.add(const Duration(hours: 1)),
          onRunNow: () {},
        ),
      );

      expect(find.text('Next update in 1:00:00'), findsOneWidget);
      expect(
        tester.widget<Text>(scheduleLabel()).style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
      final labelSize = tester.getSize(scheduleLabel());
      final triggerOffset = tester.getTopLeft(trigger());
      final toggleOffset = tester.getTopLeft(toggle());
      final skipOffset = tester.getTopLeft(find.text('Skip'));

      // Crosses the h:mm:ss → m:ss boundary, where the label's own text gets
      // materially shorter.
      clockNow = clockNow.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Next update in 59:59'), findsOneWidget);
      expect(tester.getSize(scheduleLabel()), labelSize);
      expect(tester.getTopLeft(trigger()), triggerOffset);
      expect(tester.getTopLeft(toggle()), toggleOffset);
      expect(tester.getTopLeft(find.text('Skip')), skipOffset);
    });
  });
}
