import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/task_agent_freshness_strip.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';

import '../../../widget_test_utils.dart';

void main() {
  testWidgets('stale state explains staleness and wakes the agent on tap', (
    tester,
  ) async {
    var wakes = 0;
    await tester.pumpWidget(
      makeTestableWidget(
        TaskAgentFreshnessStrip(
          isStale: true,
          isRunning: false,
          onRunNow: () => wakes++,
        ),
      ),
    );

    expect(find.text('This summary is out of date'), findsOneWidget);
    expect(find.byKey(const ValueKey('taskAgentStaleNotice')), findsOneWidget);
    final button = tester.widget<DesignSystemButton>(
      find.byKey(const ValueKey('taskAgentWakeButton')),
    );
    expect(button.variant, DesignSystemButtonVariant.primary);

    await tester.tap(find.byKey(const ValueKey('taskAgentWakeButton')));

    expect(wakes, 1);
  });

  testWidgets(
    'fresh state keeps the slot with a quiet confirmation and secondary CTA',
    (tester) async {
      var wakes = 0;
      await tester.pumpWidget(
        makeTestableWidget(
          TaskAgentFreshnessStrip(
            isStale: false,
            isRunning: false,
            onRunNow: () => wakes++,
          ),
        ),
      );

      expect(find.text('Summary is up to date'), findsOneWidget);
      expect(find.text('This summary is out of date'), findsNothing);
      expect(
        find.byKey(const ValueKey('taskAgentFreshNotice')),
        findsOneWidget,
      );
      final button = tester.widget<DesignSystemButton>(
        find.byKey(const ValueKey('taskAgentWakeButton')),
      );
      expect(button.variant, DesignSystemButtonVariant.secondary);

      await tester.tap(find.byKey(const ValueKey('taskAgentWakeButton')));
      expect(wakes, 1);
    },
  );

  testWidgets('stale and fresh states occupy the same height', (tester) async {
    await tester.pumpWidget(
      makeTestableWidget(
        const TaskAgentFreshnessStrip(
          isStale: true,
          isRunning: false,
          onRunNow: null,
        ),
      ),
    );
    final staleHeight = tester
        .getSize(find.byKey(const ValueKey('taskAgentStaleNotice')))
        .height;

    await tester.pumpWidget(
      makeTestableWidget(
        const TaskAgentFreshnessStrip(
          isStale: false,
          isRunning: false,
          onRunNow: null,
        ),
      ),
    );
    final freshHeight = tester
        .getSize(find.byKey(const ValueKey('taskAgentFreshNotice')))
        .height;

    expect(freshHeight, staleHeight);
  });

  testWidgets('running wake swaps the CTA to a non-firing thinking state', (
    tester,
  ) async {
    var wakes = 0;
    await tester.pumpWidget(
      makeTestableWidget(
        TaskAgentFreshnessStrip(
          isStale: true,
          isRunning: true,
          onRunNow: () => wakes++,
        ),
      ),
    );

    expect(find.text('Thinking…'), findsOneWidget);
    expect(find.text('Wake agent'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('taskAgentWakeButton')));

    expect(wakes, 0);
  });

  testWidgets('missing inference setup renders a disabled CTA', (
    tester,
  ) async {
    await tester.pumpWidget(
      makeTestableWidget(
        const TaskAgentFreshnessStrip(
          isStale: true,
          isRunning: false,
          onRunNow: null,
        ),
      ),
    );

    final button = tester.widget<DesignSystemButton>(
      find.byKey(const ValueKey('taskAgentWakeButton')),
    );
    expect(button.onPressed, isNull);
  });
}
