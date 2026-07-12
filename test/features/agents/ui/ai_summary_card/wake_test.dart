import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../test_data/entity_factories.dart';
import 'test_bench.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiSummaryCard – Wake affordances', () {
    testWidgets('shows the run-now refresh affordance when the agent is idle', (
      tester,
    ) async {
      final bench = AgentTestBench(
        report: makeTestReport(tldr: 'Tldr line.'),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      expect(find.text('AI summary'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });

    testWidgets(
      'tapping refresh triggers a re-analysis on the task agent service',
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

        await tester.tap(find.byIcon(Icons.refresh_rounded));
        await tester.pumpAndSettle();

        verify(() => taskAgentService.triggerReanalysis(any())).called(1);
      },
    );

    testWidgets(
      'countdown pill renders next to the run-now button when scheduled',
      (
        tester,
      ) async {
        await withClock(Clock.fixed(DateTime(2026, 5, 4, 12)), () async {
          final state = makeTestState(
            nextWakeAt: DateTime(2026, 5, 4, 12, 0, 30),
          );
          final bench = AgentTestBench(
            state: state,
            report: makeTestReport(tldr: 'Tldr line.'),
          );

          await tester.pumpWidget(bench.build());
          await tester.pumpAndSettle();

          expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
          expect(find.byIcon(Icons.close_rounded), findsOneWidget);
          expect(find.text('0:30'), findsOneWidget);
        });
      },
    );

    testWidgets(
      'automatic updates off hides countdown but keeps manual refresh',
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

        expect(
          find.text('Automatic updates off · Use Run now to update'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
        expect(find.byTooltip('Run now'), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsNothing);
        expect(find.text('0:30'), findsNothing);
        await tester.tap(find.byIcon(Icons.refresh_rounded));
        verify(() => taskAgentService.triggerReanalysis(any())).called(1);
      },
    );

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

      expect(find.text('No AI setup'), findsOneWidget);
      final refresh = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.refresh_rounded),
      );
      expect(refresh.onPressed, isNull);
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
        final bench = AgentTestBench(
          state: state,
          report: makeTestReport(tldr: 'Tldr line.'),
        );

        await tester.pumpWidget(bench.build());
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);
        expect(find.text('5:39:14'), findsOneWidget);
        expect(find.text('339:14'), findsNothing);
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

        final bench = AgentTestBench(
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
        expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      });
    });
  });
}
