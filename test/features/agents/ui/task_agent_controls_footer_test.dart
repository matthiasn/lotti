import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/agents/ui/task_agent_controls_footer.dart';
import 'package:lotti/features/agents/ui/task_agent_identity_region.dart';
import 'package:lotti/features/agents/ui/task_agent_model_identity.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../widget_test_utils.dart';

void main() {
  const route = InferenceRouteSnapshot(
    providerModelId: 'qwen3.5-plus',
    modelName: 'Qwen 3.5 Plus',
    publisherName: 'Alibaba',
    servingProviderType: InferenceProviderType.melious,
    servingProviderName: 'Melious.ai',
    runtimeSettings: {},
  );
  const identityData = TaskAgentModelIdentityViewData(
    presentation: TaskAgentIdentityPresentation.combined,
    currentRoute: route,
    reportRoute: route,
  );

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
    VoidCallback? onCancelTimer,
    VoidCallback? onCountdownExpired,
    VoidCallback? onSetupTap,
  }) {
    return TaskAgentControlsFooter(
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
      onCancelTimer: onCancelTimer ?? () {},
      onCountdownExpired: onCountdownExpired ?? () {},
      identityData: identityData,
      onSetupTap: onSetupTap ?? () {},
    );
  }

  testWidgets('wake button fires and the toggle opts in', (tester) async {
    var wakes = 0;
    bool? changedTo;
    await tester.pumpWidget(
      makeTestableWidget(
        subject(
          onRunNow: () => wakes++,
          onAutomaticUpdatesChanged: (value) => changedTo = value,
        ),
      ),
    );

    expect(find.text('Automatic updates'), findsOneWidget);
    expect(
      find.text('Qwen 3.5 Plus · Alibaba · via Melious.ai'),
      findsOneWidget,
    );
    // The wake control and the switch always live in one cluster, and
    // identity always sits in its own row below — the layout never has a
    // "wide, side by side" variant to switch to.
    expect(
      find.byKey(const ValueKey('taskAgentFooterLayout')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('taskAgentWakeButton')));
    expect(wakes, 1);

    await tester.tap(
      find.byKey(const Key('taskAgentAutomaticUpdatesCheckbox')),
    );
    expect(changedTo, isTrue);
  });

  group('freshness indicator', () {
    testWidgets('omitted entirely without report content', (tester) async {
      await tester.pumpWidget(makeTestableWidget(subject()));

      expect(find.byKey(const ValueKey('taskAgentStaleGlyph')), findsNothing);
      expect(find.byKey(const ValueKey('taskAgentFreshGlyph')), findsNothing);
    });

    testWidgets('shows the stale glyph next to the wake control', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          subject(hasReportContent: true, isStale: true, onRunNow: () {}),
        ),
      );

      expect(find.byKey(const ValueKey('taskAgentStaleGlyph')), findsOneWidget);
      expect(find.byKey(const ValueKey('taskAgentFreshGlyph')), findsNothing);
      final tooltip = tester.widget<Tooltip>(
        find.ancestor(
          of: find.byKey(const ValueKey('taskAgentStaleGlyph')),
          matching: find.byType(Tooltip),
        ),
      );
      expect(tooltip.message, 'This summary is out of date');
      // Same cluster as the wake control and switch — not a separate row.
      final glyph = find.byKey(const ValueKey('taskAgentStaleGlyph'));
      final wakeButton = find.byKey(const ValueKey('taskAgentWakeButton'));
      expect(
        tester.getCenter(glyph).dy,
        moreOrLessEquals(tester.getCenter(wakeButton).dy, epsilon: 2),
      );
    });

    testWidgets('shows the fresh glyph when the report is up to date', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          subject(hasReportContent: true, onRunNow: () {}),
        ),
      );

      expect(find.byKey(const ValueKey('taskAgentFreshGlyph')), findsOneWidget);
      expect(find.byKey(const ValueKey('taskAgentStaleGlyph')), findsNothing);
      final tooltip = tester.widget<Tooltip>(
        find.ancestor(
          of: find.byKey(const ValueKey('taskAgentFreshGlyph')),
          matching: find.byType(Tooltip),
        ),
      );
      expect(tooltip.message, 'Summary is up to date');
    });

    testWidgets(
      'stays with the wake control regardless of automatic-updates state',
      (tester) async {
        final now = DateTime(2026, 7, 16, 9);
        await withClock(Clock.fixed(now), () async {
          await tester.pumpWidget(
            makeTestableWidget(
              subject(
                hasReportContent: true,
                isStale: true,
                automaticUpdatesEnabled: true,
                showCountdown: true,
                nextWakeAt: now.add(const Duration(minutes: 1, seconds: 30)),
                onRunNow: () {},
              ),
            ),
          );
        });

        // Same cluster key regardless of automaticUpdatesEnabled — the
        // affordance never moves to a different part of the card.
        expect(
          find.byKey(const ValueKey('taskAgentStaleGlyph')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('taskAgentAutomationCluster')),
          findsOneWidget,
        );
      },
    );
  });

  testWidgets(
    'scheduled wake replaces the button with an informational chip and a '
    'dedicated cancel',
    (tester) async {
      final now = DateTime(2026, 7, 16, 9);
      var cancellations = 0;
      await withClock(Clock.fixed(now), () async {
        await tester.pumpWidget(
          makeTestableWidget(
            subject(
              automaticUpdatesEnabled: true,
              showCountdown: true,
              nextWakeAt: now.add(const Duration(minutes: 1, seconds: 30)),
              onRunNow: () {},
              onCancelTimer: () => cancellations++,
            ),
          ),
        );

        expect(find.text('Next update in 1:30'), findsOneWidget);
        expect(find.byType(DsPill), findsOneWidget);
        expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
        // One wake affordance per state: the scheduled update replaces the
        // manual wake button.
        expect(find.byKey(const ValueKey('taskAgentWakeButton')), findsNothing);
        // The chip itself is informational — only the close button cancels.
        await tester.tap(find.text('Next update in 1:30'));
        expect(cancellations, 0);
        final context = tester.element(
          find.byType(TaskAgentControlsFooter),
        );
        final tokens = context.designTokens;
        final countdownPill = find.byType(DsPill);
        final cancelIcon = find.byIcon(Icons.close_rounded);
        expect(
          tester.getSize(
            find.byKey(
              const ValueKey('taskAgentCancelCountdownTarget'),
            ),
          ),
          Size.square(tokens.spacing.step9),
        );
        expect(
          tester.getTopLeft(cancelIcon).dx -
              tester.getTopRight(countdownPill).dx,
          tokens.spacing.step1,
        );
        await tester.tap(cancelIcon);
      });

      expect(cancellations, 1);
    },
  );

  testWidgets(
    'a rescheduled wake resyncs the countdown chip in place',
    (tester) async {
      final now = DateTime(2026, 7, 16, 9);
      await withClock(Clock.fixed(now), () async {
        await tester.pumpWidget(
          makeTestableWidget(
            subject(
              automaticUpdatesEnabled: true,
              showCountdown: true,
              nextWakeAt: now.add(const Duration(minutes: 1, seconds: 30)),
              onRunNow: () {},
            ),
          ),
        );
        expect(find.text('Next update in 1:30'), findsOneWidget);

        // Same widget position, new deadline → didUpdateWidget resyncs the
        // ticking seconds instead of keeping the stale countdown.
        await tester.pumpWidget(
          makeTestableWidget(
            subject(
              automaticUpdatesEnabled: true,
              showCountdown: true,
              nextWakeAt: now.add(const Duration(seconds: 45)),
              onRunNow: () {},
            ),
          ),
        );
        expect(find.text('Next update in 0:45'), findsOneWidget);
        expect(find.text('Next update in 1:30'), findsNothing);
      });
    },
  );

  testWidgets(
    'an already-expired deadline renders nothing and reports expiry',
    (tester) async {
      final now = DateTime(2026, 7, 16, 9);
      var expiries = 0;
      await withClock(Clock.fixed(now), () async {
        await tester.pumpWidget(
          makeTestableWidget(
            subject(
              automaticUpdatesEnabled: true,
              showCountdown: true,
              nextWakeAt: now.subtract(const Duration(seconds: 1)),
              onCountdownExpired: () => expiries++,
              onRunNow: () {},
            ),
          ),
        );
        // The expiry callback is delivered post-frame.
        await tester.pump();
      });

      expect(find.textContaining('Next update in'), findsNothing);
      expect(expiries, 1);
    },
  );

  testWidgets('running wake shows the thinking state', (tester) async {
    await tester.pumpWidget(
      makeTestableWidget(subject(isRunning: true, onRunNow: () {})),
    );

    expect(find.text('Thinking…'), findsOneWidget);
    expect(find.text('Wake agent'), findsNothing);

    final context = tester.element(find.byType(TaskAgentControlsFooter));
    final spinner = find.byKey(const ValueKey('taskAgentThinkingSpinner'));
    final label = find.byKey(const ValueKey('taskAgentThinkingLabel'));
    expect(
      tester.getTopLeft(label).dx - tester.getTopRight(spinner).dx,
      context.designTokens.spacing.step3,
    );
  });

  testWidgets('narrow localized thinking status truncates without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Center(
          child: SizedBox(
            width: 180,
            child: subject(isRunning: true, onRunNow: () {}),
          ),
        ),
        mediaQueryData: const MediaQueryData(size: Size(180, 800)),
        locale: const Locale('de'),
      ),
    );

    final label = tester.widget<Text>(
      find.byKey(const ValueKey('taskAgentThinkingLabel')),
    );
    expect(label.maxLines, 1);
    expect(label.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'missing setup disables wake and toggle and explains via tooltip',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(subject(inferenceAvailable: false)),
      );

      final wakeButton = tester.widget<DesignSystemButton>(
        find.byKey(const ValueKey('taskAgentWakeButton')),
      );
      expect(wakeButton.onPressed, isNull);

      final toggle = tester.widget<DesignSystemToggle>(
        find.byKey(const Key('taskAgentAutomaticUpdatesCheckbox')),
      );
      expect(toggle.enabled, isFalse);
      expect(
        toggle.tooltipMessage,
        'Choose an AI setup before turning on automatic updates.',
      );
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    },
  );

  testWidgets('busy automation write disables the toggle', (tester) async {
    await tester.pumpWidget(
      makeTestableWidget(subject(automationBusy: true)),
    );

    final toggle = tester.widget<DesignSystemToggle>(
      find.byKey(const Key('taskAgentAutomaticUpdatesCheckbox')),
    );
    expect(toggle.enabled, isFalse);
  });

  testWidgets('model identity row opens the setup sheet callback', (
    tester,
  ) async {
    var setupTaps = 0;
    await tester.pumpWidget(
      makeTestableWidget(subject(onSetupTap: () => setupTaps++)),
    );

    await tester.tap(find.text('Qwen 3.5 Plus · Alibaba · via Melious.ai'));
    expect(setupTaps, 1);
  });

  testWidgets(
    'identity always sits below the automation cluster, at any width',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Center(
            child: SizedBox(
              width: 900,
              child: subject(),
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(900, 800)),
        ),
      );

      final identity = find.byType(TaskAgentIdentityRegion);
      final cluster = find.byKey(
        const ValueKey('taskAgentAutomationCluster'),
      );
      expect(cluster, findsOneWidget);
      expect(
        tester.getTopLeft(identity).dy,
        greaterThan(tester.getBottomLeft(cluster).dy),
      );
    },
  );

  testWidgets(
    'narrow scheduled cluster wraps countdown and switch without overflow',
    (tester) async {
      final now = DateTime(2026, 7, 16, 9);
      await withClock(Clock.fixed(now), () async {
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Center(
              child: SizedBox(
                width: 300,
                child: subject(
                  automaticUpdatesEnabled: true,
                  showCountdown: true,
                  nextWakeAt: now.add(
                    const Duration(minutes: 1, seconds: 30),
                  ),
                  onRunNow: () {},
                ),
              ),
            ),
            mediaQueryData: const MediaQueryData(size: Size(300, 800)),
          ),
        );
      });

      final countdown = find.text('Next update in 1:30');
      final automation = find.text('Automatic updates');
      final identity = find.textContaining('Qwen 3.5 Plus').first;
      expect(
        tester.getCenter(automation).dy,
        greaterThan(tester.getCenter(countdown).dy),
      );
      expect(
        tester.getCenter(identity).dy,
        greaterThan(tester.getCenter(automation).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'wide countdown and switch comfortably share one row',
    (tester) async {
      final now = DateTime(2026, 7, 16, 9);
      await withClock(Clock.fixed(now), () async {
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Center(
              child: SizedBox(
                width: 730,
                child: subject(
                  automaticUpdatesEnabled: true,
                  showCountdown: true,
                  nextWakeAt: now.add(
                    const Duration(minutes: 1, seconds: 30),
                  ),
                  onRunNow: () {},
                ),
              ),
            ),
            mediaQueryData: const MediaQueryData(size: Size(900, 800)),
          ),
        );
      });

      // Now that the cluster gets the whole footer width (identity is
      // always a separate row below, never sharing a 60% split with it),
      // 730px is comfortably enough to keep the countdown and the switch
      // on one line — this used to require a fixed-breakpoint compact
      // fallback when identity competed for the same row.
      final countdown = find.text('Next update in 1:30');
      final automation = find.text('Automatic updates');
      expect(
        tester.getCenter(countdown).dy,
        moreOrLessEquals(tester.getCenter(automation).dy, epsilon: 1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('countdown width and neighboring controls never jump', (
    tester,
  ) async {
    var now = DateTime(2026, 7, 16, 9);
    await withClock(Clock(() => now), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Center(
            child: SizedBox(
              width: 730,
              child: subject(
                automaticUpdatesEnabled: true,
                showCountdown: true,
                nextWakeAt: now.add(const Duration(hours: 1)),
                onRunNow: () {},
              ),
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(900, 800)),
        ),
      );

      expect(find.text('Next update in 1:00:00'), findsOneWidget);
      final pill = find.byType(DsPill);
      final toggle = find.byKey(
        const Key('taskAgentAutomaticUpdatesCheckbox'),
      );
      final identity = find.textContaining('Qwen 3.5 Plus').first;
      final initialPillSize = tester.getSize(pill);
      final initialToggleOffset = tester.getTopLeft(toggle);
      final initialIdentityOffset = tester.getTopLeft(identity);

      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Next update in 59:59'), findsOneWidget);
      expect(tester.getSize(pill), initialPillSize);
      expect(tester.getTopLeft(toggle), initialToggleOffset);
      expect(tester.getTopLeft(identity), initialIdentityOffset);
    });
  });

  testWidgets(
    'wide German automation label stays single-line even under constrained '
    'width',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Center(
            child: SizedBox(
              width: 520,
              child: subject(),
            ),
          ),
          mediaQueryData: const MediaQueryData(
            size: Size(520, 800),
            textScaler: TextScaler.linear(1.2),
          ),
          locale: const Locale('de'),
        ),
      );

      final label = tester.widget<Text>(
        find.text('Automatische Aktualisierungen'),
      );
      expect(label.maxLines, 1);
      expect(label.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('localized countdown stays single-line at phone width', (
    tester,
  ) async {
    final now = DateTime(2026, 7, 16, 9);
    await withClock(Clock.fixed(now), () async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Center(
            child: SizedBox(
              width: 360,
              child: subject(
                automaticUpdatesEnabled: true,
                showCountdown: true,
                nextWakeAt: now.add(
                  const Duration(minutes: 1, seconds: 30),
                ),
                onRunNow: () {},
              ),
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(360, 800)),
          locale: const Locale('de'),
        ),
      );
    });

    final countdown = tester.widget<Text>(find.textContaining('1:30'));
    expect(countdown.maxLines, 1);
    expect(countdown.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('automatic-updates control has a step9 interaction slot', (
    tester,
  ) async {
    await tester.pumpWidget(makeTestableWidget(subject()));

    final context = tester.element(find.byType(TaskAgentControlsFooter));
    final tokens = context.designTokens;
    final target = find.byKey(
      const ValueKey('taskAgentAutomaticUpdatesTarget'),
    );
    expect(
      tester.getSize(target),
      Size.square(tokens.spacing.step9),
    );
    expect(
      tester.getTopLeft(target).dx -
          tester.getTopRight(find.text('Automatic updates')).dx,
      tokens.spacing.step3,
    );
  });
}
