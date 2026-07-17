import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../test_data/entity_factories.dart';
import 'test_bench.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiSummaryCard – Wake affordances', () {
    testWidgets('shows the manual wake CTA when the agent is idle', (
      tester,
    ) async {
      final bench = AgentTestBench(
        report: makeTestReport(tldr: 'Tldr line.'),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      expect(find.text('AI summary'), findsOneWidget);
      expect(find.text('Wake agent'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });

    testWidgets('setup identity opens the persistent agent setup sheet', (
      tester,
    ) async {
      final bench = AgentTestBench(
        provideAgentIdentity: true,
        report: makeTestReport(tldr: 'Tldr line.'),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();
      await tester.tap(find.text('test-model · via Test Provider'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Agent setup'), findsOneWidget);
    });

    testWidgets(
      'tapping Wake agent triggers a re-analysis on the task agent service',
      (tester) async {
        final taskAgentService = MockTaskAgentService();
        when(
          () => taskAgentService.triggerReanalysis(any()),
        ).thenAnswer((_) {});

        final bench = AgentTestBench(
          taskAgentService: taskAgentService,
          report: makeTestReport(tldr: 'Tldr line.'),
        );

        await tester.pumpWidget(bench.build());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('taskAgentWakeButton')));
        await tester.pumpAndSettle();

        verify(() => taskAgentService.triggerReanalysis(any())).called(1);
      },
    );

    testWidgets(
      'scheduled countdown replaces the manual wake button entirely',
      (
        tester,
      ) async {
        await withClock(Clock.fixed(DateTime(2026, 5, 4, 12)), () async {
          final state = makeTestState(
            nextWakeAt: DateTime(2026, 5, 4, 12, 0, 30),
          );
          final identity = makeTestIdentity().copyWith(
            config: const AgentConfig(automaticUpdatesEnabled: true),
          );
          final bench = AgentTestBench(
            identity: identity,
            state: state,
            report: makeTestReport(tldr: 'Tldr line.'),
          );

          await tester.pumpWidget(bench.build());
          await tester.pumpAndSettle();

          // One wake affordance per state: while the countdown runs, the
          // scheduled update IS the pending wake — no second button.
          expect(find.text('Wake agent'), findsNothing);
          expect(find.byIcon(Icons.close_rounded), findsOneWidget);
          expect(find.text('Next update in 0:30'), findsOneWidget);
        });
      },
    );

    testWidgets(
      'automatic updates off stays prominent and keeps manual wake available',
      (tester) async {
        final taskAgentService = MockTaskAgentService();
        when(
          () => taskAgentService.triggerReanalysis(any()),
        ).thenAnswer((_) {});
        final identity = makeTestIdentity().copyWith(
          config: const AgentConfig(automaticUpdatesEnabled: false),
        );
        final bench = AgentTestBench(
          identity: identity,
          taskAgentService: taskAgentService,
          state: makeTestState(nextWakeAt: DateTime(2026, 5, 4, 12, 0, 30)),
          report: makeTestReport(tldr: 'Tldr line.'),
        );

        await tester.pumpWidget(bench.build());
        await tester.pumpAndSettle();

        expect(find.text('Automatic updates'), findsOneWidget);
        expect(
          find.byKey(const Key('taskAgentAutomaticUpdatesCheckbox')),
          findsOneWidget,
        );
        expect(find.text('Wake agent'), findsOneWidget);
        expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsNothing);
        expect(find.textContaining('0:30'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('taskAgentWakeButton')));
        verify(() => taskAgentService.triggerReanalysis(any())).called(1);
      },
    );

    testWidgets('stale report surfaces one clear manual wake CTA', (
      tester,
    ) async {
      final taskAgentService = MockTaskAgentService();
      when(
        () => taskAgentService.triggerReanalysis(any()),
      ).thenAnswer((_) {});
      final identity = makeTestIdentity().copyWith(
        config: const AgentConfig(automaticUpdatesEnabled: false),
      );
      final state = makeTestState().copyWith(
        reportStaleAt: DateTime(2026, 5, 4, 12),
        reportFreshAt: DateTime(2026, 5, 4, 11),
      );
      final bench = AgentTestBench(
        identity: identity,
        state: state,
        taskAgentService: taskAgentService,
        report: makeTestReport(tldr: 'Old summary.'),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      expect(find.text('This summary is out of date'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('taskAgentStaleNotice')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('taskAgentWakeButton')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('taskAgentWakeButton')));

      verify(() => taskAgentService.triggerReanalysis(any())).called(1);
    });

    testWidgets(
      'stale without any report keeps the footer wake button — the strip '
      'has nothing to describe',
      (tester) async {
        final identity = makeTestIdentity().copyWith(
          config: const AgentConfig(automaticUpdatesEnabled: false),
        );
        final state = makeTestState().copyWith(
          reportStaleAt: DateTime(2026, 5, 4, 12),
        );
        final bench = AgentTestBench(identity: identity, state: state);

        await tester.pumpWidget(bench.build());
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('taskAgentStaleNotice')),
          findsNothing,
        );
        expect(find.text('This summary is out of date'), findsNothing);
        expect(
          find.byKey(const ValueKey('taskAgentWakeButton')),
          findsOneWidget,
        );
      },
    );

    testWidgets('auto-wake toggle persists the opt-in from the card', (
      tester,
    ) async {
      final taskAgentService = MockTaskAgentService();
      when(
        () => taskAgentService.updateAutomaticUpdates(
          agentId: any(named: 'agentId'),
          enabled: any(named: 'enabled'),
        ),
      ).thenAnswer((_) async {});
      final identity = makeTestIdentity().copyWith(
        config: const AgentConfig(automaticUpdatesEnabled: false),
      );
      final bench = AgentTestBench(
        identity: identity,
        taskAgentService: taskAgentService,
        report: makeTestReport(tldr: 'Summary.'),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('taskAgentAutomaticUpdatesCheckbox')),
      );
      await tester.pump();

      verify(
        () => taskAgentService.updateAutomaticUpdates(
          agentId: any(named: 'agentId'),
          enabled: true,
        ),
      ).called(1);
    });

    testWidgets('auto-wake failure shows an error and restores the toggle', (
      tester,
    ) async {
      final taskAgentService = MockTaskAgentService();
      when(
        () => taskAgentService.updateAutomaticUpdates(
          agentId: any(named: 'agentId'),
          enabled: any(named: 'enabled'),
        ),
      ).thenThrow(StateError('write failed'));
      final bench = AgentTestBench(
        identity: makeTestIdentity().copyWith(
          config: const AgentConfig(automaticUpdatesEnabled: false),
        ),
        taskAgentService: taskAgentService,
        report: makeTestReport(tldr: 'Summary.'),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();
      final toggleFinder = find.byKey(
        const Key('taskAgentAutomaticUpdatesCheckbox'),
      );
      await tester.tap(toggleFinder);
      await tester.pump();

      expect(find.text('Error'), findsOneWidget);
      expect(tester.widget<DesignSystemToggle>(toggleFinder).enabled, isTrue);
    });

    testWidgets('no setup disables Run now and shows a visible error', (
      tester,
    ) async {
      final taskAgentService = MockTaskAgentService();
      final bench = AgentTestBench(
        taskAgentService: taskAgentService,
        resolvedSetup: const ResolvedAgentSetup(
          status: AgentSetupResolutionStatus.disabled,
        ),
        report: makeTestReport(tldr: 'Existing report.'),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Choose a saved setup or thinking model before this agent can run.',
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('No AI setup')), findsOneWidget);
      // The disabled toggle carries the needs-setup explanation as a tooltip
      // instead of a permanent caption line.
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
      final wakeButton = tester.widget<DesignSystemButton>(
        find.byKey(const ValueKey('taskAgentWakeButton')),
      );
      expect(wakeButton.onPressed, isNull);
      verifyNever(() => taskAgentService.triggerReanalysis(any()));
    });

    testWidgets('long scheduled wake countdown uses h:mm:ss format', (
      tester,
    ) async {
      final now = DateTime(2026, 5, 4, 23, 20, 46);
      await withClock(Clock.fixed(now), () async {
        final state = makeTestState(
          nextWakeAt: now.add(
            const Duration(hours: 5, minutes: 39, seconds: 14),
          ),
        );
        final identity = makeTestIdentity().copyWith(
          config: const AgentConfig(automaticUpdatesEnabled: true),
        );
        final bench = AgentTestBench(
          identity: identity,
          state: state,
          report: makeTestReport(tldr: 'Tldr line.'),
        );

        await tester.pumpWidget(bench.build());
        await tester.pumpAndSettle();

        expect(find.text('Wake agent'), findsNothing);
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);
        expect(find.text('Next update in 5:39:14'), findsOneWidget);
        expect(find.textContaining('339:14'), findsNothing);
      });
    });

    testWidgets('cancel-timer button cancels the scheduled wake', (
      tester,
    ) async {
      await withClock(Clock.fixed(DateTime(2026, 5, 4, 12)), () async {
        final taskAgentService = MockTaskAgentService();
        when(
          () => taskAgentService.cancelScheduledWake(any()),
        ).thenAnswer((_) {});
        final state = makeTestState(
          nextWakeAt: DateTime(2026, 5, 4, 12, 0, 30),
        );
        final identity = makeTestIdentity().copyWith(
          config: const AgentConfig(automaticUpdatesEnabled: true),
        );

        final bench = AgentTestBench(
          identity: identity,
          state: state,
          taskAgentService: taskAgentService,
          report: makeTestReport(tldr: 'Tldr line.'),
        );

        await tester.pumpWidget(bench.build());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        verify(() => taskAgentService.cancelScheduledWake(any())).called(1);

        expect(find.byIcon(Icons.close_rounded), findsNothing);
        expect(find.text('Wake agent'), findsOneWidget);
      });
    });
  });
}
