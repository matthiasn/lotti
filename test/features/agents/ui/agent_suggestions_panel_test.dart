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

  // Convenience wrappers so individual tests only spell out the shape
  // they actually care about.
  Future<void> pumpWithOpen(
    WidgetTester tester,
    List<PendingSuggestion> open,
  ) async {
    await tester.pumpWidget(
      buildPanel(
        list: UnifiedSuggestionList(open: open, activity: const []),
      ),
    );
    await _pumpUi(tester);
  }

  Future<void> pumpWithActivity(
    WidgetTester tester,
    List<LedgerEntry> activity,
  ) async {
    await tester.pumpWidget(
      buildPanel(
        list: UnifiedSuggestionList(open: const [], activity: activity),
      ),
    );
    await _pumpUi(tester);
  }

  Future<void> expandActivityStrip(WidgetTester tester) async {
    await tester.tap(find.text('Recent proposal activity'));
    await _pumpUi(tester);
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

    // Shared priority-change suggestion used by the swipe / confirm / reject
    // tests below — the item content is not under test, only the dispatch.
    PendingSuggestion prioritySuggestion({String id = 'cs-generic'}) =>
        pendingSuggestion(
          toolName: 'update_task_priority',
          args: const {'priority': 'P1'},
          humanSummary: 'Set priority to P1',
          changeSetId: id,
        );

    PendingSuggestion titleSuggestion({
      String id = 'cs-generic',
      String title = 'New title',
      String summary = 'Rename task to "New title"',
    }) => pendingSuggestion(
      toolName: 'set_task_title',
      args: {'title': title},
      humanSummary: summary,
      changeSetId: id,
    );

    void stubConfirmItem({
      bool success = true,
      String? errorMessage,
      Object? throws,
    }) {
      if (throws != null) {
        when(
          () => mockConfirmation.confirmItem(any(), any()),
        ).thenThrow(throws);
        return;
      }
      when(() => mockConfirmation.confirmItem(any(), any())).thenAnswer(
        (_) async => ToolExecutionResult(
          success: success,
          output: success ? 'ok' : 'failed',
          errorMessage: errorMessage,
          mutatedEntityId: success ? taskId : null,
        ),
      );
    }

    void stubRejectItem({bool applied = true, Object? throws}) {
      if (throws != null) {
        when(
          () => mockConfirmation.rejectItem(any(), any()),
        ).thenThrow(throws);
        return;
      }
      when(
        () => mockConfirmation.rejectItem(any(), any()),
      ).thenAnswer((_) async => applied);
    }

    Future<void> swipeRight(WidgetTester tester, String summary) async {
      await tester.drag(find.text(summary), const Offset(400, 0));
      await _pumpUi(tester);
    }

    Future<void> swipeLeft(WidgetTester tester, String summary) async {
      await tester.drag(find.text(summary), const Offset(-400, 0));
      await _pumpUi(tester);
    }

    testWidgets(
      'swipe-right on a SuggestionRow dispatches confirmItem with the right '
      '(changeSet, index) tuple',
      (tester) async {
        final suggestion = prioritySuggestion(id: 'cs-confirm');
        stubConfirmItem();
        await pumpWithOpen(tester, [suggestion]);

        await swipeRight(tester, 'Set priority to P1');

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

    testWidgets('swipe-left on a SuggestionRow dispatches rejectItem', (
      tester,
    ) async {
      stubRejectItem();
      await pumpWithOpen(tester, [titleSuggestion(id: 'cs-reject')]);

      await swipeLeft(tester, 'Rename task to "New title"');

      final captured = verify(
        () => mockConfirmation.rejectItem(captureAny(), captureAny()),
      ).captured;
      expect((captured[0] as ChangeSetEntity).id, 'cs-reject');
      expect(captured[1], equals(0));
    });

    testWidgets(
      'create_time_entry item renders TimeEntryTile instead of the generic tile',
      (tester) async {
        await pumpWithOpen(tester, [
          pendingSuggestion(
            toolName: 'create_time_entry',
            args: const {
              'startTime': '2026-04-18T10:00:00',
              'endTime': '2026-04-18T11:00:00',
              'summary': 'Pair on migration',
            },
            humanSummary: 'Log time entry',
            changeSetId: 'cs-time',
          ),
        ]);

        expect(find.byType(TimeEntryTile), findsOneWidget);
        expect(find.text('10:00'), findsOneWidget);
        expect(find.text('11:00'), findsOneWidget);
        expect(find.text('Pair on migration'), findsOneWidget);
      },
    );

    testWidgets(
      'confirm success with a warning message shows the warning snackbar',
      (tester) async {
        stubConfirmItem(errorMessage: 'partial issue');
        await pumpWithOpen(tester, [prioritySuggestion(id: 'cs-warn')]);

        await swipeRight(tester, 'Set priority to P1');

        expect(find.textContaining('partial issue'), findsOneWidget);
      },
    );

    // The three confirm-failure paths (success=false, thrown, reject=false,
    // reject-throws) all surface the same snackbar and only differ in the
    // stub wiring — run them as a table to avoid four near-identical bodies.
    group('confirm/reject failure paths surface the error snackbar', () {
      final cases = <({String name, void Function() wire, bool reject})>[
        (
          name: 'confirm success=false',
          wire: () => stubConfirmItem(success: false),
          reject: false,
        ),
        (
          name: 'confirm throws',
          wire: () => stubConfirmItem(throws: StateError('boom')),
          reject: false,
        ),
        (
          name: 'reject returns false',
          wire: () => stubRejectItem(applied: false),
          reject: true,
        ),
        (
          name: 'reject throws',
          wire: () => stubRejectItem(throws: StateError('boom')),
          reject: true,
        ),
      ];
      for (final c in cases) {
        testWidgets(c.name, (tester) async {
          const summary = 'Rename task to "New title"';
          c.wire();
          await pumpWithOpen(tester, [titleSuggestion(id: 'cs-${c.name}')]);

          if (c.reject) {
            await swipeLeft(tester, summary);
          } else {
            await swipeRight(tester, summary);
          }

          expect(find.text('Failed to apply change'), findsOneWidget);
        });
      }
    });

    testWidgets(
      'raw snake_case tool keys are not rendered in open suggestion rows',
      (tester) async {
        await pumpWithOpen(tester, [
          pendingSuggestion(
            toolName: 'add_checklist_item',
            args: const {'title': 'Buy milk'},
            humanSummary: 'Add checklist item: Buy milk',
            changeSetId: 'cs-declutter',
          ),
        ]);

        expect(find.text('Add checklist item: Buy milk'), findsOneWidget);
        // The raw snake_case tool key must not leak into the tile.
        expect(find.text('add_checklist_item'), findsNothing);
      },
    );

    group('Confirm all', () {
      // Two open items spanning two distinct change sets — the shape
      // the bulk-confirm affordance is actually designed for.
      List<PendingSuggestion> multiSetOpen({String suffix = ''}) => [
        prioritySuggestion(id: 'cs-a$suffix'),
        titleSuggestion(
          id: 'cs-b$suffix',
          title: 'Fix bug',
          summary: 'Rename task to "Fix bug"',
        ),
      ];

      void stubConfirmAll({bool success = true, Object? throws}) {
        if (throws != null) {
          when(
            () => mockConfirmation.confirmAll(any()),
          ).thenThrow(throws);
          return;
        }
        when(() => mockConfirmation.confirmAll(any())).thenAnswer(
          (_) async => [
            ToolExecutionResult(
              success: success,
              output: success ? 'ok' : 'nope',
              errorMessage: success ? null : 'boom',
              mutatedEntityId: success ? taskId : null,
            ),
          ],
        );
      }

      Future<void> tapConfirmAll(WidgetTester tester) async {
        await tester.tap(find.text('Confirm all'));
        await _pumpUi(tester);
      }

      testWidgets(
        'confirms every distinct change set once and surfaces a '
        'success snackbar',
        (tester) async {
          stubConfirmAll();
          await pumpWithOpen(tester, multiSetOpen());

          expect(find.text('Confirm all'), findsOneWidget);
          await tapConfirmAll(tester);

          final captured = verify(
            () => mockConfirmation.confirmAll(captureAny()),
          ).captured;
          // One call per distinct change set.
          expect(captured, hasLength(2));
          expect(
            captured.map((cs) => (cs as ChangeSetEntity).id).toSet(),
            {'cs-a', 'cs-b'},
          );
          verify(() => mockUpdates.notify(any())).called(1);
          expect(find.text('Change applied'), findsOneWidget);
        },
      );

      testWidgets(
        'button is hidden when only one open suggestion is pending',
        (tester) async {
          await pumpWithOpen(tester, [titleSuggestion(id: 'cs-single')]);
          expect(find.text('Confirm all'), findsNothing);
        },
      );

      testWidgets('surfaces the error snackbar when any confirmAll fails', (
        tester,
      ) async {
        stubConfirmAll(success: false);
        await pumpWithOpen(tester, multiSetOpen(suffix: '-fail'));

        await tapConfirmAll(tester);

        expect(find.text('Failed to apply change'), findsOneWidget);
      });

      testWidgets(
        'that throws surfaces the error snackbar and still notifies so '
        'UI refreshes any partially-persisted sets',
        (tester) async {
          stubConfirmAll(throws: StateError('boom'));
          await pumpWithOpen(tester, multiSetOpen(suffix: '-throw'));

          await tapConfirmAll(tester);

          expect(find.text('Failed to apply change'), findsOneWidget);
          // Notify must fire even on throw so already-persisted change
          // sets don't linger in the open list after a partial success.
          verify(() => mockUpdates.notify(any())).called(1);
        },
      );
    });

    group('Recent proposal activity strip', () {
      testWidgets(
        'is hidden entirely when the activity list is empty',
        (tester) async {
          await pumpWithOpen(tester, [titleSuggestion(id: 'cs-only-open')]);
          expect(find.text('Recent proposal activity'), findsNothing);
        },
      );

      testWidgets(
        'starts fully collapsed, hiding every entry row behind a '
        'single-line label and count pill',
        (tester) async {
          await pumpWithActivity(tester, [
            ledgerEntry(
              status: ChangeItemStatus.retracted,
              humanSummary: 'Withdraw add_checklist_item for "Buy milk"',
              createdAt: DateTime(2026, 4, 17, 9),
              reason: 'Duplicate of an existing checklist item',
            ),
          ]);

          // Header label is always visible.
          expect(find.text('Recent proposal activity'), findsOneWidget);
          // Count pill shows total entries even when collapsed.
          expect(find.text('1'), findsOneWidget);
          // No entry rows are rendered in the collapsed state.
          expect(
            find.text('Withdraw add_checklist_item for "Buy milk"'),
            findsNothing,
          );
          expect(find.byIcon(Icons.undo), findsNothing);
          expect(find.byIcon(Icons.info_outline), findsNothing);
          // Chevron points down in the collapsed state.
          expect(find.byIcon(Icons.expand_more), findsOneWidget);
          expect(find.byIcon(Icons.expand_less), findsNothing);
        },
      );

      testWidgets(
        'expanding reveals a retracted entry with its verdict icon and '
        'tooltip-gated reason',
        (tester) async {
          await pumpWithActivity(tester, [
            ledgerEntry(
              status: ChangeItemStatus.retracted,
              humanSummary: 'Withdraw add_checklist_item for "Buy milk"',
              createdAt: DateTime(2026, 4, 17, 9),
              reason: 'Duplicate of an existing checklist item',
            ),
          ]);
          await expandActivityStrip(tester);

          expect(
            find.text('Withdraw add_checklist_item for "Buy milk"'),
            findsOneWidget,
          );
          // The reason remains hidden behind the info-icon tooltip
          // until the user taps it.
          expect(
            find.text('Duplicate of an existing checklist item'),
            findsNothing,
          );
          expect(find.byIcon(Icons.undo), findsOneWidget);
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
        'verdict-icon tooltip names the agent that retracted the proposal '
        "and appends the resolved timestamp in 'yyyy-MM-dd HH:mm' form",
        (tester) async {
          await tester.pumpWidget(
            buildPanel(
              list: UnifiedSuggestionList(
                open: const [],
                agentName: 'Laura',
                activity: [
                  ledgerEntry(
                    status: ChangeItemStatus.retracted,
                    humanSummary: 'Withdraw add_checklist_item',
                    createdAt: DateTime(2026, 4, 17, 9, 17),
                  ),
                ],
              ),
            ),
          );
          await _pumpUi(tester);
          await expandActivityStrip(tester);

          // Long-press the icon to surface the hover/long-press tooltip
          // on the touch-style trigger used in headless tests.
          final gesture = await tester.startGesture(
            tester.getCenter(find.byIcon(Icons.undo)),
          );
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pump();
          expect(
            find.text('Retracted by Laura · 2026-04-17 09:17'),
            findsOneWidget,
          );
          await gesture.up();
        },
      );

      testWidgets(
        'verdict-icon tooltip falls back to a generic noun when no agent '
        'name is attached',
        (tester) async {
          await tester.pumpWidget(
            buildPanel(
              list: UnifiedSuggestionList(
                open: const [],
                activity: [
                  ledgerEntry(
                    status: ChangeItemStatus.retracted,
                    humanSummary: 'Withdraw add_checklist_item',
                    createdAt: DateTime(2026, 4, 17, 9, 17),
                  ),
                ],
              ),
            ),
          );
          await _pumpUi(tester);
          await expandActivityStrip(tester);

          final gesture = await tester.startGesture(
            tester.getCenter(find.byIcon(Icons.undo)),
          );
          await tester.pump(const Duration(milliseconds: 600));
          await tester.pump();
          expect(
            find.text('Retracted by the agent · 2026-04-17 09:17'),
            findsOneWidget,
          );
          await gesture.up();
        },
      );

      testWidgets(
        'renders the correct verdict icon for every ChangeItemStatus and '
        'omits the info icon when no reason is attached',
        (tester) async {
          await pumpWithActivity(tester, [
            ledgerEntry(
              status: ChangeItemStatus.confirmed,
              humanSummary: 'Confirmed: Set priority to P1',
              createdAt: DateTime(2026, 4, 17, 12),
            ),
            ledgerEntry(
              status: ChangeItemStatus.rejected,
              humanSummary: 'Rejected: Rename task',
              createdAt: DateTime(2026, 4, 17, 11),
              reason: 'Keep original title',
            ),
            ledgerEntry(
              status: ChangeItemStatus.retracted,
              humanSummary: 'Retracted: Withdraw add_checklist_item',
              createdAt: DateTime(2026, 4, 17, 10),
            ),
          ]);
          await expandActivityStrip(tester);

          expect(find.byIcon(Icons.check), findsOneWidget);
          expect(find.byIcon(Icons.close), findsOneWidget);
          expect(find.byIcon(Icons.undo), findsOneWidget);
          // Only the rejected row carries a reason, so exactly one i-icon.
          expect(find.byIcon(Icons.info_outline), findsOneWidget);
        },
      );

      testWidgets(
        'expanding reveals every entry in newest-first order, collapsing '
        'hides them all again',
        (tester) async {
          final entries = [
            for (var i = 0; i < 5; i++)
              ledgerEntry(
                status: ChangeItemStatus.confirmed,
                humanSummary: 'Entry $i',
                createdAt: DateTime(2026, 4, 17, 15 - i),
              ),
          ];
          await pumpWithActivity(tester, entries);

          // Collapsed: no entries rendered, count pill shows total.
          expect(find.text('Entry 0'), findsNothing);
          expect(find.text('5'), findsOneWidget);
          expect(find.byIcon(Icons.expand_more), findsOneWidget);
          expect(find.byIcon(Icons.expand_less), findsNothing);

          await expandActivityStrip(tester);

          // Expanded: every entry visible, in newest-first source order.
          for (var i = 0; i < 5; i++) {
            expect(find.text('Entry $i'), findsOneWidget);
          }
          final firstY = tester.getTopLeft(find.text('Entry 0')).dy;
          final lastY = tester.getTopLeft(find.text('Entry 4')).dy;
          expect(firstY, lessThan(lastY));
          expect(find.byIcon(Icons.expand_less), findsOneWidget);

          // Collapsing back hides every row.
          await tester.tap(find.byIcon(Icons.expand_less));
          await _pumpUi(tester);
          for (var i = 0; i < 5; i++) {
            expect(find.text('Entry $i'), findsNothing);
          }
        },
      );
    });
  });
}
