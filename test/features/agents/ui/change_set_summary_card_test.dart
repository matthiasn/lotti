import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/ui/change_set_summary_card.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../test_utils.dart';

/// This file covers only the project-agent path. Task-agent suggestions
/// are rendered by `AgentSuggestionsPanel` + `SuggestionRow`, which have
/// their own dedicated tests.

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUpAll(registerAllFallbackValues);

  late MockChangeSetConfirmationService mockConfirmationService;
  late MockUpdateNotifications mockUpdateNotifications;

  setUp(() async {
    mockConfirmationService = MockChangeSetConfirmationService();
    mockUpdateNotifications = MockUpdateNotifications();

    when(() => mockUpdateNotifications.notify(any())).thenReturn(null);

    await setUpTestGetIt();
  });

  tearDown(tearDownTestGetIt);

  Widget buildProjectWidget({
    List<AgentDomainEntity> changeSets = const [],
  }) {
    return makeTestableWidgetWithScaffold(
      const ChangeSetSummaryCard.project(projectId: 'project-001'),
      overrides: [
        projectPendingChangeSetsProvider('project-001').overrideWith(
          (ref) async => changeSets,
        ),
        projectChangeSetConfirmationServiceProvider.overrideWithValue(
          mockConfirmationService,
        ),
        updateNotificationsProvider.overrideWithValue(mockUpdateNotifications),
      ],
    );
  }

  Future<void> pumpProjectCard(
    WidgetTester tester, {
    List<AgentDomainEntity> changeSets = const [],
  }) async {
    await tester.pumpWidget(buildProjectWidget(changeSets: changeSets));
    await _pumpUi(tester);
  }

  group('ChangeSetSummaryCard.project', () {
    testWidgets('renders nothing when change sets list is empty', (
      tester,
    ) async {
      await pumpProjectCard(tester);

      expect(find.byType(ChangeSetSummaryCard), findsOneWidget);
      expect(find.text('Proposed changes'), findsNothing);
    });

    testWidgets('swipe right confirms via project confirmation service', (
      tester,
    ) async {
      final changeSet = makeTestChangeSet(
        taskId: 'project-001',
        items: const [
          ChangeItem(
            toolName: 'update_project_status',
            args: {'status': 'active', 'reason': 'Momentum is good'},
            humanSummary: 'Update project status to active',
          ),
        ],
      );

      when(
        () => mockConfirmationService.confirmItem(any(), any()),
      ).thenAnswer(
        (_) async => const ToolExecutionResult(success: true, output: 'Done'),
      );

      await pumpProjectCard(tester, changeSets: [changeSet]);

      await tester.drag(
        find.text('Update project status to active'),
        const Offset(300, 0),
      );
      await _pumpUi(tester);

      verify(() => mockConfirmationService.confirmItem(changeSet, 0)).called(1);
      verify(() => mockUpdateNotifications.notify({'agent-001'})).called(1);
    });

    testWidgets('swipe left rejects via project confirmation service', (
      tester,
    ) async {
      final changeSet = makeTestChangeSet(
        agentId: 'agent-002',
        taskId: 'project-001',
        items: const [
          ChangeItem(
            toolName: 'update_project_status',
            args: {'status': 'on_hold', 'reason': 'Dependency blocked'},
            humanSummary: 'Update project status to on hold',
          ),
        ],
      );

      when(
        () => mockConfirmationService.rejectItem(
          any(),
          any(),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async => true);

      await pumpProjectCard(tester, changeSets: [changeSet]);

      await tester.drag(
        find.text('Update project status to on hold'),
        const Offset(-300, 0),
      );
      await _pumpUi(tester);

      verify(() => mockConfirmationService.rejectItem(changeSet, 0)).called(1);
      verify(() => mockUpdateNotifications.notify({'agent-002'})).called(1);
    });

    testWidgets(
      'Confirm All routes through project service and surfaces warnings',
      (tester) async {
        final changeSet = makeTestChangeSet(
          agentId: 'agent-003',
          taskId: 'project-001',
          items: const [
            ChangeItem(
              toolName: 'update_project_status',
              args: {'status': 'active'},
              humanSummary: 'Update project status to active',
            ),
            ChangeItem(
              toolName: 'create_task',
              args: {'title': 'Ship beta'},
              humanSummary: 'Create task "Ship beta"',
            ),
          ],
        );

        when(() => mockConfirmationService.confirmAll(any())).thenAnswer(
          (_) async => [
            const ToolExecutionResult(
              success: true,
              output: 'Done',
              errorMessage: 'Task agent could not be assigned',
            ),
            const ToolExecutionResult(success: true, output: 'Done'),
          ],
        );

        await pumpProjectCard(tester, changeSets: [changeSet]);

        await tester.tap(find.text('Confirm all'));
        await _pumpUi(tester);

        verify(() => mockConfirmationService.confirmAll(changeSet)).called(1);
        verify(() => mockUpdateNotifications.notify({'agent-003'})).called(1);
        expect(
          find.textContaining('1 item(s) had partial issues'),
          findsOneWidget,
        );
      },
    );
  });
}
