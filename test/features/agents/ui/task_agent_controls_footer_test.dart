import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_report_provenance.dart';
import 'package:lotti/features/agents/ui/task_agent_controls_footer.dart';
import 'package:lotti/features/agents/ui/task_agent_model_identity.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
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
    bool showWakeButton = true,
    bool showCountdown = false,
    DateTime? nextWakeAt,
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
      showWakeButton: showWakeButton,
      showCountdown: showCountdown,
      nextWakeAt: nextWakeAt,
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
    expect(
      find.byKey(const ValueKey('taskAgentFooterWideLayout')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('taskAgentWakeButton')));
    expect(wakes, 1);

    await tester.tap(
      find.byKey(const Key('taskAgentAutomaticUpdatesCheckbox')),
    );
    expect(changedTo, isTrue);
  });

  testWidgets(
    'hides its wake button while the stale strip owns the CTA',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(subject(showWakeButton: false)),
      );

      expect(find.byKey(const ValueKey('taskAgentWakeButton')), findsNothing);
      expect(
        find.byKey(const Key('taskAgentAutomaticUpdatesCheckbox')),
        findsOneWidget,
      );
    },
  );

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
        // One wake affordance per state: the scheduled update replaces the
        // manual wake button.
        expect(find.byKey(const ValueKey('taskAgentWakeButton')), findsNothing);
        // The chip itself is informational — only the close button cancels.
        await tester.tap(find.text('Next update in 1:30'));
        expect(cancellations, 0);
        final context = tester.element(
          find.byType(TaskAgentControlsFooter),
        );
        expect(
          tester.getSize(
            find.byKey(
              const ValueKey('taskAgentCancelCountdownTarget'),
            ),
          ),
          Size.square(context.designTokens.spacing.step9),
        );
        await tester.tap(find.byIcon(Icons.close_rounded));
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
    'narrow German footer stacks identity above untruncated automation',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Center(
            child: SizedBox(
              width: 360,
              child: subject(showWakeButton: false),
            ),
          ),
          mediaQueryData: const MediaQueryData(size: Size(360, 800)),
          locale: const Locale('de'),
        ),
      );

      expect(
        find.byKey(const ValueKey('taskAgentFooterCompactLayout')),
        findsOneWidget,
      );
      final identity = find.textContaining('Qwen 3.5 Plus').first;
      final automation = find.text('Automatische Aktualisierungen');
      expect(automation, findsOneWidget);
      expect(
        tester.getBottomLeft(identity).dy,
        lessThan(tester.getTopLeft(automation).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('large text selects the compact footer layout', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Center(
          child: SizedBox(
            width: 700,
            child: subject(showWakeButton: false),
          ),
        ),
        mediaQueryData: const MediaQueryData(
          size: Size(700, 800),
          textScaler: TextScaler.linear(1.5),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('taskAgentFooterCompactLayout')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'wide German automation label stays single-line under constrained width',
    (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Center(
            child: SizedBox(
              width: 520,
              child: subject(showWakeButton: false),
            ),
          ),
          mediaQueryData: const MediaQueryData(
            size: Size(520, 800),
            textScaler: TextScaler.linear(1.2),
          ),
          locale: const Locale('de'),
        ),
      );

      expect(
        find.byKey(const ValueKey('taskAgentFooterWideLayout')),
        findsOneWidget,
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
    expect(
      tester.getSize(
        find.byKey(const ValueKey('taskAgentAutomaticUpdatesTarget')),
      ),
      Size.square(context.designTokens.spacing.step9),
    );
  });
}
