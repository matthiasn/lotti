import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
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
import 'package:lotti/features/agents/ui/ai_summary_card.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../test_helper.dart';
import '../test_data/change_set_factories.dart';
import '../test_data/entity_factories.dart';

class _NoAgentOverrides {
  const _NoAgentOverrides();

  List<Override> build() => [
    configFlagProvider.overrideWith(
      (ref, flagName) => Stream.value(flagName == enableAgentsFlag),
    ),
    taskAgentProvider.overrideWith((ref, id) async => null),
  ];
}

class _AgentTestBench {
  _AgentTestBench({
    AgentReportEntity? report,
    UnifiedSuggestionList suggestions = const UnifiedSuggestionList.empty(),
    bool isRunning = false,
    AgentStateEntity? state,
    bool enableAgents = true,
    MockChangeSetConfirmationService? confirmationService,
    MockUpdateNotifications? updateNotifications,
    MockTaskAgentService? taskAgentService,
  }) : _report = report,
       _suggestions = suggestions,
       _isRunning = isRunning,
       _state = state,
       _enableAgents = enableAgents,
       _confirmationService = confirmationService,
       _updateNotifications = updateNotifications,
       _taskAgentService = taskAgentService;

  static const String taskId = 'task-001';

  final AgentReportEntity? _report;
  final UnifiedSuggestionList _suggestions;
  final bool _isRunning;
  final AgentStateEntity? _state;
  final bool _enableAgents;
  final MockChangeSetConfirmationService? _confirmationService;
  final MockUpdateNotifications? _updateNotifications;
  final MockTaskAgentService? _taskAgentService;

  Widget build() {
    final identity = makeTestIdentity();
    return RiverpodWidgetTestBench(
      overrides: [
        configFlagProvider.overrideWith(
          (ref, flagName) => Stream.value(_enableAgents),
        ),
        taskAgentProvider.overrideWith((ref, id) async => identity),
        agentReportProvider.overrideWith((ref, agentId) async => _report),
        templateForAgentProvider.overrideWith((ref, agentId) async => null),
        agentIsRunningProvider.overrideWith(
          (ref, agentId) => Stream.value(_isRunning),
        ),
        agentStateProvider.overrideWith(
          (ref, agentId) async => _state,
        ),
        unifiedSuggestionListProvider.overrideWith(
          (ref, taskId) async => _suggestions,
        ),
        if (_confirmationService != null)
          changeSetConfirmationServiceProvider.overrideWith(
            (ref) => _confirmationService,
          ),
        if (_updateNotifications != null)
          updateNotificationsProvider.overrideWith(
            (ref) => _updateNotifications,
          ),
        if (_taskAgentService != null)
          taskAgentServiceProvider.overrideWith(
            (ref) => _taskAgentService,
          ),
      ],
      child: const SingleChildScrollView(
        child: AiSummaryCard(taskId: taskId),
      ),
    );
  }
}

PendingSuggestion _makePending({
  required String id,
  required String toolName,
  required String humanSummary,
  Map<String, dynamic> args = const {},
  ChangeSetEntity? changeSet,
}) {
  final cs =
      changeSet ??
      makeTestChangeSet(
        id: id,
        items: [
          ChangeItem(
            toolName: toolName,
            args: args,
            humanSummary: humanSummary,
          ),
        ],
      );
  return PendingSuggestion(
    changeSet: cs,
    itemIndex: 0,
    item: cs.items.first,
    fingerprint: 'fp-$id',
  );
}

LedgerEntry _makeLedgerEntry({
  required String id,
  required ChangeItemStatus status,
  String toolName = 'set_task_status',
  String humanSummary = 'Set status to GROOMED',
  DateTime? createdAt,
  DateTime? resolvedAt,
}) {
  return LedgerEntry(
    changeSetId: id,
    itemIndex: 0,
    toolName: toolName,
    args: const {},
    humanSummary: humanSummary,
    fingerprint: 'fp-$id',
    status: status,
    createdAt: createdAt ?? DateTime(2026, 5, 4, 9),
    resolvedAt: resolvedAt ?? DateTime(2026, 5, 4, 10),
    resolvedBy: DecisionActor.user,
    verdict: status == ChangeItemStatus.confirmed
        ? ChangeDecisionVerdict.confirmed
        : ChangeDecisionVerdict.rejected,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(makeTestChangeSet());
    registerFallbackValue(<String>{});
  });

  group('AiSummaryCard – gating and CTA', () {
    testWidgets('renders nothing when agents are disabled', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(false),
            ),
            taskAgentProvider.overrideWith((ref, id) async => null),
          ],
          child: const AiSummaryCard(taskId: 'task-001'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Assign Agent'), findsNothing);
      expect(find.text('AI summary'), findsNothing);
    });

    testWidgets('shows Assign Agent CTA when no agent is attached', (
      tester,
    ) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: const _NoAgentOverrides().build(),
          child: const AiSummaryCard(taskId: 'task-001'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Assign Agent'), findsOneWidget);
      expect(find.text('AI summary'), findsNothing);
    });
  });

  group('AiSummaryCard – TLDR', () {
    testWidgets('renders TLDR and Read more pill when an agent has a report', (
      tester,
    ) async {
      final bench = _AgentTestBench(
        report: makeTestReport(
          tldr: 'Card surface is happy.',
          content: '## Goal\nShip the card.\n',
        ),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      expect(find.text('AI summary'), findsOneWidget);
      expect(find.text('Card surface is happy.'), findsOneWidget);
      expect(find.text('Read more'), findsOneWidget);
    });

    testWidgets('Read more toggle expands and collapses the report', (
      tester,
    ) async {
      final bench = _AgentTestBench(
        report: makeTestReport(
          tldr: 'Tldr line.',
          content: '## Goal\nShip the card.\n',
        ),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Read more'));
      await tester.pumpAndSettle();
      expect(find.text('Show less'), findsOneWidget);
      expect(find.text('Open agent internals'), findsOneWidget);

      await tester.tap(find.text('Show less'));
      await tester.pumpAndSettle();
      expect(find.text('Read more'), findsOneWidget);
      expect(find.text('Open agent internals'), findsNothing);
    });

    testWidgets('Read more pill is hidden when there is no TLDR or report', (
      tester,
    ) async {
      // No report at all → no Read more pill, no TLDR body, but the card
      // shell still renders.
      await tester.pumpWidget(_AgentTestBench().build());
      await tester.pumpAndSettle();

      expect(find.text('AI summary'), findsOneWidget);
      expect(find.text('Read more'), findsNothing);
    });
  });

  group('AiSummaryCard – Proposals', () {
    testWidgets('shows empty proposals row when nothing is pending', (
      tester,
    ) async {
      await tester.pumpWidget(_AgentTestBench().build());
      await tester.pumpAndSettle();

      expect(find.text('Proposed changes'), findsOneWidget);
      expect(find.textContaining('No open proposals'), findsOneWidget);
    });

    testWidgets('renders pending proposals with kind chip and cleaned text', (
      tester,
    ) async {
      final pending = _makePending(
        id: 'p1',
        toolName: 'update_task_estimate',
        args: const {'minutes': 195},
        humanSummary: 'Estimate: 1h 30m → 3h 15m',
      );
      final bench = _AgentTestBench(
        suggestions: UnifiedSuggestionList(
          open: [pending],
          activity: const [],
        ),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      expect(find.text('Proposed changes'), findsOneWidget);
      expect(find.text('Estimate'), findsOneWidget);
      expect(find.textContaining('1h 30m → 3h 15m'), findsOneWidget);
      // The leading "Estimate:" prefix should have been stripped from the
      // body text — only the kind chip carries it.
      expect(find.textContaining('Estimate: 1h 30m'), findsNothing);
    });

    testWidgets('Confirm-all button is hidden with a single pending item', (
      tester,
    ) async {
      final bench = _AgentTestBench(
        suggestions: UnifiedSuggestionList(
          open: [
            _makePending(
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

      final bench = _AgentTestBench(
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

      // One confirmAll call per distinct change set.
      verify(() => service.confirmAll(csA)).called(1);
      verify(() => service.confirmAll(csB)).called(1);
      // Both agentIds get notified once.
      verify(() => notifier.notify(any())).called(1);
    });

    testWidgets('tap-confirm dispatches confirmItem with the correct args', (
      tester,
    ) async {
      final pending = _makePending(
        id: 'p1',
        toolName: 'set_task_status',
        humanSummary: 'Set status to GROOMED',
      );

      final service = MockChangeSetConfirmationService();
      when(() => service.confirmItem(any(), any())).thenAnswer(
        (_) async => const ToolExecutionResult(success: true, output: 'ok'),
      );
      final notifier = MockUpdateNotifications();

      final bench = _AgentTestBench(
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

      verify(() => service.confirmItem(pending.changeSet, 0)).called(1);
      verify(() => notifier.notify(any())).called(1);
    });

    testWidgets('tap-reject dispatches rejectItem and notifies the agent', (
      tester,
    ) async {
      final pending = _makePending(
        id: 'p1',
        toolName: 'set_task_status',
        humanSummary: 'Set status to GROOMED',
      );

      final service = MockChangeSetConfirmationService();
      when(() => service.rejectItem(any(), any())).thenAnswer(
        (_) async => true,
      );
      final notifier = MockUpdateNotifications();

      final bench = _AgentTestBench(
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

      verify(() => service.rejectItem(pending.changeSet, 0)).called(1);
      verify(() => notifier.notify(any())).called(1);
    });

    testWidgets('swipe-right past the threshold confirms via the service', (
      tester,
    ) async {
      final pending = _makePending(
        id: 'p1',
        toolName: 'set_task_status',
        humanSummary: 'Set status to GROOMED',
      );

      final service = MockChangeSetConfirmationService();
      when(() => service.confirmItem(any(), any())).thenAnswer(
        (_) async => const ToolExecutionResult(success: true, output: 'ok'),
      );
      final notifier = MockUpdateNotifications();

      final bench = _AgentTestBench(
        confirmationService: service,
        updateNotifications: notifier,
        suggestions: UnifiedSuggestionList(
          open: [pending],
          activity: const [],
        ),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      // The kind chip is part of the proposal row; it makes a stable
      // pointer-down target inside the Listener.
      final rowAnchor = find.text('Estimate').evaluate().isNotEmpty
          ? find.text('Estimate')
          : find.text('Status');
      // Drag past +70px: row should fire confirm.
      await tester.drag(rowAnchor, const Offset(150, 0));
      await tester.pumpAndSettle();

      verify(() => service.confirmItem(pending.changeSet, 0)).called(1);
    });

    testWidgets('swipe-left past the threshold rejects via the service', (
      tester,
    ) async {
      final pending = _makePending(
        id: 'p1',
        toolName: 'set_task_status',
        humanSummary: 'Set status to GROOMED',
      );

      final service = MockChangeSetConfirmationService();
      when(() => service.rejectItem(any(), any())).thenAnswer(
        (_) async => true,
      );
      final notifier = MockUpdateNotifications();

      final bench = _AgentTestBench(
        confirmationService: service,
        updateNotifications: notifier,
        suggestions: UnifiedSuggestionList(
          open: [pending],
          activity: const [],
        ),
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
      final pending = _makePending(
        id: 'p1',
        toolName: 'set_task_status',
        humanSummary: 'Set status to GROOMED',
      );

      final service = MockChangeSetConfirmationService();
      final notifier = MockUpdateNotifications();

      final bench = _AgentTestBench(
        confirmationService: service,
        updateNotifications: notifier,
        suggestions: UnifiedSuggestionList(
          open: [pending],
          activity: const [],
        ),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      // Below the 70px trigger.
      await tester.drag(find.text('Status'), const Offset(40, 0));
      await tester.pumpAndSettle();

      verifyNever(() => service.confirmItem(any(), any()));
      verifyNever(() => service.rejectItem(any(), any()));
    });
  });

  group('AiSummaryCard – History', () {
    testWidgets('History toggle expands and collapses resolved entries', (
      tester,
    ) async {
      final bench = _AgentTestBench(
        suggestions: UnifiedSuggestionList(
          open: const [],
          activity: [
            _makeLedgerEntry(
              id: 'h1',
              status: ChangeItemStatus.confirmed,
              humanSummary: 'Status: OPEN → GROOMED',
            ),
            _makeLedgerEntry(
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

      // Collapsed by default — entries hidden, toggle visible.
      expect(find.textContaining('History · 2'), findsOneWidget);
      expect(find.textContaining('OPEN → GROOMED'), findsNothing);

      await tester.tap(find.textContaining('History · 2'));
      await tester.pumpAndSettle();

      expect(find.textContaining('OPEN → GROOMED'), findsOneWidget);
      // Confirmed and dismissed states use distinct trailing labels.
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Dismissed'), findsOneWidget);

      // Toggle collapses again.
      await tester.tap(find.textContaining('History · 2'));
      await tester.pumpAndSettle();
      expect(find.textContaining('OPEN → GROOMED'), findsNothing);
    });
  });

  group('AiSummaryCard – Activity footer', () {
    testWidgets('hides the See activity pill when there are no entries', (
      tester,
    ) async {
      await tester.pumpWidget(_AgentTestBench().build());
      await tester.pumpAndSettle();

      expect(find.text('See activity'), findsNothing);
    });

    testWidgets(
      'See activity expands to RECENT ACTIVITY list, capped at 6 entries',
      (tester) async {
        // Eight entries — the list should clamp to six.
        final entries = [
          for (var i = 0; i < 8; i++)
            _makeLedgerEntry(
              id: 'a$i',
              status: ChangeItemStatus.confirmed,
              humanSummary: 'Activity row $i',
            ),
        ];
        final bench = _AgentTestBench(
          suggestions: UnifiedSuggestionList(
            open: const [],
            activity: entries,
          ),
        );

        await tester.pumpWidget(bench.build());
        await tester.pumpAndSettle();

        expect(find.text('See activity'), findsOneWidget);
        // Footer shows the total count (not the visible cap).
        expect(find.textContaining('8 recent actions'), findsOneWidget);

        await tester.tap(find.text('See activity'));
        await tester.pumpAndSettle();

        expect(find.text('Hide activity'), findsOneWidget);
        expect(find.text('RECENT ACTIVITY'), findsOneWidget);
        // Six rows visible (rows 0..5), rows 6/7 clipped.
        for (var i = 0; i < 6; i++) {
          expect(find.text('Activity row $i'), findsOneWidget);
        }
        expect(find.text('Activity row 6'), findsNothing);
        expect(find.text('Activity row 7'), findsNothing);

        // Collapse again.
        await tester.tap(find.text('Hide activity'));
        await tester.pumpAndSettle();
        expect(find.text('RECENT ACTIVITY'), findsNothing);
      },
    );
  });

  group('AiSummaryCard – Wake affordances', () {
    testWidgets('shows the run-now refresh affordance when the agent is idle', (
      tester,
    ) async {
      final bench = _AgentTestBench(
        report: makeTestReport(tldr: 'Tldr line.'),
      );

      await tester.pumpWidget(bench.build());
      await tester.pumpAndSettle();

      expect(find.text('AI summary'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });

    testWidgets(
      'tapping refresh triggers a re-analysis on the task agent service',
      (tester) async {
        final taskAgentService = MockTaskAgentService();
        when(
          () => taskAgentService.triggerReanalysis(any()),
        ).thenAnswer((_) {});

        final bench = _AgentTestBench(
          taskAgentService: taskAgentService,
          report: makeTestReport(tldr: 'Tldr line.'),
        );

        await tester.pumpWidget(bench.build());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.refresh_rounded));
        await tester.pumpAndSettle();

        verify(() => taskAgentService.triggerReanalysis(any())).called(1);
      },
    );

    testWidgets('countdown pill renders next to a play button when scheduled', (
      tester,
    ) async {
      // Pin clock so the countdown computation is deterministic.
      await withClock(Clock.fixed(DateTime(2026, 5, 4, 12)), () async {
        final state = makeTestState(
          nextWakeAt: DateTime(2026, 5, 4, 12, 0, 30),
        );
        final bench = _AgentTestBench(
          state: state,
          report: makeTestReport(tldr: 'Tldr line.'),
        );

        await tester.pumpWidget(bench.build());
        await tester.pumpAndSettle();

        // Run-now becomes a play button while a wake is scheduled.
        expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
        // Cancel-timer affordance sits to the right of the pill.
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);
        // The pill text formats remaining seconds as `m:ss`.
        expect(find.text('0:30'), findsOneWidget);
      });
    });

    testWidgets('cancel-timer button cancels the scheduled wake', (
      tester,
    ) async {
      await withClock(Clock.fixed(DateTime(2026, 5, 4, 12)), () async {
        final taskAgentService = MockTaskAgentService();
        when(
          () => taskAgentService.cancelScheduledWake(any()),
        ).thenAnswer((_) {});
        final state = makeTestState(
          nextWakeAt: DateTime(2026, 5, 4, 12, 0, 30),
        );

        final bench = _AgentTestBench(
          state: state,
          taskAgentService: taskAgentService,
          report: makeTestReport(tldr: 'Tldr line.'),
        );

        await tester.pumpWidget(bench.build());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        verify(() => taskAgentService.cancelScheduledWake(any())).called(1);

        // After cancel, the pill should be hidden and the run-now refresh
        // affordance returns.
        expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
        expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
      });
    });
  });

  group('AiSummaryCard – internals navigation', () {
    testWidgets('tapping the agent name pushes the AgentInternalsPanel route', (
      tester,
    ) async {
      final identity = makeTestIdentity();
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          mediaQueryData: const MediaQueryData(size: Size(900, 800)),
          overrides: [
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(true),
            ),
            taskAgentProvider.overrideWith((ref, id) async => identity),
            agentReportProvider.overrideWith(
              (ref, agentId) async => makeTestReport(tldr: 'Tldr.'),
            ),
            templateForAgentProvider.overrideWith(
              (ref, agentId) async => null,
            ),
            agentIsRunningProvider.overrideWith(
              (ref, agentId) => Stream.value(false),
            ),
            agentStateProvider.overrideWith((ref, agentId) async => null),
            unifiedSuggestionListProvider.overrideWith(
              (ref, taskId) async => const UnifiedSuggestionList.empty(),
            ),
            agentIdentityProvider.overrideWith((ref, id) async => identity),
          ],
          child: const SingleChildScrollView(
            child: AiSummaryCard(taskId: 'task-001'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The agent name link sits under the AI summary title.
      await tester.tap(find.text(identity.displayName));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The panel header surfaces the localized title.
      expect(find.text('Agent internals'), findsOneWidget);
    });
  });
}
