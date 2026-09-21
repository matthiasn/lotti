import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/ui/agent_internals_panel.dart';
import 'package:lotti/features/agents/ui/agent_maintenance_section.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/agents/ui/query/query_ask_button.dart';
import 'package:lotti/features/agents/ui/task_agent_identity_region.dart';
import 'package:lotti/features/agents/ui/widgets/ai_card_chrome.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/design_system/components/buttons/ds_ai_disc_button.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/features/projects/ui/widgets/project_agent_summary_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

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

  testWidgets('uses task-agent chrome and report body, maintenance behind '
      'the internals panel', (
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
          // The pushed internals panel resolves the agent through this
          // provider; without it the panel renders its not-found message
          // instead of the maintenance band.
          agentIdentityProvider.overrideWith((ref, id) async => makeIdentity()),
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
    expect(find.text('Project Planner'), findsOneWidget);
    expect(find.text('At Risk'), findsOneWidget);
    expect(find.text('Project agent decisions'), findsOneWidget);
    // The card itself carries no maintenance controls: no switch, no
    // schedule, no model identity.
    expect(find.byType(AgentMaintenanceSection), findsNothing);
    final context = tester.element(find.byType(ProjectAgentSummaryCard));
    expect(
      find.text(context.messages.taskAgentAutomaticUpdatesLabel),
      findsNothing,
    );

    tester.widget<TldrHeader>(find.byType(TldrHeader)).onAgentTap!();
    await tester.pumpAndSettle();
    final panel = tester.widget<AgentInternalsPanel>(
      find.byType(AgentInternalsPanel),
    );
    expect(panel.agentId, 'agent-1');
    expect(panel.agentName, 'Project Planner');
    // ...and the panel it opens is scoped to this project, so its Update now
    // reaches the project agent service and its setup row edits this
    // project's setup.
    expect(panel.maintenance?.kind, AgentMaintenanceKind.project);
    expect(panel.maintenance?.entityId, 'project-1');
    expect(find.byType(AgentMaintenanceSection), findsOneWidget);
    expect(
      find.text(context.messages.taskAgentAutomaticUpdatesLabel),
      findsOneWidget,
    );

    // No setup is resolved, so the band's identity row says so — and still
    // opens the sheet that fixes it.
    await tester.tap(
      find
          .descendant(
            of: find.byType(TaskAgentIdentityRegion),
            matching: find.byType(InkWell),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text(context.messages.taskAgentSetupTitle), findsWidgets);
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
    },
  );

  for (final stale in [false, true]) {
    testWidgets(
      'the freshness strip speaks only while the report is behind '
      '(stale: $stale)',
      (tester) async {
        var refreshes = 0;
        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Scaffold(
              body: ProjectAgentSummaryCard(
                projectId: 'project-1',
                record: makeTestProjectRecord(
                  aiSummary: 'Launch is on track.',
                ),
                identity: makeIdentity(),
                hasProjectAgent: true,
                isMutating: false,
                onRefresh: () => refreshes++,
              ),
            ),
            overrides: [
              agentReportProvider.overrideWith(
                (ref, id) async => makeTestReport(agentId: id),
              ),
              agentIdentityProvider.overrideWith((ref, id) async => null),
              agentStateProvider.overrideWith(
                (ref, id) async => stale
                    ? makeTestState(agentId: id).copyWith(
                        reportStaleAt: DateTime(2026, 9, 4, 12),
                        reportFreshAt: DateTime(2026, 9, 4, 11),
                      )
                    : makeTestState(agentId: id),
              ),
              agentIsRunningProvider.overrideWith(
                (ref, id) => Stream.value(false),
              ),
              taskAgentResolvedSetupProvider.overrideWith(
                (ref, id) async => ResolvedAgentSetup(
                  status: AgentSetupResolutionStatus.resolved,
                  profile: ResolvedProfile(
                    thinkingModelId: testAiModel().providerModelId,
                    thinkingProvider: testInferenceProvider(),
                    thinkingModel: testAiModel(),
                  ),
                ),
              ),
              templateForAgentProvider.overrideWith((ref, id) async => null),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(ProjectAgentSummaryCard));
        final trigger = find.byKey(const ValueKey('taskAgentWakeButton'));
        // A current report is worth no row at all — not even a
        // confirmation that nothing needs doing.
        expect(
          find.text(context.messages.taskAgentStatusUpToDate),
          findsNothing,
        );
        expect(
          find.text(context.messages.taskAgentStatusOutOfDate),
          stale ? findsOneWidget : findsNothing,
        );
        expect(trigger, stale ? findsOneWidget : findsNothing);

        if (stale) {
          await tester.tap(trigger);
          expect(refreshes, 1);
        }
      },
    );
  }

  testWidgets(
    'a report with no separate summary still counts as content',
    (tester) async {
      // `hasReportContent` reads the summary first and the report body
      // second; a project whose agent wrote only a body must still be able
      // to say that body is out of date.
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: ProjectAgentSummaryCard(
              projectId: 'project-1',
              record: makeTestProjectRecord(
                aiSummary: '',
                reportContent: 'Launch is on track.',
              ),
              identity: makeIdentity(),
              hasProjectAgent: true,
              isMutating: false,
              onRefresh: () {},
            ),
          ),
          overrides: [
            agentReportProvider.overrideWith(
              (ref, id) async => makeTestReport(agentId: id),
            ),
            agentIdentityProvider.overrideWith((ref, id) async => null),
            agentStateProvider.overrideWith(
              (ref, id) async => makeTestState(agentId: id).copyWith(
                reportStaleAt: DateTime(2026, 9, 4, 12),
                reportFreshAt: DateTime(2026, 9, 4, 11),
              ),
            ),
            agentIsRunningProvider.overrideWith(
              (ref, id) => Stream.value(false),
            ),
            taskAgentResolvedSetupProvider.overrideWith(
              (ref, id) async => ResolvedAgentSetup(
                status: AgentSetupResolutionStatus.resolved,
                profile: ResolvedProfile(
                  thinkingModelId: testAiModel().providerModelId,
                  thinkingProvider: testInferenceProvider(),
                  thinkingModel: testAiModel(),
                ),
              ),
            ),
            templateForAgentProvider.overrideWith((ref, id) async => null),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ProjectAgentSummaryCard));
      expect(
        find.text(context.messages.taskAgentStatusOutOfDate),
        findsOneWidget,
      );
    },
  );

  testWidgets('offers chat as the header disc, as a task card does', (
    tester,
  ) async {
    final record = makeTestProjectRecord(
      aiSummary: 'Review the feeder task before launch.',
    );
    const scope = QueryScope(
      kind: QueryScopeKind.project,
      id: 'project-1',
    );

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: ProjectAgentSummaryCard(
            projectId: 'project-1',
            record: record,
            identity: null,
            hasProjectAgent: true,
            isMutating: false,
          ),
        ),
        overrides: [queryChatEnabledProvider.overrideWithValue(true)],
      ),
    );
    await tester.pump();

    // One chat entry, and it is the header's trailing disc — not a labelled
    // button under the summary.
    expect(find.byType(QueryAskButton), findsOneWidget);
    final header = tester.widget<TldrHeader>(find.byType(TldrHeader));
    final ask = header.trailing! as QueryAskButton;
    expect(ask.disc, isTrue);
    expect(ask.scope, scope);
    final context = tester.element(find.byType(ProjectAgentSummaryCard));
    expect(find.text(context.messages.queryAskProject), findsNothing);

    await tester.tap(find.byType(DsAiDiscButton));
    await tester.pump();
    expect(
      ProviderScope.containerOf(context).read(queryPaneOpenProvider(scope)),
      isTrue,
    );
  });

  testWidgets('keeps chat beside the assignment row before an agent exists', (
    tester,
  ) async {
    const scope = QueryScope(
      kind: QueryScopeKind.project,
      id: 'project-1',
    );
    Future<void> pumpCard({required bool chatEnabled}) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Scaffold(
            body: ProjectAgentSummaryCard(
              projectId: 'project-1',
              record: makeTestProjectRecord(),
              identity: null,
              hasProjectAgent: false,
              isMutating: false,
              onAssignAgent: () async {},
            ),
          ),
          overrides: [
            queryChatEnabledProvider.overrideWithValue(chatEnabled),
          ],
        ),
      );
      await tester.pump();
    }

    await pumpCard(chatEnabled: false);
    expect(find.byType(QueryAskButton), findsNothing);

    await pumpCard(chatEnabled: true);
    final context = tester.element(find.byType(ProjectAgentSummaryCard));
    expect(
      find.text(context.messages.taskFirstRunAssignAgent),
      findsOneWidget,
    );
    final disc = tester.getRect(find.byType(DsAiDiscButton));
    final assign = tester.getRect(
      find.text(context.messages.taskFirstRunAssignAgent),
    );
    expect(disc.left, greaterThan(assign.right));

    await tester.tap(find.byType(DsAiDiscButton));
    await tester.pump();
    expect(
      ProviderScope.containerOf(context).read(queryPaneOpenProvider(scope)),
      isTrue,
    );
  });

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
}
