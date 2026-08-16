import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_model_providers.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/tldr_section_part.dart';
import 'package:lotti/features/agents/ui/task_agent_controls_footer.dart';
import 'package:lotti/features/agents/ui/widgets/ai_card_chrome.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/features/projects/ui/widgets/project_agent_summary_card.dart';

import '../../../../widget_test_utils.dart';
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
          agentReportProvider.overrideWith((ref, id) async => null),
          agentStateProvider.overrideWith((ref, id) async => null),
          agentIsRunningProvider.overrideWith(
            (ref, id) => Stream.value(false),
          ),
          taskAgentResolvedSetupProvider.overrideWith(
            (ref, id) async => const ResolvedAgentSetup(
              status: AgentSetupResolutionStatus.disabled,
            ),
          ),
          templateForAgentProvider.overrideWith((ref, id) async => null),
        ],
      ),
    );
    await tester.pump();

    expect(find.byType(AgentSummaryCardSurface), findsOneWidget);
    expect(find.byType(TldrHeader), findsOneWidget);
    expect(find.byType(TldrBody), findsOneWidget);
    expect(find.byType(TaskAgentControlsFooter), findsOneWidget);
    expect(find.text('Project Agent'), findsOneWidget);
    expect(find.text('At Risk'), findsOneWidget);
    expect(find.text('Project agent decisions'), findsOneWidget);
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
