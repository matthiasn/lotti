import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/agents/ui/task_agent_controls_footer.dart';
import 'package:lotti/features/agents/ui/widgets/ai_card_chrome.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/features/projects/ui/widgets/project_agent_summary_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../agents/test_utils.dart';
import '../../test_utils.dart';

void main() {
  AgentIdentityEntity makeIdentity() =>
      AgentDomainEntity.agent(
            id: 'identity-1',
            agentId: 'agent-1',
            kind: AgentKinds.projectAgent,
            displayName: 'Project Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {'cat-1'},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: DateTime(2026, 4),
            updatedAt: DateTime(2026, 4),
            vectorClock: null,
          )
          as AgentIdentityEntity;

  testWidgets('uses task-agent chrome, report body, and controls footer', (
    tester,
  ) async {
    final record = makeTestProjectRecord(
      healthMetrics: makeTestProjectHealthMetrics(
        band: ProjectHealthBand.atRisk,
        rationale: 'The launch path needs attention.',
      ),
      aiSummary: 'Review the feeder task before launch.',
      reportContent:
          'Review the feeder task before launch.\n\nThe remaining work is sequenced.',
    );

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: ProjectAgentSummaryCard(
            projectId: 'project-1',
            record: record,
            identity: makeIdentity(),
            hasProjectAgent: true,
            isMutating: false,
            actions: const Text('Project agent decisions'),
          ),
        ),
        overrides: [
          agentReportProvider.overrideWith(
            (ref, id) async => makeTestReport(agentId: id),
          ),
          agentIdentityProvider.overrideWith((ref, id) async => null),
          taskAgentSetupOptionsProvider.overrideWith(
            (ref) async => const TaskAgentSetupOptions(
              profiles: [],
              models: [],
              providers: [],
            ),
          ),

          agentStateProvider.overrideWith((ref, id) async => null),
          agentIsRunningProvider.overrideWith(
            (ref, id) => Stream.value(false),
          ),
          taskAgentResolvedSetupProvider.overrideWith(
            (ref, id) async => const ResolvedAgentSetup(
              status: AgentSetupResolutionStatus.disabled,
            ),
          ),
          templateForAgentProvider.overrideWith(
            (ref, id) async => makeTestTemplate(
              displayName: '  Project Planner  ',
              kind: AgentTemplateKind.projectAgent,
            ),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(AgentSummaryCardSurface), findsOneWidget);
    expect(find.byType(TldrHeader), findsOneWidget);
    expect(find.byType(TldrBody), findsOneWidget);
    expect(find.byType(TaskAgentControlsFooter), findsOneWidget);
    expect(find.text('Project Planner'), findsOneWidget);
    expect(
      tester
          .widget<TaskAgentControlsFooter>(find.byType(TaskAgentControlsFooter))
          .identityData
          .reportAttributionUnavailable,
      isTrue,
    );
    expect(find.text('At Risk'), findsOneWidget);
    expect(find.text('Project agent decisions'), findsOneWidget);
    tester.widget<TldrHeader>(find.byType(TldrHeader)).onAgentTap!();
    await tester.pumpAndSettle();
    final panel = tester.widget<AgentInternalsPanel>(
      find.byType(AgentInternalsPanel),
    );
    expect(panel.agentId, 'agent-1');
    expect(panel.agentName, 'Project Planner');
    Navigator.of(tester.element(find.byType(AgentInternalsPanel))).pop();
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(ProjectAgentSummaryCard));
    tester
        .widget<TaskAgentControlsFooter>(
          find.byType(TaskAgentControlsFooter),
        )
        .onSetupTap();
    await tester.pumpAndSettle();
    expect(find.text(context.messages.taskAgentSetupTitle), findsOneWidget);
    expect(
      find.text(context.messages.taskAgentSetupChoiceHelp),
      findsOneWidget,
    );
  });

  testWidgets(
    'read-only report expands and keeps actions mounted during mutation',
    (
      tester,
    ) async {
      var blockerOpens = 0;
      final record = makeTestProjectRecord(
        aiSummary: 'Launch summary.',
        reportContent: 'Launch summary.\n\nDetailed launch plan.',
        healthMetrics: makeTestProjectHealthMetrics(
          rationale: 'The feeder needs calibration.',
          confidence: 0.8,
        ),
      );
      Future<void> pumpCard({required bool mutating}) => tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: ProjectAgentSummaryCard(
              projectId: 'project-1',
              record: record,
              identity: null,
              hasProjectAgent: true,
              isMutating: mutating,
              onViewBlocker: () => blockerOpens++,
              actions: const Text('Review proposed changes'),
            ),
          ),
        ),
      );
      await pumpCard(mutating: false);
      TldrBody body() => tester.widget(find.byType(TldrBody));
      expect(body().tldr, 'Launch summary.');
      expect(body().expanded, isFalse);
      body().onToggle();
      await tester.pump();
      expect(body().expanded, isTrue);
      expect(body().additionalReport, contains('Detailed launch plan.'));
      expect(find.text('The feeder needs calibration.'), findsOneWidget);
      expect(find.text('Review proposed changes'), findsOneWidget);
      final blocker = find.text('1 task blocked');
      await tester.tap(blocker);
      expect(blockerOpens, 1);

      await pumpCard(mutating: true);
      expect(
        find.text('Review proposed changes'),
        findsOneWidget,
        reason:
            'The host disables the bands; the card must not drop them, '
            'or an in-flight decision loses its row state.',
      );
      await tester.tap(blocker);
      expect(blockerOpens, 1);
      expect(find.byType(TaskAgentControlsFooter), findsNothing);
    },
  );

  testWidgets('keeps the task-style assignment row single-flight', (
    tester,
  ) async {
    var requests = 0;
    final completion = Completer<void>();

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: ProjectAgentSummaryCard(
            projectId: 'project-1',
            record: makeTestProjectRecord(),
            identity: null,
            hasProjectAgent: false,
            isMutating: false,
            onAssignAgent: () {
              requests++;
              return completion.future;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Assign an agent'));
    await tester.pump();
    await tester.tap(find.text('Assign an agent'));

    expect(requests, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completion.complete();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  for (final fails in [false, true]) {
    testWidgets('automation preference update (fails: $fails)', (
      tester,
    ) async {
      var identity = makeIdentity().copyWith(
        config: const AgentConfig(automaticUpdatesEnabled: true),
      );
      final taskService = MockTaskAgentService();
      final projectService = MockProjectAgentService();
      final model = testAiModel();
      when(
        () => projectService.getProjectAgentForProject('project-1'),
      ).thenAnswer((_) async => identity);
      when(
        () => taskService.updateAutomaticUpdates(
          agentId: 'agent-1',
          enabled: false,
        ),
      ).thenAnswer((_) async {
        if (fails) throw StateError('preference update rejected');
        identity = identity.copyWith(
          config: identity.config.copyWith(automaticUpdatesEnabled: false),
        );
      });

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: Consumer(
              builder: (context, ref, child) => ProjectAgentSummaryCard(
                projectId: 'project-1',
                record: makeTestProjectRecord(),
                identity:
                    ref.watch(projectAgentProvider('project-1')).value
                        as AgentIdentityEntity?,
                hasProjectAgent: true,
                isMutating: false,
              ),
            ),
          ),
          overrides: [
            taskAgentServiceProvider.overrideWithValue(taskService),
            projectAgentServiceProvider.overrideWithValue(projectService),
            agentUpdateStreamProvider.overrideWith(
              (ref, id) => const Stream<Set<String>>.empty(),
            ),
            agentIdentityProvider.overrideWith((ref, id) async => identity),
            agentReportProvider.overrideWith((ref, id) async => null),
            agentStateProvider.overrideWith((ref, id) async => null),
            agentIsRunningProvider.overrideWith(
              (ref, id) => Stream.value(false),
            ),
            taskAgentResolvedSetupProvider.overrideWith(
              (ref, id) async => ResolvedAgentSetup(
                status: AgentSetupResolutionStatus.resolved,
                profile: ResolvedProfile(
                  thinkingModelId: model.providerModelId,
                  thinkingProvider: testInferenceProvider(),
                  thinkingModel: model,
                ),
              ),
            ),
            templateForAgentProvider.overrideWith((ref, id) async => null),
          ],
        ),
      );
      await tester.pump();
      TaskAgentControlsFooter footer() => tester.widget(
        find.byType(TaskAgentControlsFooter),
      );
      expect(footer().automaticUpdatesEnabled, isTrue);
      footer().onAutomaticUpdatesChanged(false);
      await tester.pump();
      await tester.pump();
      expect(identity.config.automaticUpdatesEnabled, fails);
      expect(footer().automaticUpdatesEnabled, fails);
      expect(footer().automationBusy, isFalse);
      verify(
        () => taskService.updateAutomaticUpdates(
          agentId: 'agent-1',
          enabled: false,
        ),
      ).called(1);
      if (fails) {
        final context = tester.element(find.byType(ProjectAgentSummaryCard));
        expect(find.text(context.messages.commonError), findsOneWidget);
      }
    });
  }

  for (final cancellationSucceeds in [false, true]) {
    testWidgets(
      'countdown follows persisted state after cancellation '
      '(succeeds: $cancellationSucceeds)',
      (tester) async {
        var currentTime = DateTime(2026, 9, 4, 12);
        await withClock(Clock(() => currentTime), () async {
          final firstWake = DateTime(2026, 9, 4, 12, 5);
          final laterWake = DateTime(2026, 9, 4, 12, 10);
          final wakeProvider = StateProvider<DateTime?>((ref) => firstWake);
          final model = testAiModel();
          var cancelRequests = 0;
          late ProviderContainer container;

          await tester.pumpWidget(
            makeTestableWidgetNoScroll(
              Scaffold(
                body: ProjectAgentSummaryCard(
                  projectId: 'project-1',
                  record: makeTestProjectRecord(
                    aiSummary: '',
                    reportContent: 'Launch is on track.',
                  ),
                  identity: makeIdentity().copyWith(
                    config: const AgentConfig(automaticUpdatesEnabled: true),
                  ),
                  hasProjectAgent: true,
                  isMutating: false,
                  onCancelScheduledWake: () {
                    cancelRequests++;
                    if (cancellationSucceeds) {
                      container.read(wakeProvider.notifier).state = null;
                    }
                  },
                ),
              ),
              overrides: [
                agentReportProvider.overrideWith((ref, id) async => null),
                agentStateProvider.overrideWith(
                  (ref, id) async => makeTestState(
                    agentId: id,
                    nextWakeAt: ref.watch(wakeProvider),
                  ),
                ),
                agentIsRunningProvider.overrideWith(
                  (ref, id) => Stream.value(false),
                ),
                taskAgentResolvedSetupProvider.overrideWith(
                  (ref, id) async => ResolvedAgentSetup(
                    status: AgentSetupResolutionStatus.resolved,
                    profile: ResolvedProfile(
                      thinkingModelId: model.providerModelId,
                      thinkingProvider: testInferenceProvider(),
                      thinkingModel: model,
                    ),
                  ),
                ),
                templateForAgentProvider.overrideWith((ref, id) async => null),
              ],
            ),
          );
          await tester.pump();
          container = ProviderScope.containerOf(
            tester.element(find.byType(ProjectAgentSummaryCard)),
          );
          TaskAgentControlsFooter footer() => tester.widget(
            find.byType(TaskAgentControlsFooter),
          );
          expect(footer().showCountdown, isTrue);
          footer().onSkipScheduledUpdate();
          await tester.pump();
          await tester.pump();
          expect(cancelRequests, 1);
          expect(footer().showCountdown, !cancellationSucceeds);

          container.read(wakeProvider.notifier).state = laterWake;
          await tester.pump();
          await tester.pump();
          expect(footer().showCountdown, isTrue);
          expect(footer().nextWakeAt, laterWake);
          expect(footer().hasReportContent, isTrue);
          currentTime = laterWake.add(const Duration(seconds: 1));
          footer().onCountdownExpired();
          await tester.pump();
          expect(footer().showCountdown, isFalse);
        });
      },
    );
  }
}
