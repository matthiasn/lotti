import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/change_set.dart';
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
  });
}
