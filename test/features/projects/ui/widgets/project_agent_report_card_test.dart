import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/projects/ui/widgets/project_agent_report_card.dart';

import '../../../../helpers/fallbacks.dart';
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
  });
}
