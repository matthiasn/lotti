import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/task_agent_automation_panel.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';

import '../../../widget_test_utils.dart';

void main() {
  Widget subject({
    bool automaticUpdatesEnabled = false,
    bool automationBusy = false,
    bool inferenceAvailable = true,
    bool isRunning = false,
    bool isStale = false,
    bool showCountdown = false,
    DateTime? nextWakeAt,
    ValueChanged<bool>? onAutomaticUpdatesChanged,
    VoidCallback? onRunNow,
    VoidCallback? onCancelTimer,
    VoidCallback? onCountdownExpired,
  }) {
    return TaskAgentAutomationPanel(
      automaticUpdatesEnabled: automaticUpdatesEnabled,
      automationBusy: automationBusy,
      inferenceAvailable: inferenceAvailable,
      isRunning: isRunning,
      isStale: isStale,
      showCountdown: showCountdown,
      nextWakeAt: nextWakeAt,
      onAutomaticUpdatesChanged: onAutomaticUpdatesChanged ?? (_) {},
      onRunNow: onRunNow,
      onCancelTimer: onCancelTimer ?? () {},
      onCountdownExpired: onCountdownExpired ?? () {},
    );
  }

  testWidgets('off state explains manual control and toggle opts in', (
    tester,
  ) async {
    bool? changedTo;
    await tester.pumpWidget(
      makeTestableWidget(
        subject(onAutomaticUpdatesChanged: (value) => changedTo = value),
      ),
    );

    expect(find.text('Automatic updates'), findsOneWidget);
    expect(
      find.text(
        'Automatic updates are off. Wake the agent when you want a fresh '
        'report.',
      ),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('taskAgentAutomaticUpdatesCheckbox')),
    );

    expect(changedTo, isTrue);
  });

  testWidgets('stale state replaces routine action with a focused wake CTA', (
    tester,
  ) async {
    var wakes = 0;
    await tester.pumpWidget(
      makeTestableWidget(
        subject(isStale: true, onRunNow: () => wakes++),
      ),
    );

    expect(find.text('This summary is out of date'), findsOneWidget);
    expect(
      find.text('The task changed after this summary was generated.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('taskAgentStaleNotice')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('taskAgentWakeButton')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('taskAgentWakeButton')));

    expect(wakes, 1);
  });

  testWidgets('scheduled state shows countdown and cancellation', (
    tester,
  ) async {
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

      expect(find.text('1:30'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
    });

    expect(cancellations, 1);
  });

  testWidgets('missing setup disables inference and automation actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget(subject(inferenceAvailable: false)),
    );

    expect(
      find.text('Choose an AI setup before turning on automatic updates.'),
      findsOneWidget,
    );
    final wakeButton = tester.widget<DesignSystemButton>(
      find.byKey(const ValueKey('taskAgentWakeButton')),
    );
    expect(wakeButton.onPressed, isNull);
    final toggle = tester.widget<DesignSystemToggle>(
      find.byKey(const Key('taskAgentAutomaticUpdatesCheckbox')),
    );
    expect(toggle.enabled, isFalse);
  });
}
