import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../test_data/change_set_factories.dart';
import 'test_bench.dart';

PendingSuggestion _pending(String tool) {
  return makePending(
    id: tool,
    toolName: tool,
    humanSummary: 'Body for $tool',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(makeTestChangeSet());
    registerFallbackValue(<String>{});
  });

  group('AiSummaryCard – Proposals', () {
    testWidgets('shows empty proposals row when nothing is pending', (
      tester,
    ) async {
      await tester.pumpWidget(AgentTestBench().build());
      await tester.pumpAndSettle();

      expect(find.text('Proposed changes'), findsOneWidget);
      expect(find.textContaining('No open proposals'), findsOneWidget);
    });

    testWidgets('renders pending proposals with kind chip and cleaned text', (
      tester,
    ) async {
      final pending = makePending(
        id: 'p1',
        toolName: 'update_task_estimate',
        args: const {'minutes': 195},
        humanSummary: 'Estimate: 1h 30m → 3h 15m',
      );
      final bench = AgentTestBench(
        suggestions: UnifiedSuggestionList(open: [pending], activity: const []),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      expect(find.text('Proposed changes'), findsOneWidget);
      expect(find.text('Estimate'), findsOneWidget);
      expect(find.textContaining('1h 30m → 3h 15m'), findsOneWidget);
      expect(find.textContaining('Estimate: 1h 30m'), findsNothing);
    });

    testWidgets('Confirm-all button is hidden with a single pending item', (
      tester,
    ) async {
      final bench = AgentTestBench(
        suggestions: UnifiedSuggestionList(
          open: [
            makePending(
              id: 'only',
              toolName: 'set_task_status',
              humanSummary: 'Set status to GROOMED',
            ),
          ],
          activity: const [],
        ),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      expect(find.text('Confirm all'), findsNothing);
    });

    testWidgets('Confirm-all batches confirmAll over distinct change sets', (
      tester,
    ) async {
      final csA = makeTestChangeSet(
        id: 'cs-a',
        items: const [
          ChangeItem(
            toolName: 'set_task_status',
            args: {'status': 'GROOMED'},
            humanSummary: 'Set status to GROOMED',
          ),
        ],
      );
      final csB = makeTestChangeSet(
        id: 'cs-b',
        items: const [
          ChangeItem(
            toolName: 'update_task_priority',
            args: {'priority': 'P1'},
            humanSummary: 'Raise priority to P1',
          ),
        ],
      );

      final service = MockChangeSetConfirmationService();
      when(() => service.confirmAll(any())).thenAnswer(
        (_) async => const [
          ToolExecutionResult(success: true, output: 'ok'),
        ],
      );
      final notifier = MockUpdateNotifications();

      final bench = AgentTestBench(
        confirmationService: service,
        updateNotifications: notifier,
        suggestions: UnifiedSuggestionList(
          open: [
            PendingSuggestion(
              changeSet: csA,
              itemIndex: 0,
              item: csA.items.first,
              fingerprint: 'fp-a',
            ),
            PendingSuggestion(
              changeSet: csB,
              itemIndex: 0,
              item: csB.items.first,
              fingerprint: 'fp-b',
            ),
          ],
          activity: const [],
        ),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      expect(find.text('Confirm all'), findsOneWidget);
      await tester.tap(find.text('Confirm all'));
      await tester.pumpAndSettle();

      verify(() => service.confirmAll(csA)).called(1);
      verify(() => service.confirmAll(csB)).called(1);
      verify(() => notifier.notify(any())).called(1);
    });

    testWidgets('tap-confirm dispatches confirmItem with the correct args', (
      tester,
    ) async {
      final pending = makePending(
        id: 'p1',
        toolName: 'set_task_status',
        humanSummary: 'Set status to GROOMED',
      );

      final service = MockChangeSetConfirmationService();
      when(() => service.confirmItem(any(), any())).thenAnswer(
        (_) async => const ToolExecutionResult(success: true, output: 'ok'),
      );
      final notifier = MockUpdateNotifications();

      final bench = AgentTestBench(
        confirmationService: service,
        updateNotifications: notifier,
        suggestions: UnifiedSuggestionList(open: [pending], activity: const []),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();

      verify(() => service.confirmItem(pending.changeSet, 0)).called(1);
      verify(() => notifier.notify(any())).called(1);
    });

    testWidgets('tap-reject dispatches rejectItem and notifies the agent', (
      tester,
    ) async {
      final pending = makePending(
        id: 'p1',
        toolName: 'set_task_status',
        humanSummary: 'Set status to GROOMED',
      );

      final service = MockChangeSetConfirmationService();
      when(
        () => service.rejectItem(any(), any()),
      ).thenAnswer((_) async => true);
      final notifier = MockUpdateNotifications();

      final bench = AgentTestBench(
        confirmationService: service,
        updateNotifications: notifier,
        suggestions: UnifiedSuggestionList(open: [pending], activity: const []),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();

      verify(() => service.rejectItem(pending.changeSet, 0)).called(1);
      verify(() => notifier.notify(any())).called(1);
    });

    testWidgets('swipe-right past the threshold confirms via the service', (
      tester,
    ) async {
      final pending = makePending(
        id: 'p1',
        toolName: 'set_task_status',
        humanSummary: 'Set status to GROOMED',
      );

      final service = MockChangeSetConfirmationService();
      when(() => service.confirmItem(any(), any())).thenAnswer(
        (_) async => const ToolExecutionResult(success: true, output: 'ok'),
      );
      final notifier = MockUpdateNotifications();

      final bench = AgentTestBench(
        confirmationService: service,
        updateNotifications: notifier,
        suggestions: UnifiedSuggestionList(open: [pending], activity: const []),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      await tester.drag(find.text('Status'), const Offset(150, 0));
      await tester.pumpAndSettle();

      verify(() => service.confirmItem(pending.changeSet, 0)).called(1);
    });

    testWidgets('swipe-left past the threshold rejects via the service', (
      tester,
    ) async {
      final pending = makePending(
        id: 'p1',
        toolName: 'set_task_status',
        humanSummary: 'Set status to GROOMED',
      );

      final service = MockChangeSetConfirmationService();
      when(
        () => service.rejectItem(any(), any()),
      ).thenAnswer((_) async => true);
      final notifier = MockUpdateNotifications();

      final bench = AgentTestBench(
        confirmationService: service,
        updateNotifications: notifier,
        suggestions: UnifiedSuggestionList(open: [pending], activity: const []),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      await tester.drag(find.text('Status'), const Offset(-150, 0));
      await tester.pumpAndSettle();

      verify(() => service.rejectItem(pending.changeSet, 0)).called(1);
    });

    testWidgets('swipe under the threshold does not call the service', (
      tester,
    ) async {
      final pending = makePending(
        id: 'p1',
        toolName: 'set_task_status',
        humanSummary: 'Set status to GROOMED',
      );

      final service = MockChangeSetConfirmationService();
      final notifier = MockUpdateNotifications();

      final bench = AgentTestBench(
        confirmationService: service,
        updateNotifications: notifier,
        suggestions: UnifiedSuggestionList(open: [pending], activity: const []),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      await tester.drag(find.text('Status'), const Offset(40, 0));
      await tester.pumpAndSettle();

      verifyNever(() => service.confirmItem(any(), any()));
      verifyNever(() => service.rejectItem(any(), any()));
    });
  });

  group('AiSummaryCard – Proposal error & cancel paths', () {
    testWidgets('confirmItem failure surfaces an error toast', (tester) async {
      final pending = makePending(
        id: 'p1',
        toolName: 'set_task_status',
        humanSummary: 'Set status to GROOMED',
      );
      final service = MockChangeSetConfirmationService();
      when(
        () => service.confirmItem(any(), any()),
      ).thenAnswer((_) async => Future.error(Exception('boom')));
      final notifier = MockUpdateNotifications();
      final bench = AgentTestBench(
        confirmationService: service,
        updateNotifications: notifier,
        suggestions: UnifiedSuggestionList(open: [pending], activity: const []),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Failed to apply change'), findsWidgets);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('rejectItem returning false surfaces an error toast', (
      tester,
    ) async {
      final pending = makePending(
        id: 'p1',
        toolName: 'set_task_status',
        humanSummary: 'Set status to GROOMED',
      );
      final service = MockChangeSetConfirmationService();
      when(
        () => service.rejectItem(any(), any()),
      ).thenAnswer((_) async => false);
      final notifier = MockUpdateNotifications();
      final bench = AgentTestBench(
        confirmationService: service,
        updateNotifications: notifier,
        suggestions: UnifiedSuggestionList(open: [pending], activity: const []),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();

      verify(() => service.rejectItem(any(), any())).called(1);
      expect(find.text('Failed to apply change'), findsWidgets);
    });

    testWidgets('confirmItem warning result surfaces a warning toast', (
      tester,
    ) async {
      final pending = makePending(
        id: 'p1',
        toolName: 'set_task_status',
        humanSummary: 'Set status to GROOMED',
      );
      final service = MockChangeSetConfirmationService();
      when(() => service.confirmItem(any(), any())).thenAnswer(
        (_) async => const ToolExecutionResult(
          success: true,
          output: 'partial',
          errorMessage: 'partial issue',
        ),
      );
      final notifier = MockUpdateNotifications();
      final bench = AgentTestBench(
        confirmationService: service,
        updateNotifications: notifier,
        suggestions: UnifiedSuggestionList(open: [pending], activity: const []),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();

      expect(find.textContaining('partial issue'), findsWidgets);
    });

    testWidgets('confirmAll failure surfaces an error toast', (tester) async {
      final cs = makeTestChangeSet(
        id: 'cs-fail',
        items: const [
          ChangeItem(
            toolName: 'set_task_status',
            args: {'status': 'GROOMED'},
            humanSummary: 'Set status to GROOMED',
          ),
          ChangeItem(
            toolName: 'update_task_priority',
            args: {'priority': 'P1'},
            humanSummary: 'Raise priority to P1',
          ),
        ],
      );
      final service = MockChangeSetConfirmationService();
      when(
        () => service.confirmAll(any()),
      ).thenAnswer((_) async => Future.error(Exception('boom')));
      final notifier = MockUpdateNotifications();
      final bench = AgentTestBench(
        confirmationService: service,
        updateNotifications: notifier,
        suggestions: UnifiedSuggestionList(
          open: [
            PendingSuggestion(
              changeSet: cs,
              itemIndex: 0,
              item: cs.items.first,
              fingerprint: 'fp-a',
            ),
            PendingSuggestion(
              changeSet: cs,
              itemIndex: 1,
              item: cs.items[1],
              fingerprint: 'fp-b',
            ),
          ],
          activity: const [],
        ),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm all'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to apply change'), findsWidgets);
      verify(() => notifier.notify(any())).called(1);
    });

    testWidgets('confirmAll partial failure surfaces an error toast', (
      tester,
    ) async {
      final cs = makeTestChangeSet(
        id: 'cs-partial',
        items: const [
          ChangeItem(
            toolName: 'set_task_status',
            args: {'status': 'GROOMED'},
            humanSummary: 'Set status to GROOMED',
          ),
          ChangeItem(
            toolName: 'update_task_priority',
            args: {'priority': 'P1'},
            humanSummary: 'Raise priority to P1',
          ),
        ],
      );
      final service = MockChangeSetConfirmationService();
      when(() => service.confirmAll(any())).thenAnswer(
        (_) async => const [
          ToolExecutionResult(success: true, output: 'ok'),
          ToolExecutionResult(success: false, output: 'boom'),
        ],
      );
      final notifier = MockUpdateNotifications();
      final bench = AgentTestBench(
        confirmationService: service,
        updateNotifications: notifier,
        suggestions: UnifiedSuggestionList(
          open: [
            PendingSuggestion(
              changeSet: cs,
              itemIndex: 0,
              item: cs.items.first,
              fingerprint: 'fp-a',
            ),
            PendingSuggestion(
              changeSet: cs,
              itemIndex: 1,
              item: cs.items[1],
              fingerprint: 'fp-b',
            ),
          ],
          activity: const [],
        ),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm all'));
      await tester.pumpAndSettle();

      expect(find.text('Failed to apply change'), findsWidgets);
    });

    testWidgets('PointerCancel resets a partial drag back to rest', (
      tester,
    ) async {
      final pending = makePending(
        id: 'p1',
        toolName: 'set_task_status',
        humanSummary: 'Set status to GROOMED',
      );
      final service = MockChangeSetConfirmationService();
      final notifier = MockUpdateNotifications();
      final bench = AgentTestBench(
        confirmationService: service,
        updateNotifications: notifier,
        suggestions: UnifiedSuggestionList(open: [pending], activity: const []),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Status')),
      );
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.cancel();
      await tester.pumpAndSettle();

      verifyNever(() => service.confirmItem(any(), any()));
      verifyNever(() => service.rejectItem(any(), any()));
    });
  });

  group('AiSummaryCard – History', () {
    testWidgets('History toggle expands and collapses resolved entries', (
      tester,
    ) async {
      final bench = AgentTestBench(
        suggestions: UnifiedSuggestionList(
          open: const [],
          activity: [
            makeLedgerEntry(
              id: 'h1',
              status: ChangeItemStatus.confirmed,
              humanSummary: 'Status: OPEN → GROOMED',
            ),
            makeLedgerEntry(
              id: 'h2',
              status: ChangeItemStatus.rejected,
              humanSummary: 'Add: "Stale checklist item"',
              toolName: 'add_checklist_item',
            ),
          ],
        ),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      expect(find.textContaining('History · 2'), findsOneWidget);
      expect(find.textContaining('OPEN → GROOMED'), findsNothing);

      await tester.tap(find.textContaining('History · 2'));
      await tester.pumpAndSettle();

      expect(find.textContaining('OPEN → GROOMED'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Dismissed'), findsOneWidget);

      await tester.tap(find.textContaining('History · 2'));
      await tester.pumpAndSettle();
      expect(find.textContaining('OPEN → GROOMED'), findsNothing);
    });

    testWidgets('rejected entries render dimmed with strikethrough', (
      tester,
    ) async {
      final bench = AgentTestBench(
        suggestions: UnifiedSuggestionList(
          open: const [],
          activity: [
            makeLedgerEntry(
              id: 'rejected',
              status: ChangeItemStatus.rejected,
              humanSummary: 'Add: "Stale row"',
              toolName: 'add_checklist_item',
            ),
          ],
        ),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('History · 1'));
      await tester.pumpAndSettle();

      expect(find.text('Dismissed'), findsOneWidget);
      final bodyText = tester.widget<Text>(find.text('"Stale row"'));
      expect(bodyText.style?.decoration, TextDecoration.lineThrough);
    });
  });

  group('AiSummaryCard – Proposal kind chips', () {
    testWidgets('renders the localized chip label for every kind', (
      tester,
    ) async {
      // Pending rows drive `_resolveKind` + `_kindMeta` for every
      // arm. The body text isn't unique enough to assert against, so
      // we look at the chip labels.
      final pendings = [
        _pending('add_multiple_checklist_items'), // → add
        _pending('update_checklist_items'), // → update
        _pending('update_task_priority'), // → priority
        _pending('update_task_estimate'), // → estimate
        _pending('set_task_status'), // → status
        _pending('assign_task_labels'), // → label
        _pending('update_task_due_date'), // → due
      ];
      final bench = AgentTestBench(
        suggestions: UnifiedSuggestionList(
          open: pendings,
          activity: const [],
        ),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      expect(find.text('Add'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);
      expect(find.text('Priority'), findsOneWidget);
      expect(find.text('Estimate'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Label'), findsOneWidget);
      expect(find.text('Due'), findsOneWidget);
    });
  });

  group('AiSummaryCard – Proposal row error branches', () {
    testWidgets(
      'confirmItem returning success: false surfaces an error toast',
      (tester) async {
        final pending = makePending(
          id: 'p1',
          toolName: 'set_task_status',
          humanSummary: 'Set status to GROOMED',
        );
        final service = MockChangeSetConfirmationService();
        // Distinct from the existing "throws" test: this hits the
        // `!result.success` branch inside the try body, not the catch.
        when(() => service.confirmItem(any(), any())).thenAnswer(
          (_) async => const ToolExecutionResult(
            success: false,
            output: 'failed',
          ),
        );
        final notifier = MockUpdateNotifications();
        final bench = AgentTestBench(
          confirmationService: service,
          updateNotifications: notifier,
          suggestions: UnifiedSuggestionList(
            open: [pending],
            activity: const [],
          ),
        );

        await tester.pumpWidget(bench.build());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.check_rounded));
        await tester.pumpAndSettle();

        verify(() => service.confirmItem(any(), any())).called(1);
        verify(() => notifier.notify(any())).called(1);
        expect(find.text('Failed to apply change'), findsWidgets);
      },
    );

    testWidgets(
      'rejectItem throwing surfaces an error toast via the catch arm',
      (tester) async {
        final pending = makePending(
          id: 'p1',
          toolName: 'set_task_status',
          humanSummary: 'Set status to GROOMED',
        );
        final service = MockChangeSetConfirmationService();
        when(
          () => service.rejectItem(any(), any()),
        ).thenAnswer((_) async => Future.error(Exception('reject boom')));
        final notifier = MockUpdateNotifications();
        final bench = AgentTestBench(
          confirmationService: service,
          updateNotifications: notifier,
          suggestions: UnifiedSuggestionList(
            open: [pending],
            activity: const [],
          ),
        );

        await tester.pumpWidget(bench.build());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.close_rounded).first);
        await tester.pumpAndSettle();

        verify(() => service.rejectItem(any(), any())).called(1);
        expect(find.text('Failed to apply change'), findsWidgets);
      },
    );
  });

  group('AiSummaryCard – Confirm-all busy spinner', () {
    testWidgets(
      'while confirmAll is in flight the button shows a spinner',
      (tester) async {
        final csA = makeTestChangeSet(
          id: 'cs-busy-a',
          items: const [
            ChangeItem(
              toolName: 'set_task_status',
              args: {'status': 'GROOMED'},
              humanSummary: 'Set status to GROOMED',
            ),
          ],
        );
        final csB = makeTestChangeSet(
          id: 'cs-busy-b',
          items: const [
            ChangeItem(
              toolName: 'update_task_priority',
              args: {'priority': 'P1'},
              humanSummary: 'Raise priority to P1',
            ),
          ],
        );

        // Hold the response so the button stays in the busy state for
        // the duration of the assertion.
        final completer = Completer<List<ToolExecutionResult>>();
        final service = MockChangeSetConfirmationService();
        when(
          () => service.confirmAll(any()),
        ).thenAnswer((_) => completer.future);
        final notifier = MockUpdateNotifications();

        final bench = AgentTestBench(
          confirmationService: service,
          updateNotifications: notifier,
          suggestions: UnifiedSuggestionList(
            open: [
              PendingSuggestion(
                changeSet: csA,
                itemIndex: 0,
                item: csA.items.first,
                fingerprint: 'fp-a',
              ),
              PendingSuggestion(
                changeSet: csB,
                itemIndex: 0,
                item: csB.items.first,
                fingerprint: 'fp-b',
              ),
            ],
            activity: const [],
          ),
        );

        await tester.pumpWidget(bench.build());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Confirm all'));
        // Don't settle — drain the tap and rebuild only.
        await tester.pump();

        // The Confirm all button now shows a spinner in place of the
        // done-all icon.
        expect(find.byIcon(Icons.done_all_rounded), findsNothing);
        expect(
          find.descendant(
            of: find.byType(TextButton),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );

        // Release the future so the test tear-down doesn't hang.
        completer.complete(const []);
        await tester.pumpAndSettle();
      },
    );
  });
}
