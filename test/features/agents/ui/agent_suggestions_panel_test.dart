import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/ui/agent_suggestions_panel.dart';
import 'package:lotti/features/agents/ui/suggestion_row.dart';
import 'package:lotti/features/agents/ui/task_agent_report_section.dart';
import 'package:lotti/features/agents/ui/time_entry_tile.dart';
import 'package:lotti/utils/consts.dart';
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

  late MockChangeSetConfirmationService mockConfirmation;
  late MockUpdateNotifications mockUpdates;

  const taskId = 'task-panel';

  setUp(() async {
    mockConfirmation = MockChangeSetConfirmationService();
    mockUpdates = MockUpdateNotifications();
    when(() => mockUpdates.notify(any())).thenReturn(null);
    await setUpTestGetIt();
  });

  tearDown(tearDownTestGetIt);

  PendingSuggestion pendingSuggestion({
    required String toolName,
    required Map<String, dynamic> args,
    required String humanSummary,
    String changeSetId = 'cs-1',
    int itemIndex = 0,
  }) {
    final item = ChangeItem(
      toolName: toolName,
      args: args,
      humanSummary: humanSummary,
    );
    return PendingSuggestion(
      changeSet: makeTestChangeSet(
        id: changeSetId,
        taskId: taskId,
        items: [item],
      ),
      itemIndex: itemIndex,
      item: item,
      fingerprint: ChangeItem.fingerprintFromParts(toolName, args),
    );
  }

  LedgerEntry ledgerEntry({
    required ChangeItemStatus status,
    required String humanSummary,
    required DateTime createdAt,
    String? reason,
    String toolName = 'set_task_priority',
    Map<String, dynamic> args = const {'priority': 'P1'},
    String changeSetId = 'cs-history',
    int itemIndex = 0,
  }) {
    return LedgerEntry(
      changeSetId: changeSetId,
      itemIndex: itemIndex,
      toolName: toolName,
      args: args,
      humanSummary: humanSummary,
      fingerprint: ChangeItem.fingerprintFromParts(toolName, args),
      status: status,
      createdAt: createdAt,
      resolvedAt: createdAt,
      verdict: switch (status) {
        ChangeItemStatus.confirmed => ChangeDecisionVerdict.confirmed,
        ChangeItemStatus.rejected => ChangeDecisionVerdict.rejected,
        ChangeItemStatus.retracted => ChangeDecisionVerdict.retracted,
        _ => null,
      },
      resolvedBy: status == ChangeItemStatus.retracted
          ? DecisionActor.agent
          : DecisionActor.user,
      reason: reason,
    );
  }

  Widget buildPanel({required UnifiedSuggestionList list}) {
    return makeTestableWidgetWithScaffold(
      const AgentSuggestionsPanel(taskId: taskId),
      overrides: [
        configFlagProvider(enableAgentsFlag).overrideWith(
          (ref) => Stream<bool>.value(false),
        ),
        taskAgentProvider(taskId).overrideWith((ref) async => null),
        unifiedSuggestionListProvider(taskId).overrideWith((ref) async => list),
        changeSetConfirmationServiceProvider.overrideWithValue(
          mockConfirmation,
        ),
        updateNotificationsProvider.overrideWithValue(mockUpdates),
      ],
    );
  }

  group('AgentSuggestionsPanel', () {
    testWidgets(
      'renders the TaskAgentReportSection host even when ledger is empty',
      (tester) async {
        await tester.pumpWidget(
          buildPanel(list: const UnifiedSuggestionList.empty()),
        );
        await _pumpUi(tester);

        expect(find.byType(AgentSuggestionsPanel), findsOneWidget);
        // The header section is always present (it owns the create-agent
        // CTA and the run-now / countdown controls).
        expect(find.byType(TaskAgentReportSection), findsOneWidget);
        // No open-suggestions list renders when the ledger is empty.
        expect(find.text('Proposed changes'), findsNothing);
        expect(find.byType(SuggestionRow), findsNothing);
      },
    );

    testWidgets(
      'renders a SuggestionRow per open pending item with the pending badge',
      (tester) async {
        final suggestion1 = pendingSuggestion(
          toolName: 'update_task_priority',
          args: const {'priority': 'P1'},
          humanSummary: 'Set priority to P1',
          changeSetId: 'cs-a',
        );
        final suggestion2 = pendingSuggestion(
          toolName: 'set_task_title',
          args: const {'title': 'Fix bug'},
          humanSummary: 'Rename task to "Fix bug"',
          changeSetId: 'cs-b',
        );

        await tester.pumpWidget(
          buildPanel(
            list: UnifiedSuggestionList(
              open: [suggestion1, suggestion2],
              activity: const [],
            ),
          ),
        );
        await _pumpUi(tester);

        expect(find.text('Proposed changes'), findsOneWidget);
        expect(find.text('2 pending'), findsOneWidget);
        expect(find.byType(SuggestionRow), findsNWidgets(2));
        expect(find.text('Set priority to P1'), findsOneWidget);
        expect(find.text('Rename task to "Fix bug"'), findsOneWidget);
      },
    );

    testWidgets(
      'swipe-right on a SuggestionRow dispatches confirmItem with the right '
      '(changeSet, index) tuple',
      (tester) async {
        final suggestion = pendingSuggestion(
          toolName: 'update_task_priority',
          args: const {'priority': 'P1'},
          humanSummary: 'Set priority to P1',
          changeSetId: 'cs-confirm',
        );
        when(() => mockConfirmation.confirmItem(any(), any())).thenAnswer(
          (_) async => const ToolExecutionResult(
            success: true,
            output: 'ok',
            mutatedEntityId: taskId,
          ),
        );

        await tester.pumpWidget(
          buildPanel(
            list: UnifiedSuggestionList(
              open: [suggestion],
              activity: const [],
            ),
          ),
        );
        await _pumpUi(tester);

        await tester.drag(
          find.text('Set priority to P1'),
          const Offset(400, 0),
        );
        await _pumpUi(tester);

        final captured = verify(
          () => mockConfirmation.confirmItem(captureAny(), captureAny()),
        ).captured;
        expect(captured[0], isA<ChangeSetEntity>());
        expect((captured[0] as ChangeSetEntity).id, 'cs-confirm');
        expect(captured[1], equals(0));
        verify(
          () => mockUpdates.notify({suggestion.changeSet.agentId}),
        ).called(1);
      },
    );

    testWidgets(
      'swipe-left on a SuggestionRow dispatches rejectItem',
      (tester) async {
        final suggestion = pendingSuggestion(
          toolName: 'set_task_title',
          args: const {'title': 'New title'},
          humanSummary: 'Rename task to "New title"',
          changeSetId: 'cs-reject',
        );
        when(
          () => mockConfirmation.rejectItem(any(), any()),
        ).thenAnswer((_) async => true);

        await tester.pumpWidget(
          buildPanel(
            list: UnifiedSuggestionList(
              open: [suggestion],
              activity: const [],
            ),
          ),
        );
        await _pumpUi(tester);

        await tester.drag(
          find.text('Rename task to "New title"'),
          const Offset(-400, 0),
        );
        await _pumpUi(tester);

        final captured = verify(
          () => mockConfirmation.rejectItem(captureAny(), captureAny()),
        ).captured;
        expect((captured[0] as ChangeSetEntity).id, 'cs-reject');
        expect(captured[1], equals(0));
      },
    );

    testWidgets(
      'create_time_entry item renders TimeEntryTile instead of the generic tile',
      (tester) async {
        final suggestion = pendingSuggestion(
          toolName: 'create_time_entry',
          args: const {
            'startTime': '2026-04-18T10:00:00',
            'endTime': '2026-04-18T11:00:00',
            'summary': 'Pair on migration',
          },
          humanSummary: 'Log time entry',
          changeSetId: 'cs-time',
        );

        await tester.pumpWidget(
          buildPanel(
            list: UnifiedSuggestionList(
              open: [suggestion],
              activity: const [],
            ),
          ),
        );
        await _pumpUi(tester);

        expect(find.byType(TimeEntryTile), findsOneWidget);
        expect(find.text('10:00'), findsOneWidget);
        expect(find.text('11:00'), findsOneWidget);
        expect(find.text('Pair on migration'), findsOneWidget);
      },
    );

    testWidgets(
      'confirm success with a warning message shows the warning snackbar',
      (tester) async {
        final suggestion = pendingSuggestion(
          toolName: 'update_task_priority',
          args: const {'priority': 'P1'},
          humanSummary: 'Set priority to P1',
          changeSetId: 'cs-warn',
        );
        when(() => mockConfirmation.confirmItem(any(), any())).thenAnswer(
          (_) async => const ToolExecutionResult(
            success: true,
            output: 'ok',
            errorMessage: 'partial issue',
            mutatedEntityId: taskId,
          ),
        );

        await tester.pumpWidget(
          buildPanel(
            list: UnifiedSuggestionList(
              open: [suggestion],
              activity: const [],
            ),
          ),
        );
        await _pumpUi(tester);

        await tester.drag(
          find.text('Set priority to P1'),
          const Offset(400, 0),
        );
        await _pumpUi(tester);

        expect(find.textContaining('partial issue'), findsOneWidget);
      },
    );

    testWidgets(
      'confirm returning success=false surfaces the error snackbar',
      (tester) async {
        final suggestion = pendingSuggestion(
          toolName: 'set_task_title',
          args: const {'title': 'New'},
          humanSummary: 'Rename to "New"',
          changeSetId: 'cs-failure',
        );
        when(() => mockConfirmation.confirmItem(any(), any())).thenAnswer(
          (_) async => const ToolExecutionResult(
            success: false,
            output: 'failed',
            errorMessage: 'dispatch failed',
          ),
        );

        await tester.pumpWidget(
          buildPanel(
            list: UnifiedSuggestionList(
              open: [suggestion],
              activity: const [],
            ),
          ),
        );
        await _pumpUi(tester);

        await tester.drag(
          find.text('Rename to "New"'),
          const Offset(400, 0),
        );
        await _pumpUi(tester);

        expect(find.text('Failed to apply change'), findsOneWidget);
      },
    );

    testWidgets(
      'confirm that throws is caught and surfaces the error snackbar',
      (tester) async {
        final suggestion = pendingSuggestion(
          toolName: 'set_task_title',
          args: const {'title': 'Crash'},
          humanSummary: 'Rename task (throws)',
          changeSetId: 'cs-throws',
        );
        when(() => mockConfirmation.confirmItem(any(), any())).thenThrow(
          StateError('boom'),
        );

        await tester.pumpWidget(
          buildPanel(
            list: UnifiedSuggestionList(
              open: [suggestion],
              activity: const [],
            ),
          ),
        );
        await _pumpUi(tester);

        await tester.drag(
          find.text('Rename task (throws)'),
          const Offset(400, 0),
        );
        await _pumpUi(tester);

        expect(find.text('Failed to apply change'), findsOneWidget);
      },
    );

    testWidgets(
      'reject returning false surfaces the error snackbar',
      (tester) async {
        final suggestion = pendingSuggestion(
          toolName: 'set_task_title',
          args: const {'title': 'Skip'},
          humanSummary: 'Rename (reject-skip)',
          changeSetId: 'cs-reject-skip',
        );
        when(
          () => mockConfirmation.rejectItem(any(), any()),
        ).thenAnswer((_) async => false);

        await tester.pumpWidget(
          buildPanel(
            list: UnifiedSuggestionList(
              open: [suggestion],
              activity: const [],
            ),
          ),
        );
        await _pumpUi(tester);

        await tester.drag(
          find.text('Rename (reject-skip)'),
          const Offset(-400, 0),
        );
        await _pumpUi(tester);

        expect(find.text('Failed to apply change'), findsOneWidget);
      },
    );

    testWidgets(
      'reject that throws is caught and surfaces the error snackbar',
      (tester) async {
        final suggestion = pendingSuggestion(
          toolName: 'set_task_title',
          args: const {'title': 'Kaboom'},
          humanSummary: 'Rename (reject-throws)',
          changeSetId: 'cs-reject-throws',
        );
        when(
          () => mockConfirmation.rejectItem(any(), any()),
        ).thenThrow(StateError('boom'));

        await tester.pumpWidget(
          buildPanel(
            list: UnifiedSuggestionList(
              open: [suggestion],
              activity: const [],
            ),
          ),
        );
        await _pumpUi(tester);

        await tester.drag(
          find.text('Rename (reject-throws)'),
          const Offset(-400, 0),
        );
        await _pumpUi(tester);

        expect(find.text('Failed to apply change'), findsOneWidget);
      },
    );

    testWidgets(
      'raw snake_case tool keys are not rendered in open suggestion rows',
      (tester) async {
        final suggestion = pendingSuggestion(
          toolName: 'add_checklist_item',
          args: const {'title': 'Buy milk'},
          humanSummary: 'Add checklist item: Buy milk',
          changeSetId: 'cs-declutter',
        );

        await tester.pumpWidget(
          buildPanel(
            list: UnifiedSuggestionList(
              open: [suggestion],
              activity: const [],
            ),
          ),
        );
        await _pumpUi(tester);

        expect(find.text('Add checklist item: Buy milk'), findsOneWidget);
        // The raw snake_case tool key must not leak into the tile.
        expect(find.text('add_checklist_item'), findsNothing);
      },
    );

    testWidgets(
      'Accept all confirms every distinct change set once and surfaces a '
      'success snackbar',
      (tester) async {
        final suggestion1 = pendingSuggestion(
          toolName: 'update_task_priority',
          args: const {'priority': 'P1'},
          humanSummary: 'Set priority to P1',
          changeSetId: 'cs-multi-a',
        );
        final suggestion2 = pendingSuggestion(
          toolName: 'set_task_title',
          args: const {'title': 'Fix bug'},
          humanSummary: 'Rename task to "Fix bug"',
          changeSetId: 'cs-multi-b',
        );
        when(() => mockConfirmation.confirmAll(any())).thenAnswer(
          (_) async => const [
            ToolExecutionResult(
              success: true,
              output: 'ok',
              mutatedEntityId: taskId,
            ),
          ],
        );

        await tester.pumpWidget(
          buildPanel(
            list: UnifiedSuggestionList(
              open: [suggestion1, suggestion2],
              activity: const [],
            ),
          ),
        );
        await _pumpUi(tester);

        expect(find.text('Confirm all'), findsOneWidget);

        await tester.tap(find.text('Confirm all'));
        await _pumpUi(tester);

        final captured = verify(
          () => mockConfirmation.confirmAll(captureAny()),
        ).captured;
        // One call per distinct change set.
        expect(captured, hasLength(2));
        expect(
          captured.map((cs) => (cs as ChangeSetEntity).id).toSet(),
          {'cs-multi-a', 'cs-multi-b'},
        );
        verify(() => mockUpdates.notify(any())).called(1);
        expect(find.text('Change applied'), findsOneWidget);
      },
    );

    testWidgets(
      'Accept all is hidden when only one open suggestion is pending',
      (tester) async {
        final suggestion = pendingSuggestion(
          toolName: 'set_task_title',
          args: const {'title': 'Fix bug'},
          humanSummary: 'Rename task to "Fix bug"',
          changeSetId: 'cs-single',
        );

        await tester.pumpWidget(
          buildPanel(
            list: UnifiedSuggestionList(
              open: [suggestion],
              activity: const [],
            ),
          ),
        );
        await _pumpUi(tester);

        expect(find.text('Confirm all'), findsNothing);
      },
    );

    testWidgets(
      'Accept all surfaces the error snackbar when any confirmAll fails',
      (tester) async {
        final suggestion1 = pendingSuggestion(
          toolName: 'update_task_priority',
          args: const {'priority': 'P1'},
          humanSummary: 'Set priority to P1',
          changeSetId: 'cs-fail-a',
        );
        final suggestion2 = pendingSuggestion(
          toolName: 'set_task_title',
          args: const {'title': 'Fix bug'},
          humanSummary: 'Rename task to "Fix bug"',
          changeSetId: 'cs-fail-b',
        );
        when(() => mockConfirmation.confirmAll(any())).thenAnswer(
          (_) async => const [
            ToolExecutionResult(
              success: false,
              output: 'nope',
              errorMessage: 'boom',
            ),
          ],
        );

        await tester.pumpWidget(
          buildPanel(
            list: UnifiedSuggestionList(
              open: [suggestion1, suggestion2],
              activity: const [],
            ),
          ),
        );
        await _pumpUi(tester);

        await tester.tap(find.text('Confirm all'));
        await _pumpUi(tester);

        expect(find.text('Failed to apply change'), findsOneWidget);
      },
    );

    testWidgets(
      'Accept all that throws surfaces the error snackbar and re-enables',
      (tester) async {
        final suggestion1 = pendingSuggestion(
          toolName: 'update_task_priority',
          args: const {'priority': 'P1'},
          humanSummary: 'Set priority to P1',
          changeSetId: 'cs-throw-a',
        );
        final suggestion2 = pendingSuggestion(
          toolName: 'set_task_title',
          args: const {'title': 'Fix bug'},
          humanSummary: 'Rename task to "Fix bug"',
          changeSetId: 'cs-throw-b',
        );
        when(() => mockConfirmation.confirmAll(any())).thenThrow(
          StateError('boom'),
        );

        await tester.pumpWidget(
          buildPanel(
            list: UnifiedSuggestionList(
              open: [suggestion1, suggestion2],
              activity: const [],
            ),
          ),
        );
        await _pumpUi(tester);

        await tester.tap(find.text('Confirm all'));
        await _pumpUi(tester);

        expect(find.text('Failed to apply change'), findsOneWidget);
      },
    );

    testWidgets(
      'activity strip is hidden entirely when the activity list is empty',
      (tester) async {
        final suggestion = pendingSuggestion(
          toolName: 'set_task_title',
          args: const {'title': 'Fix bug'},
          humanSummary: 'Rename task to "Fix bug"',
          changeSetId: 'cs-only-open',
        );

        await tester.pumpWidget(
          buildPanel(
            list: UnifiedSuggestionList(
              open: [suggestion],
              activity: const [],
            ),
          ),
        );
        await _pumpUi(tester);

        expect(find.text('Recent activity'), findsNothing);
      },
    );

    testWidgets(
      'activity strip renders a single retracted entry with the reason '
      'tooltip exposed via the info icon',
      (tester) async {
        final retracted = ledgerEntry(
          status: ChangeItemStatus.retracted,
          humanSummary: 'Withdraw add_checklist_item for "Buy milk"',
          createdAt: DateTime(2026, 4, 17, 9),
          reason: 'Duplicate of an existing checklist item',
        );

        await tester.pumpWidget(
          buildPanel(
            list: UnifiedSuggestionList(
              open: const [],
              activity: [retracted],
            ),
          ),
        );
        await _pumpUi(tester);

        expect(find.text('Recent activity'), findsOneWidget);
        expect(
          find.text('Withdraw add_checklist_item for "Buy milk"'),
          findsOneWidget,
        );
        // The reason is not displayed as text — it lives behind the i-icon.
        expect(
          find.text('Duplicate of an existing checklist item'),
          findsNothing,
        );
        // The undo verdict icon is present for retracted entries.
        expect(find.byIcon(Icons.undo), findsOneWidget);
        // The info icon opens the reason tooltip on tap.
        final infoIcon = find.byIcon(Icons.info_outline);
        expect(infoIcon, findsOneWidget);

        await tester.tap(infoIcon);
        await tester.pump(const Duration(milliseconds: 100));
        expect(
          find.text('Duplicate of an existing checklist item'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'activity strip renders verdict icons for confirmed and rejected '
      'entries and omits the info icon when no reason is attached',
      (tester) async {
        final confirmed = ledgerEntry(
          status: ChangeItemStatus.confirmed,
          humanSummary: 'Confirmed: Set priority to P1',
          createdAt: DateTime(2026, 4, 17, 12),
        );
        final rejected = ledgerEntry(
          status: ChangeItemStatus.rejected,
          humanSummary: 'Rejected: Rename task',
          createdAt: DateTime(2026, 4, 17, 11),
          reason: 'Keep original title',
        );

        await tester.pumpWidget(
          buildPanel(
            list: UnifiedSuggestionList(
              open: const [],
              activity: [confirmed, rejected],
            ),
          ),
        );
        await _pumpUi(tester);

        expect(find.byIcon(Icons.check), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);
        // Only the rejected row carries a reason, so exactly one i-icon.
        expect(find.byIcon(Icons.info_outline), findsOneWidget);
      },
    );

    testWidgets(
      'activity strip preserves newest-first order and caps at three rows '
      'when collapsed',
      (tester) async {
        final entries = [
          ledgerEntry(
            status: ChangeItemStatus.confirmed,
            humanSummary: 'Newest entry',
            createdAt: DateTime(2026, 4, 17, 15),
          ),
          ledgerEntry(
            status: ChangeItemStatus.rejected,
            humanSummary: 'Middle entry',
            createdAt: DateTime(2026, 4, 17, 14),
          ),
          ledgerEntry(
            status: ChangeItemStatus.retracted,
            humanSummary: 'Third entry',
            createdAt: DateTime(2026, 4, 17, 13),
          ),
          ledgerEntry(
            status: ChangeItemStatus.confirmed,
            humanSummary: 'Oldest entry (must be hidden when collapsed)',
            createdAt: DateTime(2026, 4, 17, 12),
          ),
        ];

        await tester.pumpWidget(
          buildPanel(
            list: UnifiedSuggestionList(open: const [], activity: entries),
          ),
        );
        await _pumpUi(tester);

        expect(find.text('Newest entry'), findsOneWidget);
        expect(find.text('Middle entry'), findsOneWidget);
        expect(find.text('Third entry'), findsOneWidget);
        // Fourth entry is hidden behind the collapse.
        expect(
          find.text('Oldest entry (must be hidden when collapsed)'),
          findsNothing,
        );

        // Display order matches source order (newest-first).
        final newestY = tester.getTopLeft(find.text('Newest entry')).dy;
        final middleY = tester.getTopLeft(find.text('Middle entry')).dy;
        final thirdY = tester.getTopLeft(find.text('Third entry')).dy;
        expect(newestY, lessThan(middleY));
        expect(middleY, lessThan(thirdY));
      },
    );

    testWidgets(
      'activity strip expands to reveal every entry and collapses back',
      (tester) async {
        final entries = [
          for (var i = 0; i < 5; i++)
            ledgerEntry(
              status: ChangeItemStatus.confirmed,
              humanSummary: 'Entry $i',
              createdAt: DateTime(2026, 4, 17, 15 - i),
            ),
        ];

        await tester.pumpWidget(
          buildPanel(
            list: UnifiedSuggestionList(open: const [], activity: entries),
          ),
        );
        await _pumpUi(tester);

        // Collapsed state: three visible, remainder hidden, chevron down.
        expect(find.text('Entry 0'), findsOneWidget);
        expect(find.text('Entry 1'), findsOneWidget);
        expect(find.text('Entry 2'), findsOneWidget);
        expect(find.text('Entry 3'), findsNothing);
        expect(find.text('Entry 4'), findsNothing);
        expect(find.byIcon(Icons.expand_more), findsOneWidget);
        expect(find.byIcon(Icons.expand_less), findsNothing);
        // Collapsed header shows visible/total counter.
        expect(find.text('3 of 5'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.expand_more));
        await _pumpUi(tester);

        // Expanded state: every entry visible, chevron flips, counter
        // switches to total.
        expect(find.text('Entry 3'), findsOneWidget);
        expect(find.text('Entry 4'), findsOneWidget);
        expect(find.byIcon(Icons.expand_less), findsOneWidget);
        expect(find.byIcon(Icons.expand_more), findsNothing);
        expect(find.text('5 total'), findsOneWidget);

        // Tapping again collapses back to three.
        await tester.tap(find.byIcon(Icons.expand_less));
        await _pumpUi(tester);
        expect(find.text('Entry 3'), findsNothing);
        expect(find.text('Entry 4'), findsNothing);
        expect(find.text('3 of 5'), findsOneWidget);
      },
    );

    testWidgets(
      'activity strip hides the expand toggle when there are at most three '
      'entries',
      (tester) async {
        final entries = [
          for (var i = 0; i < 3; i++)
            ledgerEntry(
              status: ChangeItemStatus.confirmed,
              humanSummary: 'Entry $i',
              createdAt: DateTime(2026, 4, 17, 15 - i),
            ),
        ];

        await tester.pumpWidget(
          buildPanel(
            list: UnifiedSuggestionList(open: const [], activity: entries),
          ),
        );
        await _pumpUi(tester);

        expect(find.byIcon(Icons.expand_more), findsNothing);
        expect(find.byIcon(Icons.expand_less), findsNothing);
      },
    );
  });
}
