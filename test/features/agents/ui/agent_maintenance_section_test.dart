import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_maintenance_section.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/icon_tokens.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_helper.dart';
import '../test_data/entity_factories.dart';

/// The maintenance band that the agent internals panel hosts: everything the
/// task and project summary cards used to pin under their summary.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const agentId = 'agent-001';
  const entityId = 'task-001';
  final resolvedSetup = ResolvedAgentSetup(
    status: AgentSetupResolutionStatus.resolved,
    profile: ResolvedProfile(
      thinkingModelId: 'test-model',
      thinkingProvider: AiConfigInferenceProvider(
        id: 'test-provider',
        baseUrl: 'https://example.invalid',
        apiKey: 'test-key',
        name: 'Test Provider',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      ),
    ),
    source: AgentSetupResolutionSource.legacyModel,
  );

  Widget build({
    AgentStateEntity? state,
    AgentReportEntity? report,
    bool automaticUpdates = false,
    bool isRunning = false,
    ResolvedAgentSetup? setup,
    MockTaskAgentService? taskAgentService,
    MockProjectAgentService? projectAgentService,
    AgentMaintenanceKind kind = AgentMaintenanceKind.task,
  }) {
    return RiverpodWidgetTestBench(
      mediaQueryData: const MediaQueryData(size: Size(900, 800)),
      overrides: [
        agentIdentityProvider.overrideWith(
          (ref, id) async => makeTestIdentity(
            config: AgentConfig(automaticUpdatesEnabled: automaticUpdates),
          ),
        ),
        agentStateProvider.overrideWith((ref, id) async => state),
        agentReportProvider.overrideWith((ref, id) async => report),
        agentIsRunningProvider.overrideWith(
          (ref, id) => Stream.value(isRunning),
        ),
        taskAgentResolvedSetupProvider.overrideWith(
          (ref, id) async => setup ?? resolvedSetup,
        ),
        taskAgentSetupOptionsProvider.overrideWith(
          (ref) async => const TaskAgentSetupOptions(
            profiles: [],
            models: [],
            providers: [],
          ),
        ),
        if (taskAgentService != null)
          taskAgentServiceProvider.overrideWith((ref) => taskAgentService),
        if (projectAgentService != null)
          projectAgentServiceProvider.overrideWith(
            (ref) => projectAgentService,
          ),
      ],
      child: SingleChildScrollView(
        child: AgentMaintenanceSection(
          agentId: agentId,
          scope: AgentMaintenanceScope(kind: kind, entityId: entityId),
        ),
      ),
    );
  }

  group('AgentMaintenanceSection', () {
    testWidgets('carries the schedule, the switch and the model identity', (
      tester,
    ) async {
      await withClock(Clock.fixed(DateTime(2026, 5, 4, 12)), () async {
        await tester.pumpWidget(
          build(
            automaticUpdates: true,
            state: makeTestState(nextWakeAt: DateTime(2026, 5, 4, 12, 0, 30)),
            report: makeTestReport(tldr: 'Tldr line.'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('0:30'), findsOneWidget);
        expect(find.text('Skip once'), findsOneWidget);
        expect(find.text('Automatic updates'), findsOneWidget);
        expect(find.text('Update now'), findsOneWidget);
        expect(find.text('test-model · via Test Provider'), findsOneWidget);
      });
    });

    testWidgets('says Up to date, which the summary card no longer does', (
      tester,
    ) async {
      await tester.pumpWidget(
        build(report: makeTestReport(tldr: 'Tldr line.')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Up to date'), findsOneWidget);
    });

    testWidgets('Update now triggers the task agent service', (tester) async {
      final taskAgentService = MockTaskAgentService();
      when(() => taskAgentService.triggerReanalysis(any())).thenAnswer((_) {});

      await tester.pumpWidget(
        build(
          taskAgentService: taskAgentService,
          report: makeTestReport(tldr: 'Tldr line.'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('taskAgentWakeButton')));
      await tester.pumpAndSettle();

      verify(() => taskAgentService.triggerReanalysis(agentId)).called(1);
    });

    testWidgets('a project scope triggers the project agent service instead', (
      tester,
    ) async {
      final taskAgentService = MockTaskAgentService();
      final projectAgentService = MockProjectAgentService();
      when(
        () => projectAgentService.triggerReanalysis(any()),
      ).thenAnswer((_) {});

      await tester.pumpWidget(
        build(
          kind: AgentMaintenanceKind.project,
          taskAgentService: taskAgentService,
          projectAgentService: projectAgentService,
          report: makeTestReport(tldr: 'Tldr line.'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('taskAgentWakeButton')));
      await tester.pumpAndSettle();

      verify(() => projectAgentService.triggerReanalysis(agentId)).called(1);
      verifyNever(() => taskAgentService.triggerReanalysis(any()));
    });

    testWidgets('Skip once cancels the pending run and leaves the switch on', (
      tester,
    ) async {
      final taskAgentService = MockTaskAgentService();
      when(
        () => taskAgentService.cancelScheduledWake(any()),
      ).thenAnswer((_) {});

      await withClock(Clock.fixed(DateTime(2026, 5, 4, 12)), () async {
        await tester.pumpWidget(
          build(
            automaticUpdates: true,
            state: makeTestState(nextWakeAt: DateTime(2026, 5, 4, 12, 0, 30)),
            taskAgentService: taskAgentService,
            report: makeTestReport(tldr: 'Tldr line.'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('taskAgentSkipScheduledUpdate')),
        );
        await tester.pumpAndSettle();

        verify(() => taskAgentService.cancelScheduledWake(agentId)).called(1);
        expect(find.textContaining('0:30'), findsNothing);
        expect(find.text('Updates on changes'), findsOneWidget);
        expect(
          tester
              .widget<DesignSystemToggle>(
                find.byKey(const Key('taskAgentAutomaticUpdatesCheckbox')),
              )
              .value,
          isTrue,
        );
      });
    });

    testWidgets('a project scope cancels through the project service', (
      tester,
    ) async {
      final taskAgentService = MockTaskAgentService();
      final projectAgentService = MockProjectAgentService();
      when(
        () => projectAgentService.cancelScheduledWake(any()),
      ).thenAnswer((_) async {});

      await withClock(Clock.fixed(DateTime(2026, 5, 4, 12)), () async {
        await tester.pumpWidget(
          build(
            kind: AgentMaintenanceKind.project,
            automaticUpdates: true,
            state: makeTestState(nextWakeAt: DateTime(2026, 5, 4, 12, 0, 30)),
            taskAgentService: taskAgentService,
            projectAgentService: projectAgentService,
            report: makeTestReport(tldr: 'Tldr line.'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('taskAgentSkipScheduledUpdate')),
        );
        await tester.pumpAndSettle();

        verify(
          () => projectAgentService.cancelScheduledWake(agentId),
        ).called(1);
        verifyNever(() => taskAgentService.cancelScheduledWake(any()));
      });
    });

    testWidgets('a failed cancellation says so instead of going quiet', (
      tester,
    ) async {
      final taskAgentService = MockTaskAgentService();
      when(
        () => taskAgentService.cancelScheduledWake(any()),
      ).thenThrow(StateError('cancel failed'));

      await withClock(Clock.fixed(DateTime(2026, 5, 4, 12)), () async {
        await tester.pumpWidget(
          build(
            automaticUpdates: true,
            state: makeTestState(nextWakeAt: DateTime(2026, 5, 4, 12, 0, 30)),
            taskAgentService: taskAgentService,
            report: makeTestReport(tldr: 'Tldr line.'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('taskAgentSkipScheduledUpdate')),
        );
        await tester.pump();

        expect(find.text('Error'), findsOneWidget);
      });
    });

    testWidgets(
      'a wake rescheduled after a skip brings its countdown back',
      (tester) async {
        final taskAgentService = MockTaskAgentService();
        when(
          () => taskAgentService.cancelScheduledWake(any()),
        ).thenAnswer((_) {});

        await withClock(Clock.fixed(DateTime(2026, 5, 4, 12)), () async {
          AgentDomainEntity? current = makeTestState(
            nextWakeAt: DateTime(2026, 5, 4, 12, 0, 30),
          );
          await tester.pumpWidget(
            RiverpodWidgetTestBench(
              mediaQueryData: const MediaQueryData(size: Size(900, 800)),
              overrides: [
                agentIdentityProvider.overrideWith(
                  (ref, id) async => makeTestIdentity(
                    config: const AgentConfig(automaticUpdatesEnabled: true),
                  ),
                ),
                agentStateProvider.overrideWith((ref, id) async => current),
                agentReportProvider.overrideWith(
                  (ref, id) async => makeTestReport(tldr: 'Tldr line.'),
                ),
                agentIsRunningProvider.overrideWith(
                  (ref, id) => Stream.value(false),
                ),
                taskAgentResolvedSetupProvider.overrideWith(
                  (ref, id) async => resolvedSetup,
                ),
                taskAgentServiceProvider.overrideWith(
                  (ref) => taskAgentService,
                ),
              ],
              child: const SingleChildScrollView(
                child: AgentMaintenanceSection(
                  agentId: agentId,
                  scope: AgentMaintenanceScope(
                    kind: AgentMaintenanceKind.task,
                    entityId: entityId,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('taskAgentSkipScheduledUpdate')),
          );
          await tester.pumpAndSettle();
          expect(find.text('Skip once'), findsNothing);

          // A new deadline is not the one that was skipped, so it counts
          // down again rather than staying hidden behind a stale skip.
          final container = ProviderScope.containerOf(
            tester.element(find.byType(AgentMaintenanceSection)),
          );
          current = makeTestState(nextWakeAt: DateTime(2026, 5, 4, 12, 1, 30));
          container.invalidate(agentStateProvider(agentId));
          await tester.pumpAndSettle();

          expect(find.text('Skip once'), findsOneWidget);
          expect(find.textContaining('1:30'), findsOneWidget);
        });
      },
    );

    testWidgets('the switch persists the opt-in', (tester) async {
      final taskAgentService = MockTaskAgentService();
      when(
        () => taskAgentService.updateAutomaticUpdates(
          agentId: any(named: 'agentId'),
          enabled: any(named: 'enabled'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        build(
          taskAgentService: taskAgentService,
          report: makeTestReport(tldr: 'Summary.'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('taskAgentAutomaticUpdatesCheckbox')),
      );
      await tester.pump();

      verify(
        () => taskAgentService.updateAutomaticUpdates(
          agentId: agentId,
          enabled: true,
        ),
      ).called(1);
    });

    testWidgets('a failed opt-in surfaces an error and re-enables the switch', (
      tester,
    ) async {
      final taskAgentService = MockTaskAgentService();
      when(
        () => taskAgentService.updateAutomaticUpdates(
          agentId: any(named: 'agentId'),
          enabled: any(named: 'enabled'),
        ),
      ).thenThrow(StateError('write failed'));

      await tester.pumpWidget(
        build(
          taskAgentService: taskAgentService,
          report: makeTestReport(tldr: 'Summary.'),
        ),
      );
      await tester.pumpAndSettle();
      final toggle = find.byKey(
        const Key('taskAgentAutomaticUpdatesCheckbox'),
      );
      await tester.tap(toggle);
      await tester.pump();

      expect(find.text('Error'), findsOneWidget);
      expect(tester.widget<DesignSystemToggle>(toggle).enabled, isTrue);
    });

    testWidgets('the identity row opens the agent setup sheet', (tester) async {
      await tester.pumpWidget(
        build(report: makeTestReport(tldr: 'Tldr line.')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('test-model · via Test Provider'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Agent setup'), findsOneWidget);
    });

    testWidgets('without a setup the trigger is dead and says why', (
      tester,
    ) async {
      final taskAgentService = MockTaskAgentService();

      await tester.pumpWidget(
        build(
          taskAgentService: taskAgentService,
          setup: const ResolvedAgentSetup(
            status: AgentSetupResolutionStatus.disabled,
          ),
          report: makeTestReport(tldr: 'Existing report.'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Choose a saved setup or thinking model before this agent can run.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(LottiIcons.info), findsOneWidget);
      expect(
        tester
            .widget<DesignSystemButton>(
              find.byKey(const ValueKey('taskAgentWakeButton')),
            )
            .onPressed,
        isNull,
      );
      verifyNever(() => taskAgentService.triggerReanalysis(any()));
    });

    testWidgets('a long deadline reads h:mm:ss rather than running minutes', (
      tester,
    ) async {
      final now = DateTime(2026, 5, 4, 23, 20, 46);
      await withClock(Clock.fixed(now), () async {
        await tester.pumpWidget(
          build(
            automaticUpdates: true,
            state: makeTestState(
              nextWakeAt: now.add(
                const Duration(hours: 5, minutes: 39, seconds: 14),
              ),
            ),
            report: makeTestReport(tldr: 'Tldr line.'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Next update in 5:39:14'), findsOneWidget);
        expect(find.textContaining('339:14'), findsNothing);
      });
    });

    testWidgets('an expired deadline gives way to the settled line', (
      tester,
    ) async {
      final wakeAt = DateTime(2026, 5, 4, 12, 0, 2);
      var clockNow = DateTime(2026, 5, 4, 12);
      await withClock(Clock(() => clockNow), () async {
        await tester.pumpWidget(
          build(
            automaticUpdates: true,
            state: makeTestState(nextWakeAt: wakeAt),
            report: makeTestReport(tldr: 'Tldr line.'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.textContaining('0:02'), findsOneWidget);

        for (var second = 1; second <= 3; second++) {
          clockNow = DateTime(2026, 5, 4, 12, 0, second);
          await tester.pump(const Duration(seconds: 1));
        }
        await tester.pump();

        expect(
          find.byKey(const ValueKey('taskAgentSkipScheduledUpdate')),
          findsNothing,
        );
        expect(find.text('Updates on changes'), findsOneWidget);
      });
    });

    testWidgets('a persisted scheduled wake counts down like a live one', (
      tester,
    ) async {
      // A project agent records its pending wake in `scheduledWakeAt` while
      // the runtime holds `nextWakeAt`; the band reads both.
      await withClock(Clock.fixed(DateTime(2026, 5, 4, 12)), () async {
        await tester.pumpWidget(
          build(
            kind: AgentMaintenanceKind.project,
            automaticUpdates: true,
            state: makeTestState().copyWith(
              scheduledWakeAt: DateTime(2026, 5, 4, 12, 0, 45),
            ),
            report: makeTestReport(tldr: 'Tldr line.'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('0:45'), findsOneWidget);
      });
    });
  });
}
