import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
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

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUpAll(registerAllFallbackValues);

  late MockChangeSetConfirmationService mockConfirmationService;
  late MockUpdateNotifications mockUpdateNotifications;

  const taskId = 'task-001';

  setUp(() async {
    mockConfirmationService = MockChangeSetConfirmationService();
    mockUpdateNotifications = MockUpdateNotifications();

    when(() => mockUpdateNotifications.notify(any())).thenReturn(null);

    await setUpTestGetIt();
  });

  tearDown(tearDownTestGetIt);

  Widget buildWidget({
    List<AgentDomainEntity> changeSets = const [],
  }) {
    return makeTestableWidgetWithScaffold(
      const ChangeSetSummaryCard(taskId: taskId),
      overrides: [
        pendingChangeSetsProvider(taskId).overrideWith(
          (ref) async => changeSets,
        ),
        changeSetConfirmationServiceProvider.overrideWithValue(
          mockConfirmationService,
        ),
        updateNotificationsProvider.overrideWithValue(mockUpdateNotifications),
      ],
    );
  }

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

  Future<void> pumpCard(
    WidgetTester tester, {
    List<AgentDomainEntity> changeSets = const [],
  }) async {
    await tester.pumpWidget(buildWidget(changeSets: changeSets));
    await _pumpUi(tester);
  }

  Future<void> pumpProjectCard(
    WidgetTester tester, {
    List<AgentDomainEntity> changeSets = const [],
  }) async {
    await tester.pumpWidget(buildProjectWidget(changeSets: changeSets));
    await _pumpUi(tester);
  }

  group('ChangeSetSummaryCard', () {
    testWidgets('renders nothing when change sets list is empty', (
      tester,
    ) async {
      await pumpCard(tester);

      expect(find.byType(ChangeSetSummaryCard), findsOneWidget);
      // Should render SizedBox.shrink when no change sets.
      expect(find.text('Proposed changes'), findsNothing);
    });

    testWidgets('renders card with title and item summaries', (tester) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Set estimate to 2 hours',
          ),
          ChangeItem(
            toolName: 'set_task_title',
            args: {'title': 'New Title'},
            humanSummary: 'Set title to "New Title"',
          ),
        ],
      );

      await pumpCard(tester, changeSets: [changeSet]);

      expect(find.text('Proposed changes'), findsOneWidget);
      expect(find.text('Set estimate to 2 hours'), findsOneWidget);
      expect(find.text('Set title to "New Title"'), findsOneWidget);
      expect(find.text('2 pending'), findsOneWidget);
    });

    testWidgets('no inline confirm/reject buttons on pending items', (
      tester,
    ) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Set estimate to 2 hours',
          ),
        ],
      );

      await pumpCard(tester, changeSets: [changeSet]);

      // Inline confirm/reject buttons should not exist; users swipe instead.
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
      expect(find.byIcon(Icons.cancel_outlined), findsNothing);
    });

    testWidgets('Confirm All button confirms all pending items', (
      tester,
    ) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Set estimate to 2 hours',
          ),
          ChangeItem(
            toolName: 'set_task_title',
            args: {'title': 'New'},
            humanSummary: 'Set title',
          ),
        ],
      );

      when(
        () => mockConfirmationService.confirmAll(any()),
      ).thenAnswer(
        (_) async => [
          const ToolExecutionResult(success: true, output: 'Done'),
          const ToolExecutionResult(success: true, output: 'Done'),
        ],
      );

      await pumpCard(tester, changeSets: [changeSet]);

      await tester.tap(find.text('Confirm all'));
      await _pumpUi(tester);

      verify(
        () => mockConfirmationService.confirmAll(changeSet),
      ).called(1);
    });

    testWidgets('resolved items are hidden from the list', (tester) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Confirmed item',
            status: ChangeItemStatus.confirmed,
          ),
          ChangeItem(
            toolName: 'set_task_title',
            args: {'title': 'Rejected'},
            humanSummary: 'Rejected item',
            status: ChangeItemStatus.rejected,
          ),
          ChangeItem(
            toolName: 'assign_task_label',
            args: {'label': 'urgent'},
            humanSummary: 'Still pending',
          ),
        ],
      );

      await pumpCard(tester, changeSets: [changeSet]);

      // Confirmed and rejected items should be hidden.
      expect(find.text('Confirmed item'), findsNothing);
      expect(find.text('Rejected item'), findsNothing);

      // Only the pending item is visible.
      expect(find.text('Still pending'), findsOneWidget);

      // Pending count badge shows 1.
      expect(find.text('1 pending'), findsOneWidget);

      // Confirm All button should appear (1 pending item).
      expect(find.text('Confirm all'), findsOneWidget);
    });

    testWidgets('shows error snackbar when confirm fails', (tester) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Will fail',
          ),
        ],
      );

      when(
        () => mockConfirmationService.confirmItem(any(), any()),
      ).thenThrow(Exception('Test error'));

      await pumpCard(tester, changeSets: [changeSet]);

      // Swipe right to confirm.
      await tester.drag(find.text('Will fail'), const Offset(300, 0));
      await _pumpUi(tester);

      expect(find.text('Failed to apply change'), findsOneWidget);
    });

    testWidgets('shows error snackbar when confirm returns failure result', (
      tester,
    ) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Will fail silently',
          ),
        ],
      );

      when(
        () => mockConfirmationService.confirmItem(any(), any()),
      ).thenAnswer(
        (_) async => const ToolExecutionResult(
          success: false,
          output: 'Task not found',
          errorMessage: 'Task lookup failed',
        ),
      );

      await pumpCard(tester, changeSets: [changeSet]);

      // Swipe right to confirm.
      await tester.drag(
        find.text('Will fail silently'),
        const Offset(300, 0),
      );
      await _pumpUi(tester);

      expect(find.text('Failed to apply change'), findsOneWidget);
    });

    testWidgets('shows error snackbar when reject fails', (tester) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Reject will fail',
          ),
        ],
      );

      when(
        () => mockConfirmationService.rejectItem(
          any(),
          any(),
          reason: any(named: 'reason'),
        ),
      ).thenThrow(Exception('Reject error'));

      await pumpCard(tester, changeSets: [changeSet]);

      // Swipe left to reject.
      await tester.drag(
        find.text('Reject will fail'),
        const Offset(-300, 0),
      );
      await _pumpUi(tester);

      expect(find.text('Failed to apply change'), findsOneWidget);
    });

    testWidgets('swipe right triggers confirm', (tester) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Swipe to confirm',
          ),
        ],
      );

      when(
        () => mockConfirmationService.confirmItem(any(), any()),
      ).thenAnswer(
        (_) async => const ToolExecutionResult(
          success: true,
          output: 'Done',
        ),
      );

      await pumpCard(tester, changeSets: [changeSet]);

      // Swipe right (startToEnd) on the item tile.
      await tester.drag(
        find.text('Swipe to confirm'),
        const Offset(300, 0),
      );
      await _pumpUi(tester);

      verify(
        () => mockConfirmationService.confirmItem(changeSet, 0),
      ).called(1);
    });

    testWidgets('swipe left triggers reject', (tester) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Swipe to reject',
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

      await pumpCard(tester, changeSets: [changeSet]);

      // Swipe left (endToStart) on the item tile.
      await tester.drag(
        find.text('Swipe to reject'),
        const Offset(-300, 0),
      );
      await _pumpUi(tester);

      verify(
        () => mockConfirmationService.rejectItem(changeSet, 0),
      ).called(1);
    });

    testWidgets('Confirm All shows warning snackbar when items have warnings', (
      tester,
    ) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Item with warning',
          ),
          ChangeItem(
            toolName: 'set_task_title',
            args: {'title': 'OK'},
            humanSummary: 'Clean item',
          ),
        ],
      );

      when(
        () => mockConfirmationService.confirmAll(any()),
      ).thenAnswer(
        (_) async => [
          const ToolExecutionResult(
            success: true,
            output: 'Done',
            errorMessage: 'Source item archival failed',
          ),
          const ToolExecutionResult(success: true, output: 'Done'),
        ],
      );

      await pumpCard(tester, changeSets: [changeSet]);

      await tester.tap(find.text('Confirm all'));
      await _pumpUi(tester);

      // Should show the warning snackbar, not the error one.
      expect(find.text('Failed to apply change'), findsNothing);
      expect(
        find.textContaining('1 item(s) had partial issues'),
        findsOneWidget,
      );
    });

    testWidgets(
      'confirm item shows warning snackbar when result has errorMessage',
      (tester) async {
        final changeSet = makeTestChangeSet(
          items: const [
            ChangeItem(
              toolName: 'update_task_estimate',
              args: {'minutes': 120},
              humanSummary: 'Has warning',
            ),
          ],
        );

        when(
          () => mockConfirmationService.confirmItem(any(), any()),
        ).thenAnswer(
          (_) async => const ToolExecutionResult(
            success: true,
            output: 'Migrated item',
            errorMessage: 'Source item archival failed',
          ),
        );

        await pumpCard(tester, changeSets: [changeSet]);

        // Swipe right to confirm.
        await tester.drag(find.text('Has warning'), const Offset(300, 0));
        await _pumpUi(tester);

        // Should show the warning message, not the generic error.
        expect(find.text('Failed to apply change'), findsNothing);
        expect(
          find.textContaining('Source item archival failed'),
          findsOneWidget,
        );
      },
    );

    testWidgets('reject shows error snackbar when rejectItem returns false', (
      tester,
    ) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Reject returns false',
          ),
        ],
      );

      when(
        () => mockConfirmationService.rejectItem(
          any(),
          any(),
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async => false);

      await pumpCard(tester, changeSets: [changeSet]);

      // Swipe left to reject.
      await tester.drag(
        find.text('Reject returns false'),
        const Offset(-300, 0),
      );
      await _pumpUi(tester);

      // When applied is false, the error snackbar is shown.
      expect(find.text('Failed to apply change'), findsOneWidget);
    });

    testWidgets('Confirm All shows error snackbar on partial failure', (
      tester,
    ) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Will succeed',
          ),
          ChangeItem(
            toolName: 'set_task_title',
            args: {'title': 'Fail'},
            humanSummary: 'Will fail',
          ),
        ],
      );

      when(
        () => mockConfirmationService.confirmAll(any()),
      ).thenAnswer(
        (_) async => [
          const ToolExecutionResult(success: true, output: 'Done'),
          const ToolExecutionResult(
            success: false,
            output: 'Task not found',
            errorMessage: 'Failed',
          ),
        ],
      );

      await pumpCard(tester, changeSets: [changeSet]);

      await tester.tap(find.text('Confirm all'));
      await _pumpUi(tester);

      expect(find.text('Failed to apply change'), findsOneWidget);
      verify(
        () => mockConfirmationService.confirmAll(changeSet),
      ).called(1);
    });

    testWidgets('Confirm All error shows snackbar', (tester) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 120},
            humanSummary: 'Will fail',
          ),
        ],
      );

      when(
        () => mockConfirmationService.confirmAll(any()),
      ).thenThrow(Exception('Confirm all failed'));

      await pumpCard(tester, changeSets: [changeSet]);

      await tester.tap(find.text('Confirm all'));
      await _pumpUi(tester);

      expect(find.text('Failed to apply change'), findsOneWidget);
    });

    testWidgets('project scope uses project confirmation service', (
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

      // Swipe right to confirm.
      await tester.drag(
        find.text('Update project status to active'),
        const Offset(300, 0),
      );
      await _pumpUi(tester);

      verify(
        () => mockConfirmationService.confirmItem(changeSet, 0),
      ).called(1);
      verify(() => mockUpdateNotifications.notify({'agent-001'})).called(1);
    });

    testWidgets('project scope reject uses project confirmation service', (
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

      // Swipe left to reject.
      await tester.drag(
        find.text('Update project status to on hold'),
        const Offset(-300, 0),
      );
      await _pumpUi(tester);

      verify(
        () => mockConfirmationService.rejectItem(changeSet, 0),
      ).called(1);
      verify(() => mockUpdateNotifications.notify({'agent-002'})).called(1);
    });

    testWidgets(
      'project scope confirm all routes through project service and shows warnings',
      (
        tester,
      ) async {
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

        when(
          () => mockConfirmationService.confirmAll(any()),
        ).thenAnswer(
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

        verify(
          () => mockConfirmationService.confirmAll(changeSet),
        ).called(1);
        verify(() => mockUpdateNotifications.notify({'agent-003'})).called(1);
        expect(
          find.textContaining('1 item(s) had partial issues'),
          findsOneWidget,
        );
      },
    );
  });

  group('create_time_entry tile', () {
    testWidgets('renders start and end times for completed session', (
      tester,
    ) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'create_time_entry',
            args: {
              'startTime': '2026-03-17T14:00:00',
              'endTime': '2026-03-17T15:30:00',
              'summary': 'Deep work on feature X [generated]',
            },
            humanSummary: 'Time entry 14:00–15:30: "Deep work on feature X"',
          ),
        ],
      );

      await pumpCard(tester, changeSets: [changeSet]);

      expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      expect(find.textContaining('14:00'), findsOneWidget);
      expect(find.textContaining('15:30'), findsOneWidget);
      expect(
        find.text('Deep work on feature X [generated]'),
        findsOneWidget,
      );
    });

    testWidgets('shows Running label when endTime is absent', (tester) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'create_time_entry',
            args: {
              'startTime': '2026-03-17T14:00:00',
              'summary': 'Started a timer [generated]',
            },
            humanSummary: 'Time entry from 14:00: "Started a timer"',
          ),
        ],
      );

      await pumpCard(tester, changeSets: [changeSet]);

      expect(find.textContaining('14:00'), findsOneWidget);
      expect(find.textContaining('Running'), findsOneWidget);
    });

    testWidgets('falls back to raw string when startTime is unparseable', (
      tester,
    ) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'create_time_entry',
            args: {
              'startTime': 'not-a-date',
              'summary': 'Some work [generated]',
            },
            humanSummary: 'Time entry from not-a-date',
          ),
        ],
      );

      await pumpCard(tester, changeSets: [changeSet]);

      // Raw unparseable string is shown as-is.
      expect(find.textContaining('not-a-date'), findsOneWidget);
    });

    testWidgets('shows raw endTime when it is present but unparseable', (
      tester,
    ) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'create_time_entry',
            args: {
              'startTime': '2026-03-17T10:00:00',
              'endTime': 'later',
              'summary': 'Some work [generated]',
            },
            humanSummary: 'Time entry 10:00–later',
          ),
        ],
      );

      await pumpCard(tester, changeSets: [changeSet]);

      expect(find.textContaining('10:00'), findsOneWidget);
      expect(find.textContaining('later'), findsOneWidget);
      expect(find.textContaining('Running'), findsNothing);
    });

    testWidgets('renders without summary text when summary is empty', (
      tester,
    ) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'create_time_entry',
            args: {
              'startTime': '2026-03-17T10:00:00',
              'endTime': '2026-03-17T11:00:00',
              'summary': '',
            },
            humanSummary: 'Time entry 10:00–11:00',
          ),
        ],
      );

      await pumpCard(tester, changeSets: [changeSet]);

      expect(find.textContaining('10:00'), findsOneWidget);
      expect(find.textContaining('11:00'), findsOneWidget);
      // No body text widget when summary is empty.
      expect(find.text(''), findsNothing);
    });

    testWidgets('swipe right confirms time entry tile', (tester) async {
      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'create_time_entry',
            args: {
              'startTime': '2026-03-17T09:00:00',
              'endTime': '2026-03-17T10:00:00',
              'summary': 'Morning standup [generated]',
            },
            humanSummary: 'Time entry 09:00–10:00',
          ),
        ],
      );

      when(
        () => mockConfirmationService.confirmItem(any(), any()),
      ).thenAnswer(
        (_) async => const ToolExecutionResult(success: true, output: 'Done'),
      );

      await pumpCard(tester, changeSets: [changeSet]);

      // No inline confirm/reject buttons on time entry tiles.
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
      expect(find.byIcon(Icons.cancel_outlined), findsNothing);

      // Swipe right to confirm the time entry.
      await tester.drag(
        find.text('Morning standup [generated]'),
        const Offset(300, 0),
      );
      await _pumpUi(tester);

      verify(
        () => mockConfirmationService.confirmItem(changeSet, 0),
      ).called(1);
    });

    testWidgets('wraps time labels on narrow layouts', (tester) async {
      addTearDown(() => tester.view.resetPhysicalSize());
      addTearDown(() => tester.view.resetDevicePixelRatio());
      tester.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1;

      final changeSet = makeTestChangeSet(
        items: const [
          ChangeItem(
            toolName: 'create_time_entry',
            args: {
              'startTime': '2026-03-17T14:00:00',
              'summary': 'Started a timer [generated]',
            },
            humanSummary: 'Time entry from 14:00: "Started a timer"',
          ),
        ],
      );

      await pumpCard(tester, changeSets: [changeSet]);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Running'), findsOneWidget);
    });
  });
}
