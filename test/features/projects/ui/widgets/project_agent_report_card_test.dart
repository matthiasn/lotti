import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';
import 'package:lotti/features/projects/ui/widgets/project_agent_report_card.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  const projectId = 'proj-agent-1';

  final testAgent =
      AgentDomainEntity.agent(
            id: 'agent-1',
            agentId: 'agent-1',
            kind: 'project_agent',
            displayName: 'My Project Agent',
            lifecycle: AgentLifecycle.active,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state-1',
            config: const AgentConfig(),
            createdAt: DateTime(2024, 3, 15),
            updatedAt: DateTime(2024, 3, 15),
            vectorClock: null,
          )
          as AgentIdentityEntity;

  setUpAll(registerAllFallbackValues);

  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  group('ProjectAgentReportCard', () {
    testWidgets('shows nothing when loading', (tester) async {
      final completer = Completer<AgentDomainEntity?>();

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProjectAgentReportCard(projectId: projectId),
          overrides: [
            projectAgentProvider(projectId).overrideWith(
              (ref) => completer.future,
            ),
          ],
        ),
      );
      await tester.pump();

      // Loading state renders SizedBox.shrink — verify no agent content
      expect(find.text('My Project Agent'), findsNothing);
      expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
    });

    testWidgets('shows nothing when error', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProjectAgentReportCard(projectId: projectId),
          overrides: [
            projectAgentProvider(projectId).overrideWith(
              (ref) => Future<AgentDomainEntity?>.error(
                Exception('test error'),
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Agent'), findsNothing);
    });

    testWidgets('shows nothing when data is null', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProjectAgentReportCard(projectId: projectId),
          overrides: [
            projectAgentProvider(projectId).overrideWith(
              (ref) async => null,
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Agent'), findsNothing);
    });

    testWidgets('shows agent display name when data is AgentIdentityEntity', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProjectAgentReportCard(projectId: projectId),
          overrides: [
            projectAgentProvider(projectId).overrideWith(
              (ref) async => testAgent,
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Agent'), findsOneWidget);
      expect(find.text('My Project Agent'), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy_outlined), findsWidgets);
    });

    testWidgets(
      'shows accepted next steps from confirmed recommendation decisions',
      (
        tester,
      ) async {
        final mockRepository = MockAgentRepository();
        final updateController = StreamController<Set<String>>.broadcast();
        addTearDown(updateController.close);
        final decision =
            AgentDomainEntity.changeDecision(
                  id: 'decision-001',
                  agentId: 'agent-1',
                  changeSetId: 'change-set-001',
                  itemIndex: 0,
                  toolName: ProjectAgentToolNames.recommendNextSteps,
                  verdict: ChangeDecisionVerdict.confirmed,
                  taskId: projectId,
                  humanSummary: 'Recommend 2 next step(s)',
                  args: const {
                    'steps': [
                      {
                        'title': 'Unblock QA',
                        'rationale': 'Staging data is missing',
                        'priority': 'high',
                      },
                      {
                        'title': 'Write launch checklist',
                        'rationale': 'Avoid release drift',
                      },
                    ],
                  },
                  createdAt: DateTime(2024, 3, 16),
                  vectorClock: const VectorClock({}),
                )
                as ChangeDecisionEntity;

        when(
          () => mockRepository.getRecentDecisions(
            'agent-1',
            taskId: projectId,
          ),
        ).thenAnswer((_) async => [decision]);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            const ProjectAgentReportCard(projectId: projectId),
            overrides: [
              projectAgentProvider(projectId).overrideWith(
                (ref) async => testAgent,
              ),
              agentRepositoryProvider.overrideWithValue(mockRepository),
              agentUpdateStreamProvider('agent-1').overrideWith(
                (ref) => updateController.stream,
              ),
            ],
          ),
        );
        await tester.pump();

        expect(find.text('Accepted next steps'), findsOneWidget);
        expect(find.text('Unblock QA'), findsOneWidget);
        expect(find.text('Staging data is missing'), findsOneWidget);
        expect(find.text('High'), findsOneWidget);
        expect(find.text('Write launch checklist'), findsOneWidget);
        expect(find.text('Avoid release drift'), findsOneWidget);
      },
    );
  });
}
