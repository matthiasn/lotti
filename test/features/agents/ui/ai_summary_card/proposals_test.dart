import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/ui/ai_summary_card.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposal_row_part.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/proposals_section_part.dart';
import 'package:lotti/features/design_system/theme/motion_tokens.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../../../widget_test_utils.dart';
import '../../test_data/change_set_factories.dart';
import '../../test_data/entity_factories.dart';
import 'test_bench.dart';

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Proposed changes'), findsOneWidget);
      expect(find.textContaining('No open proposals'), findsOneWidget);
    });

    testWidgets('flags only newly-arrived rows to animate their entrance', (
      tester,
    ) async {
      final p1 = makePending(
        id: 'p1',
        toolName: 'set_task_status',
        humanSummary: 'First',
      );
      final p2 = makePending(
        id: 'p2',
        toolName: 'set_task_status',
        humanSummary: 'Second',
      );

      await tester.pumpWidget(
        makeTestableWidget(
          ProposalsSection(
            open: [p1, p2],
            newlyArrived: const {'fp-p2'},
            resolved: const [],
            historyOpen: false,
            onToggleHistory: () {},
            confirmAllBusy: false,
            confirmAllPulse: 0,
            onConfirmAll: null,
          ),
          // Reduced motion keeps the entrance instant (and suppresses the row's
          // one-shot swipe-nudge timer); we assert the wiring, not the tween —
          // EnterTransition's own tests cover the reveal.
          mediaQueryData: const MediaQueryData(disableAnimations: true),
        ),
      );
      await tester.pump();

      final enterP1 = tester.widget<EnterTransition>(
        find.byKey(const ValueKey('enter-p1-0')),
      );
      final enterP2 = tester.widget<EnterTransition>(
        find.byKey(const ValueKey('enter-p2-0')),
      );
      // The initial batch (p1) is shown instantly; only the freshly arrived p2
      // is flagged to reveal its height open.
      expect(enterP1.animate, isFalse);
      expect(enterP2.animate, isTrue);
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Confirm all'), findsOneWidget);
      await tester.tap(find.text('Confirm all'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      verify(() => service.confirmItem(pending.changeSet, 0)).called(1);
      verify(() => notifier.notify(any())).called(1);
    });

    testWidgets(
      'keeps unresolved proposals visible during running-agent refresh '
      'until the agent finishes',
      (tester) async {
        final runningController = StreamController<bool>.broadcast();
        addTearDown(runningController.close);

        final identity = makeTestIdentity();
        final pending = makePending(
          id: 'p1',
          toolName: 'set_task_status',
          humanSummary: 'Set status to GROOMED',
        );
        var currentSuggestions = UnifiedSuggestionList(
          open: [pending],
          activity: const [],
        );

        await tester.pumpWidget(
          AgentTestBench(
            // The running flag is driven from a controller so the test can
            // step the agent through running → idle. The suggestion list
            // reacts to that flag: it empties while the agent runs, and the
            // shell's merge logic must keep the unresolved row visible.
            isRunningOverride: (ref, agentId) async* {
              yield false;
              yield* runningController.stream;
            },
            suggestionListOverride: (ref, taskId) async {
              final isRunning =
                  ref.watch(agentIsRunningProvider(identity.agentId)).value ??
                  false;
              return isRunning
                  ? const UnifiedSuggestionList.empty()
                  : currentSuggestions;
            },
          ).build(),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

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
        AgentTestBench(
          isRunningOverride: (ref, agentId) async* {
            yield false;
            yield* runningController.stream;
          },
          suggestionListOverride: (ref, taskId) async {
            ref.watch(agentIsRunningProvider(identity.agentId));
            return UnifiedSuggestionList(
              open: [pending],
              activity: const [],
            );
          },
        ).build(),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.text('Status'), const Offset(150, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.text('Status'), const Offset(-150, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.drag(find.text('Status'), const Offset(40, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Confirm all'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Confirm all'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Status')),
      );
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();
      await gesture.cancel();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('History · 2'), findsOneWidget);
      expect(find.textContaining('OPEN → GROOMED'), findsNothing);

      await tester.tap(find.textContaining('History · 2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('OPEN → GROOMED'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Dismissed'), findsOneWidget);

      await tester.tap(find.textContaining('History · 2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.textContaining('History · 1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Dismissed'), findsOneWidget);
      final bodyText = tester.widget<Text>(find.text('"Stale row"'));
      expect(bodyText.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('retracted entries also render dimmed with strikethrough', (
      tester,
    ) async {
      // The `lineThrough`/`dimmed` arm fires for both `rejected` and
      // `retracted`; this covers the agent-withdrawn (`retracted`) status
      // that the rejected case above doesn't reach. A retracted entry is
      // not user-confirmed, so `_ResolvedTag` renders "Dismissed".
      final bench = AgentTestBench(
        suggestions: UnifiedSuggestionList(
          open: const [],
          activity: [
            makeLedgerEntry(
              id: 'retracted',
              status: ChangeItemStatus.retracted,
              humanSummary: 'Add: "Redundant row"',
              toolName: 'add_checklist_item',
            ),
          ],
        ),
      );

      await tester.pumpWidget(bench.build());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.textContaining('History · 1'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Dismissed'), findsOneWidget);
      final bodyText = tester.widget<Text>(find.text('"Redundant row"'));
      expect(bodyText.style?.decoration, TextDecoration.lineThrough);

      // The body is rendered dimmed (Opacity 0.45) on resolved-rejected
      // and resolved-retracted rows alike.
      final opacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('"Redundant row"'),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, 0.45);
    });
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
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Confirm all'));
        // Don't settle — drain the tap and rebuild only.
        await tester.pump();

        // The Confirm all button (a tonal accent pill) now shows a spinner
        // in place of the done-all icon. No proposal row is busy here, so the
        // only spinner in the tree is the Confirm-all one.
        expect(find.byIcon(Icons.done_all_rounded), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Release the future so the test tear-down doesn't hang.
        completer.complete(const []);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      },
    );
  });

  group('AiSummaryCard – screen-reader announcement', () {
    testWidgets(
      'confirm announces the verdict assertively with the remaining count',
      (tester) async {
        final events = <Map<Object?, Object?>>[];
        tester.binding.defaultBinaryMessenger.setMockMessageHandler(
          'flutter/accessibility',
          (message) async {
            final decoded = const StandardMessageCodec().decodeMessage(message);
            if (decoded is Map) events.add(decoded);
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMessageHandler(
            'flutter/accessibility',
            null,
          ),
        );

        final service = MockChangeSetConfirmationService();
        when(() => service.confirmItem(any(), any())).thenAnswer(
          (_) async => const ToolExecutionResult(success: true, output: 'ok'),
        );
        // Two pending → after confirming one, "1 pending" remains.
        final bench = AgentTestBench(
          confirmationService: service,
          updateNotifications: MockUpdateNotifications(),
          suggestions: UnifiedSuggestionList(
            open: [
              makePending(
                id: 'a',
                toolName: 'set_task_status',
                humanSummary: 'Set status to GROOMED',
              ),
              makePending(
                id: 'b',
                toolName: 'update_task_priority',
                humanSummary: 'Raise priority to P1',
              ),
            ],
            activity: const [],
          ),
        );

        await tester.pumpWidget(bench.build());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.byIcon(Icons.check_rounded).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final announce = events.firstWhere(
          (e) => e['type'] == 'announce',
          orElse: () => const {},
        );
        final data = announce['data'] as Map<Object?, Object?>?;
        final message = data?['message'] as String?;
        // Verdict text + the localized remaining count are both spoken, and the
        // announcement is assertive (index 1) — the direct result of an action.
        expect(message, isNotNull);
        expect(message, contains('Change applied'));
        expect(message, contains('1'));
        expect(data?['assertiveness'], 1);
      },
    );
  });

  group('AiSummaryCard – retain exiting suggestion', () {
    testWidgets(
      'a committed row dropped by the provider mid-exit stays until its '
      'collapse finishes',
      (tester) async {
        final csA = makeTestChangeSet(
          id: 'retain-a',
          items: const [
            ChangeItem(
              toolName: 'set_task_status',
              args: {'status': 'GROOMED'},
              humanSummary: 'Alpha proposal',
            ),
          ],
        );
        final csB = makeTestChangeSet(
          id: 'retain-b',
          items: const [
            ChangeItem(
              toolName: 'update_task_priority',
              args: {'priority': 'P1'},
              humanSummary: 'Beta proposal',
            ),
          ],
        );
        final sugA = PendingSuggestion(
          changeSet: csA,
          itemIndex: 0,
          item: csA.items.first,
          fingerprint: 'fp-retain-a',
        );
        final sugB = PendingSuggestion(
          changeSet: csB,
          itemIndex: 0,
          item: csB.items.first,
          fingerprint: 'fp-retain-b',
        );
        var current = UnifiedSuggestionList(
          open: [sugA, sugB],
          activity: const [],
        );

        final service = MockChangeSetConfirmationService();
        // Hold Alpha's write open so it stays in the exiting set (acknowledging)
        // without pruning while the provider drops it.
        final completer = Completer<ToolExecutionResult>();
        when(
          () => service.confirmItem(csA, 0),
        ).thenAnswer((_) => completer.future);

        final bench = AgentTestBench(
          confirmationService: service,
          updateNotifications: MockUpdateNotifications(),
          suggestionListOverride: (ref, taskId) => current,
        );

        await tester.pumpWidget(bench.build());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Alpha proposal'), findsOneWidget);
        expect(find.text('Beta proposal'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.check_rounded).first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // The provider now drops Alpha (as the real re-query does after a
        // write completes) while Alpha is still collapsing.
        current = UnifiedSuggestionList(open: [sugB], activity: const []);
        ProviderScope.containerOf(
          tester.element(find.byType(AiSummaryCard)),
        ).invalidate(unifiedSuggestionListProvider(AgentTestBench.taskId));
        await tester.pump();
        await tester.pump();

        // Alpha is retained on screen even though the provider dropped it —
        // _retainExitingSuggestions re-inserts it until its exit completes.
        expect(find.text('Alpha proposal'), findsOneWidget);

        // Release the write → Alpha collapses and is finally pruned; Beta stays.
        completer.complete(
          const ToolExecutionResult(success: true, output: 'ok'),
        );
        await tester.pump();
        await tester.pump(ProposalMotion.resolveHold);
        await tester.pump(ProposalMotion.collapse);
        await tester.pump(ProposalMotion.collapse);
        await tester.pump();
        expect(find.text('Alpha proposal'), findsNothing);
        expect(find.text('Beta proposal'), findsOneWidget);
      },
    );
  });

  group('AiSummaryCard – tap-guard during collapse', () {
    testWidgets(
      'a tap on a sibling is inert while another row is collapsing',
      (tester) async {
        final csA = makeTestChangeSet(
          id: 'cs-guard-a',
          items: const [
            ChangeItem(
              toolName: 'set_task_status',
              args: {'status': 'GROOMED'},
              humanSummary: 'Set status to GROOMED',
            ),
          ],
        );
        final csB = makeTestChangeSet(
          id: 'cs-guard-b',
          items: const [
            ChangeItem(
              toolName: 'update_task_priority',
              args: {'priority': 'P1'},
              humanSummary: 'Raise priority to P1',
            ),
          ],
        );
        final service = MockChangeSetConfirmationService();
        // Hold row A's confirm open so it stays in the resolve/collapse window
        // (settling = true) across the sibling tap.
        final completer = Completer<ToolExecutionResult>();
        when(
          () => service.confirmItem(csA, 0),
        ).thenAnswer((_) => completer.future);
        when(() => service.confirmItem(csB, 0)).thenAnswer(
          (_) async => const ToolExecutionResult(success: true, output: 'ok'),
        );
        final bench = AgentTestBench(
          confirmationService: service,
          updateNotifications: MockUpdateNotifications(),
          suggestions: UnifiedSuggestionList(
            open: [
              PendingSuggestion(
                changeSet: csA,
                itemIndex: 0,
                item: csA.items.first,
                fingerprint: 'fp-guard-a',
              ),
              PendingSuggestion(
                changeSet: csB,
                itemIndex: 0,
                item: csB.items.first,
                fingerprint: 'fp-guard-b',
              ),
            ],
            activity: const [],
          ),
        );

        await tester.pumpWidget(bench.build());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Commit row A; it begins resolving (and reports it), so the section is
        // now settling. Row A's own buttons collapse to a spinner.
        await tester.tap(find.byIcon(Icons.check_rounded).first);
        await tester.pump();

        // Tap row B's confirm button — it must be inert while the section is
        // settling (row A collapsing). `.last` targets row B's button: row A's
        // resolve badge also renders a check glyph, so `.first` could hit that
        // inert badge and pass for the wrong reason; row B sits below row A, so
        // its button is always the last check glyph in tree order.
        await tester.tap(find.byIcon(Icons.check_rounded).last);
        await tester.pump(const Duration(milliseconds: 50));
        verifyNever(() => service.confirmItem(csB, 0));

        // Let row A finish leaving (resolve → collapse → prune), then row B is
        // interactive again.
        completer.complete(
          const ToolExecutionResult(success: true, output: 'ok'),
        );
        await tester.pump();
        await tester.pump(ProposalMotion.resolveHold);
        await tester.pump(ProposalMotion.collapse);
        await tester.pump(ProposalMotion.collapse);
        await tester.pump();
        // Only row B remains, and it is interactive again.
        expect(find.byType(ProposalRow), findsOneWidget);

        await tester.tap(find.byIcon(Icons.check_rounded).first);
        await tester.pump();
        verify(() => service.confirmItem(csB, 0)).called(1);
      },
    );
  });

  group('AiSummaryCard – Confirm-all cascade', () {
    testWidgets(
      'pressing Confirm all fires one haptic and sweeps the rows out',
      (tester) async {
        final haptics = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              haptics.add(call.arguments as String? ?? '');
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );

        final csA = makeTestChangeSet(
          id: 'cs-cascade-a',
          items: const [
            ChangeItem(
              toolName: 'set_task_status',
              args: {'status': 'GROOMED'},
              humanSummary: 'Set status to GROOMED',
            ),
          ],
        );
        final csB = makeTestChangeSet(
          id: 'cs-cascade-b',
          items: const [
            ChangeItem(
              toolName: 'update_task_priority',
              args: {'priority': 'P1'},
              humanSummary: 'Raise priority to P1',
            ),
          ],
        );
        // Hold the confirm so the rows stay mounted across the cascade window.
        final completer = Completer<List<ToolExecutionResult>>();
        final service = MockChangeSetConfirmationService();
        when(
          () => service.confirmAll(any()),
        ).thenAnswer((_) => completer.future);
        final bench = AgentTestBench(
          confirmationService: service,
          updateNotifications: MockUpdateNotifications(),
          suggestions: UnifiedSuggestionList(
            open: [
              PendingSuggestion(
                changeSet: csA,
                itemIndex: 0,
                item: csA.items.first,
                fingerprint: 'fp-cascade-a',
              ),
              PendingSuggestion(
                changeSet: csB,
                itemIndex: 0,
                item: csB.items.first,
                fingerprint: 'fp-cascade-b',
              ),
            ],
            activity: const [],
          ),
        );

        await tester.pumpWidget(bench.build());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Confirm all'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Exactly one light haptic for the whole gesture — the rows no longer
        // tick individually (which machine-gunned on a big batch).
        expect(
          haptics.where((h) => h == 'HapticFeedbackType.selectionClick').length,
          1,
        );

        // The rows run their staggered resolve → collapse sweep (independent of
        // the still-pending writes) and leave one after another.
        completer.complete(const []);
        await tester.pump();
        await tester.pump(ProposalMotion.total);
        await tester.pump(ProposalMotion.collapse);
        await tester.pump(ProposalMotion.staggerStep * 8);
        await tester.pump();
        expect(find.byType(ProposalRow), findsNothing);
      },
    );
  });

  // The card wraps each section that lands while the agent runs in an
  // [EnterTransition] so it reveals open from zero instead of snapping the
  // page below it (see `ai_summary_card.dart`).
  group('EnterTransition', () {
    Future<void> pumpEnter(
      WidgetTester tester, {
      required bool animate,
      bool reduceMotion = false,
    }) {
      return tester.pumpWidget(
        makeTestableWidget(
          Align(
            alignment: Alignment.topLeft,
            child: EnterTransition(
              animate: animate,
              child: const SizedBox(height: 100, width: 100),
            ),
          ),
          mediaQueryData: reduceMotion
              ? const MediaQueryData(disableAnimations: true)
              : null,
        ),
      );
    }

    double revealHeight(WidgetTester tester) => tester
        .getSize(
          find.descendant(
            of: find.byType(EnterTransition),
            matching: find.byType(SizeTransition),
          ),
        )
        .height;

    testWidgets('animate:false reveals the child at full height immediately', (
      tester,
    ) async {
      await pumpEnter(tester, animate: false);
      // No settle pump: content already present on the card's first frame must
      // not animate — the card's StaggeredEntrance owns that on-open motion.
      expect(revealHeight(tester), 100);
    });

    testWidgets('animate:true eases the height open from zero to full', (
      tester,
    ) async {
      await pumpEnter(tester, animate: true);
      // Collapsed on the first frame, then it grows.
      expect(revealHeight(tester), lessThan(100));
      await tester.pump(const Duration(milliseconds: 150));
      final mid = revealHeight(tester);
      expect(mid, greaterThan(0));
      expect(mid, lessThan(100));
      await tester.pump(const Duration(milliseconds: 300));
      expect(revealHeight(tester), 100);
    });

    testWidgets(
      'reduced motion snaps to full height even when animate is true',
      (tester) async {
        await pumpEnter(tester, animate: true, reduceMotion: true);
        expect(revealHeight(tester), 100);
      },
    );
  });
}
