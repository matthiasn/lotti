import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/ui/ai_summary_card.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../test_data/change_set_factories.dart';
import '../../test_data/entity_factories.dart';
import 'test_bench.dart';

PendingSuggestion _pending(String tool) {
  return makePending(
    id: tool,
    toolName: tool,
    humanSummary: 'Body for $tool',
  );
}

// Per-kind token selectors. Each generated `DsColorsProposalKind<Kind>` is a
// distinct type with no shared interface, so we project each onto a common
// `(color, surface)` record for the parameterized chip test below.
({Color color, Color surface}) _selectAdd(DsColorsProposalKind p) =>
    (color: p.add.color, surface: p.add.surface);
({Color color, Color surface}) _selectUpdate(DsColorsProposalKind p) =>
    (color: p.update.color, surface: p.update.surface);
({Color color, Color surface}) _selectRemove(DsColorsProposalKind p) =>
    (color: p.remove.color, surface: p.remove.surface);
({Color color, Color surface}) _selectPriority(DsColorsProposalKind p) =>
    (color: p.priority.color, surface: p.priority.surface);
({Color color, Color surface}) _selectEstimate(DsColorsProposalKind p) =>
    (color: p.estimate.color, surface: p.estimate.surface);
({Color color, Color surface}) _selectStatus(DsColorsProposalKind p) =>
    (color: p.status.color, surface: p.status.surface);
({Color color, Color surface}) _selectLabel(DsColorsProposalKind p) =>
    (color: p.label.color, surface: p.label.surface);
({Color color, Color surface}) _selectDue(DsColorsProposalKind p) =>
    (color: p.due.color, surface: p.due.surface);

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

    testWidgets(
      'keeps unresolved proposals visible during running-agent refresh '
      'until the agent finishes',
      (tester) async {
        final runningController = StreamController<bool>.broadcast();
        addTearDown(runningController.close);
        final refreshController = StreamController<int>.broadcast();
        addTearDown(refreshController.close);

        final identity = makeTestIdentity();
        final pending = makePending(
          id: 'p1',
          toolName: 'set_task_status',
          humanSummary: 'Set status to GROOMED',
        );
        final populated = UnifiedSuggestionList(
          open: [pending],
          activity: const [],
        );
        var currentSuggestions = populated;

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            mediaQueryData: desktopMediaQueryData,
            overrides: [
              configFlagProvider.overrideWith(
                (ref, flagName) => Stream.value(
                  flagName != enableAiSummaryTtsFlag,
                ),
              ),
              taskAgentProvider.overrideWith((ref, id) async => identity),
              agentReportProvider.overrideWith((ref, agentId) async => null),
              templateForAgentProvider.overrideWith(
                (ref, agentId) async => null,
              ),
              agentStateProvider.overrideWith((ref, agentId) async => null),
              agentIsRunningProvider.overrideWith((ref, agentId) async* {
                yield false;
                yield* runningController.stream;
              }),
              unifiedSuggestionListProvider.overrideWith((ref, taskId) async {
                final isRunning =
                    ref.watch(agentIsRunningProvider(identity.agentId)).value ??
                    false;
                return isRunning
                    ? const UnifiedSuggestionList.empty()
                    : currentSuggestions;
              }),
            ],
            child: const SingleChildScrollView(
              child: AiSummaryCard(taskId: AgentTestBench.taskId),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Set status to GROOMED'), findsOneWidget);

        runningController.add(true);
        await tester.pump();
        await tester.pump();

        expect(find.textContaining('Set status to GROOMED'), findsOneWidget);
        expect(find.textContaining('No open proposals'), findsNothing);

        currentSuggestions = const UnifiedSuggestionList.empty();
        runningController.add(false);
        await tester.pump();
        await tester.pump();

        expect(find.textContaining('Set status to GROOMED'), findsNothing);
        expect(find.textContaining('No open proposals'), findsOneWidget);
      },
    );

    testWidgets('disposes suggestion subscriptions when unmounted', (
      tester,
    ) async {
      final runningController = StreamController<bool>.broadcast();
      addTearDown(runningController.close);

      final identity = makeTestIdentity();
      final pending = makePending(
        id: 'p1',
        toolName: 'set_task_status',
        humanSummary: 'Set status to GROOMED',
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          mediaQueryData: desktopMediaQueryData,
          overrides: [
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(
                flagName != enableAiSummaryTtsFlag,
              ),
            ),
            taskAgentProvider.overrideWith((ref, id) async => identity),
            agentReportProvider.overrideWith((ref, agentId) async => null),
            templateForAgentProvider.overrideWith(
              (ref, agentId) async => null,
            ),
            agentStateProvider.overrideWith((ref, agentId) async => null),
            agentIsRunningProvider.overrideWith((ref, agentId) async* {
              yield false;
              yield* runningController.stream;
            }),
            unifiedSuggestionListProvider.overrideWith((ref, taskId) async {
              ref.watch(agentIsRunningProvider(identity.agentId));
              return UnifiedSuggestionList(
                open: [pending],
                activity: const [],
              );
            }),
          ],
          child: const SingleChildScrollView(
            child: AiSummaryCard(taskId: AgentTestBench.taskId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Set status to GROOMED'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      runningController.add(true);
      await tester.pump();

      expect(find.textContaining('Set status to GROOMED'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'clears cached proposals when the card switches to another task',
      (tester) async {
        final taskIdNotifier = ValueNotifier<String>(AgentTestBench.taskId);
        addTearDown(taskIdNotifier.dispose);

        final firstIdentity = makeTestIdentity(
          id: 'identity-001',
          displayName: 'Task Agent One',
        );
        final secondIdentity = makeTestIdentity(
          id: 'identity-002',
          agentId: 'agent-002',
          displayName: 'Task Agent Two',
        );
        final pending = makePending(
          id: 'task-one-proposal',
          toolName: 'set_task_status',
          humanSummary: 'Set task one to GROOMED',
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            mediaQueryData: desktopMediaQueryData,
            overrides: [
              configFlagProvider.overrideWith(
                (ref, flagName) => Stream.value(
                  flagName != enableAiSummaryTtsFlag,
                ),
              ),
              taskAgentProvider.overrideWith((ref, id) async {
                return id == AgentTestBench.taskId
                    ? firstIdentity
                    : secondIdentity;
              }),
              agentReportProvider.overrideWith((ref, agentId) async => null),
              templateForAgentProvider.overrideWith(
                (ref, agentId) async => null,
              ),
              agentStateProvider.overrideWith((ref, agentId) async => null),
              agentIsRunningProvider.overrideWith(
                (ref, agentId) => Stream.value(true),
              ),
              unifiedSuggestionListProvider.overrideWith((ref, taskId) async {
                return taskId == AgentTestBench.taskId
                    ? UnifiedSuggestionList(
                        open: [pending],
                        activity: const [],
                      )
                    : const UnifiedSuggestionList.empty();
              }),
            ],
            child: ValueListenableBuilder<String>(
              valueListenable: taskIdNotifier,
              builder: (context, taskId, _) {
                return SingleChildScrollView(
                  child: AiSummaryCard(taskId: taskId),
                );
              },
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.textContaining('Set task one to GROOMED'), findsOneWidget);

        taskIdNotifier.value = 'task-002';
        await tester.pump();
        await tester.pump();

        expect(find.textContaining('Set task one to GROOMED'), findsNothing);
        expect(find.text('Task Agent Two'), findsOneWidget);
      },
    );

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
    // Each tool name resolves (via `_resolveKind`) to a proposal kind, and
    // each kind resolves (via `_kindMeta`) to a chip whose label text, text
    // color and surface color come from the `proposalKind` design tokens.
    // We drive every (tool → kind) arm and assert all three observable
    // properties against the live production tokens rather than re-deriving
    // them in the test.
    const cases =
        <
          ({
            String tool,
            String expectedLabel,
            ({Color color, Color surface}) Function(DsColorsProposalKind p)
            select,
          })
        >[
          (
            tool: 'add_multiple_checklist_items',
            expectedLabel: 'Add',
            select: _selectAdd,
          ),
          (
            tool: 'update_checklist_items',
            expectedLabel: 'Update',
            select: _selectUpdate,
          ),
          (
            tool: 'retract_suggestions',
            expectedLabel: 'Remove',
            select: _selectRemove,
          ),
          (
            tool: 'update_task_priority',
            expectedLabel: 'Priority',
            select: _selectPriority,
          ),
          (
            tool: 'update_task_estimate',
            expectedLabel: 'Estimate',
            select: _selectEstimate,
          ),
          (
            tool: 'set_task_status',
            expectedLabel: 'Status',
            select: _selectStatus,
          ),
          (
            tool: 'assign_task_labels',
            expectedLabel: 'Label',
            select: _selectLabel,
          ),
          (
            tool: 'update_task_due_date',
            expectedLabel: 'Due',
            select: _selectDue,
          ),
        ];

    for (final c in cases) {
      testWidgets(
        'renders ${c.expectedLabel} chip with token color/surface '
        'for ${c.tool}',
        (tester) async {
          final bench = AgentTestBench(
            suggestions: UnifiedSuggestionList(
              open: [_pending(c.tool)],
              activity: const [],
            ),
          );

          await tester.pumpWidget(bench.build());
          await tester.pumpAndSettle();

          final labelFinder = find.text(c.expectedLabel);
          expect(labelFinder, findsOneWidget);

          // Resolve the production tokens from the live render context so the
          // expected colors are never hard-coded or re-derived in the test.
          final tokens = tester
              .element(labelFinder)
              .designTokens
              .colors
              .proposalKind;
          final entry = c.select(tokens);

          final labelText = tester.widget<Text>(labelFinder);
          expect(labelText.style?.color, entry.color);

          // Each kind is a distinct token; sanity-check that the chip color
          // is the kind's own foreground, not a different kind's.
          expect(entry.color, isNot(entry.surface));

          // The chip surface lives on the nearest enclosing decorated
          // Container ancestor of the label text.
          final chip = tester.widget<Container>(
            find
                .ancestor(of: labelFinder, matching: find.byType(Container))
                .first,
          );
          final decoration = chip.decoration! as BoxDecoration;
          expect(decoration.color, entry.surface);
        },
      );
    }
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

  group('AiSummaryCard – swipe intent label & affordances', () {
    // A desktop-width viewport with animations disabled. Disabling
    // animations both (a) drives the reduce-motion branch in
    // didChangeDependencies that schedules nothing, and (b) keeps the
    // wiggle hint from adding its own offset on top of the drag, so the
    // mid-gesture `_dx` is exactly what we move by.
    const reducedMotionDesktop = MediaQueryData(
      size: Size(900, 800),
      disableAnimations: true,
    );

    testWidgets(
      'reduce-motion skips scheduling the wiggle hint on the first row',
      (tester) async {
        final pending = makePending(
          id: 'p1',
          toolName: 'set_task_status',
          humanSummary: 'Set status to GROOMED',
        );
        final bench = AgentTestBench(
          mediaQueryData: reducedMotionDesktop,
          suggestions: UnifiedSuggestionList(
            open: [pending],
            activity: const [],
          ),
        );

        await tester.pumpWidget(bench.build());
        await tester.pumpAndSettle();

        // No animation controller is created, so the row never peeks:
        // the swipe-intent labels stay hidden until the user drags.
        expect(find.text('Confirm'), findsNothing);
        expect(find.text('Reject'), findsNothing);

        // The row renders normally with its action buttons. If a wiggle
        // Timer had been scheduled, an un-awaited timer would make the
        // test fail at tear-down — reaching here clean proves the
        // reduce-motion early return fired.
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a partial left swipe surfaces the Reject intent label and close icon',
      (tester) async {
        final pending = makePending(
          id: 'p1',
          toolName: 'set_task_status',
          humanSummary: 'Set status to GROOMED',
        );
        final service = MockChangeSetConfirmationService();
        final notifier = MockUpdateNotifications();
        final bench = AgentTestBench(
          mediaQueryData: reducedMotionDesktop,
          confirmationService: service,
          updateNotifications: notifier,
          suggestions: UnifiedSuggestionList(
            open: [pending],
            activity: const [],
          ),
        );

        await tester.pumpWidget(bench.build());
        await tester.pumpAndSettle();

        // Before any drag the reject backdrop is not shown.
        expect(find.byIcon(Icons.close), findsNothing);

        // Hold a left drag at -50px: past the -30 intent threshold but
        // short of the -70 reject trigger, so the row stays in the
        // "Reject" affordance state without firing the service.
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Status')),
        );
        await gesture.moveBy(const Offset(-50, 0));
        await tester.pump();

        // The reject intent label + the backdrop close icon are now
        // rendered by the gradient layer.
        expect(find.text('Reject'), findsOneWidget);
        expect(find.byIcon(Icons.close), findsOneWidget);

        // Releasing below the trigger must not call the service.
        await gesture.up();
        await tester.pumpAndSettle();
        verifyNever(() => service.rejectItem(any(), any()));
        verifyNever(() => service.confirmItem(any(), any()));
      },
    );
  });

  group('AiSummaryCard – proposal row busy spinner', () {
    testWidgets(
      'while confirmItem is in flight the row actions show a spinner',
      (tester) async {
        final pending = makePending(
          id: 'p1',
          toolName: 'set_task_status',
          humanSummary: 'Set status to GROOMED',
        );

        // Hold the confirm response open so the row stays busy across
        // the assertion window.
        final completer = Completer<ToolExecutionResult>();
        final service = MockChangeSetConfirmationService();
        when(
          () => service.confirmItem(any(), any()),
        ).thenAnswer((_) => completer.future);
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

        // Tap confirm and rebuild only (no settle) so we observe the
        // in-flight busy layout.
        await tester.tap(find.byIcon(Icons.check_rounded));
        await tester.pump();

        // The confirm/reject chips collapse to a single 48×48 spinner
        // slot — the icons are gone and a spinner is shown in their
        // place inside the proposal row (not the confirm-all button,
        // which isn't present with a single item).
        expect(find.byIcon(Icons.check_rounded), findsNothing);
        expect(find.byIcon(Icons.close_rounded), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Release the future so tear-down doesn't hang, and confirm the
        // busy state clears back to the action buttons.
        completer.complete(
          const ToolExecutionResult(success: true, output: 'ok'),
        );
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
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
