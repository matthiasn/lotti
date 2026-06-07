import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

import 'unified_suggestion_test_generators.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentRepository mockRepo;

  setUp(() {
    mockRepo = MockAgentRepository();
  });

  ProviderContainer build({
    required AgentIdentityEntity? agent,
    required ProposalLedger ledger,
  }) {
    when(
      () => mockRepo.getProposalLedger(
        any(),
        taskId: any(named: 'taskId'),
        changeSetFetchLimit: any(named: 'changeSetFetchLimit'),
        resolvedLimit: any(named: 'resolvedLimit'),
      ),
    ).thenAnswer((_) async => ledger);

    final container = ProviderContainer(
      overrides: [
        taskAgentProvider('task-abc').overrideWith((ref) async => agent),
        agentRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('unifiedSuggestionListProvider', () {
    glados.Glados(
      glados.any.unifiedSuggestionScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test(
      'matches generated pending filtering and activity dedup semantics',
      (scenario) async {
        final generatedRepo = MockAgentRepository();
        final notifications = UpdateNotifications();
        final agent = makeTestIdentity(
          agentId: 'generated-agent',
          displayName: 'Generated Agent',
        );
        final container = ProviderContainer(
          overrides: [
            taskAgentProvider('task-abc').overrideWith((ref) async => agent),
            agentRepositoryProvider.overrideWithValue(generatedRepo),
            updateNotificationsProvider.overrideWithValue(notifications),
          ],
        );

        when(
          () => generatedRepo.getProposalLedger(
            any(),
            taskId: any(named: 'taskId'),
            changeSetFetchLimit: any(named: 'changeSetFetchLimit'),
            resolvedLimit: any(named: 'resolvedLimit'),
          ),
        ).thenAnswer((_) async => scenario.ledger);

        final sub = container.listen(
          unifiedSuggestionListProvider('task-abc'),
          (_, _) {},
        );

        try {
          final result = await container.read(
            unifiedSuggestionListProvider('task-abc').future,
          );

          final actualOpen = [
            for (final suggestion in result.open)
              (
                changeSetId: suggestion.changeSet.id,
                itemIndex: suggestion.itemIndex,
                toolName: suggestion.item.toolName,
                args: suggestion.item.args,
                humanSummary: suggestion.item.humanSummary,
                fingerprint: suggestion.fingerprint,
              ),
          ];
          final actualActivity = [
            for (final entry in result.activity)
              (
                changeSetId: entry.changeSetId,
                fingerprint: entry.fingerprint,
                status: entry.status,
                verdict: entry.verdict,
                resolvedBy: entry.resolvedBy,
              ),
          ];

          expect(actualOpen, scenario.expectedOpen, reason: '$scenario');
          expect(
            actualActivity,
            scenario.expectedActivity,
            reason: '$scenario',
          );
          expect(result.agentName, 'Generated Agent');

          verify(
            () => generatedRepo.getProposalLedger(
              'generated-agent',
              taskId: 'task-abc',
              changeSetFetchLimit: any(named: 'changeSetFetchLimit'),
              resolvedLimit: any(named: 'resolvedLimit'),
            ),
          ).called(1);
        } finally {
          sub.close();
          container.dispose();
          await notifications.dispose();
        }
      },
      tags: 'glados',
    );

    test('returns empty list when the task has no agent', () async {
      final container = build(
        agent: null,
        ledger: const ProposalLedger.empty(),
      );

      final sub = container.listen(
        unifiedSuggestionListProvider('task-abc'),
        (_, _) {},
      );
      addTearDown(sub.close);

      final result = await container.read(
        unifiedSuggestionListProvider('task-abc').future,
      );

      expect(result.isEmpty, isTrue);
      verifyNever(
        () => mockRepo.getProposalLedger(
          any(),
          taskId: any(named: 'taskId'),
          changeSetFetchLimit: any(named: 'changeSetFetchLimit'),
          resolvedLimit: any(named: 'resolvedLimit'),
        ),
      );
    });

    test(
      'builds one PendingSuggestion per pending item in ledger.pendingSets',
      () async {
        final agent = makeTestIdentity();
        final pendingSet = makeTestChangeSet(
          id: 'cs-1',
          agentId: agent.agentId,
          taskId: 'task-abc',
          items: const [
            ChangeItem(
              toolName: 'set_task_title',
              args: {'title': 'Hello'},
              humanSummary: 'Rename task',
            ),
            ChangeItem(
              toolName: 'update_task_priority',
              args: {'priority': 'P1'},
              humanSummary: 'Set priority to P1',
            ),
          ],
        );

        final container = build(
          agent: agent,
          ledger: ProposalLedger(
            open: const [],
            resolved: const [],
            pendingSets: [pendingSet],
          ),
        );
        final sub = container.listen(
          unifiedSuggestionListProvider('task-abc'),
          (_, _) {},
        );
        addTearDown(sub.close);

        final result = await container.read(
          unifiedSuggestionListProvider('task-abc').future,
        );

        expect(result.open, hasLength(2));
        expect(result.open[0].changeSet.id, 'cs-1');
        expect(result.open[0].item.toolName, 'set_task_title');
        expect(
          result.open[0].fingerprint,
          ChangeItem.fingerprintFromParts('set_task_title', const {
            'title': 'Hello',
          }),
        );
        expect(result.open[1].item.toolName, 'update_task_priority');
      },
    );

    test(
      'skips non-pending items inside a partiallyResolved change set',
      () async {
        final agent = makeTestIdentity();
        final pendingSet = makeTestChangeSet(
          id: 'cs-mixed',
          agentId: agent.agentId,
          taskId: 'task-abc',
          status: ChangeSetStatus.partiallyResolved,
          items: const [
            ChangeItem(
              toolName: 'set_task_title',
              args: {'title': 'Confirmed'},
              humanSummary: 'Already confirmed',
              status: ChangeItemStatus.confirmed,
            ),
            ChangeItem(
              toolName: 'update_task_priority',
              args: {'priority': 'P1'},
              humanSummary: 'Still pending',
            ),
            ChangeItem(
              toolName: 'set_task_status',
              args: {'status': 'IN_PROGRESS'},
              humanSummary: 'User rejected',
              status: ChangeItemStatus.rejected,
            ),
            ChangeItem(
              toolName: 'update_task_estimate',
              args: {'minutes': 60},
              humanSummary: 'Agent retracted',
              status: ChangeItemStatus.retracted,
            ),
          ],
        );

        final container = build(
          agent: agent,
          ledger: ProposalLedger(
            open: const [],
            resolved: const [],
            pendingSets: [pendingSet],
          ),
        );
        final sub = container.listen(
          unifiedSuggestionListProvider('task-abc'),
          (_, _) {},
        );
        addTearDown(sub.close);

        final result = await container.read(
          unifiedSuggestionListProvider('task-abc').future,
        );

        expect(result.open, hasLength(1));
        expect(result.open.single.item.toolName, 'update_task_priority');
      },
    );

    test(
      'deduplicates items that share a fingerprint across change sets',
      () async {
        final agent = makeTestIdentity();
        final earlier = makeTestChangeSet(
          id: 'cs-old',
          agentId: agent.agentId,
          taskId: 'task-abc',
          createdAt: DateTime(2026, 4, 18, 9),
          items: const [
            ChangeItem(
              toolName: 'set_task_title',
              args: {'title': 'Hello'},
              humanSummary: 'Rename task (old wake)',
            ),
          ],
        );
        final newer = makeTestChangeSet(
          id: 'cs-new',
          agentId: agent.agentId,
          taskId: 'task-abc',
          createdAt: DateTime(2026, 4, 18, 10),
          items: const [
            ChangeItem(
              toolName: 'set_task_title',
              args: {'title': 'Hello'},
              humanSummary: 'Rename task (new wake)',
            ),
          ],
        );

        final container = build(
          agent: agent,
          ledger: ProposalLedger(
            open: const [],
            resolved: const [],
            pendingSets: [newer, earlier],
          ),
        );
        final sub = container.listen(
          unifiedSuggestionListProvider('task-abc'),
          (_, _) {},
        );
        addTearDown(sub.close);

        final result = await container.read(
          unifiedSuggestionListProvider('task-abc').future,
        );

        expect(result.open, hasLength(1));
        // First occurrence wins; iteration order is by pendingSets input
        // order (newer first as supplied by the repository).
        expect(result.open.single.changeSet.id, 'cs-new');
      },
    );

    test(
      'deduplicates verbatim visible suggestions across change sets',
      () async {
        final agent = makeTestIdentity();
        const summary = 'Check off: "Address CodeRabbit review comments"';
        final earlier = makeTestChangeSet(
          id: 'cs-old-visible',
          agentId: agent.agentId,
          taskId: 'task-abc',
          createdAt: DateTime(2026, 4, 18, 9),
          items: const [
            ChangeItem(
              toolName: 'update_checklist_item',
              args: {'id': 'old-item-id', 'isChecked': true},
              humanSummary: summary,
            ),
          ],
        );
        final newer = makeTestChangeSet(
          id: 'cs-new-visible',
          agentId: agent.agentId,
          taskId: 'task-abc',
          createdAt: DateTime(2026, 4, 18, 10),
          items: const [
            ChangeItem(
              toolName: 'update_checklist_item',
              args: {'id': 'new-item-id', 'isChecked': true},
              humanSummary: summary,
            ),
          ],
        );

        final container = build(
          agent: agent,
          ledger: ProposalLedger(
            open: const [],
            resolved: const [],
            pendingSets: [newer, earlier],
          ),
        );
        final sub = container.listen(
          unifiedSuggestionListProvider('task-abc'),
          (_, _) {},
        );
        addTearDown(sub.close);

        final result = await container.read(
          unifiedSuggestionListProvider('task-abc').future,
        );

        expect(result.open, hasLength(1));
        expect(result.open.single.changeSet.id, 'cs-new-visible');
        expect(result.open.single.item.humanSummary, summary);
      },
    );

    test(
      'keeps same-summary running timer suggestions for different timers',
      () async {
        final agent = makeTestIdentity();
        const summary = 'Update running timer text: "Focus block"';
        final changeSet = makeTestChangeSet(
          id: 'cs-running-visible',
          agentId: agent.agentId,
          taskId: 'task-abc',
          createdAt: DateTime(2026, 4, 18, 10),
          items: const [
            ChangeItem(
              toolName: TaskAgentToolNames.updateRunningTimer,
              args: {
                'timerId': 'timer-1',
                'summary': 'Focus block',
              },
              humanSummary: summary,
            ),
            ChangeItem(
              toolName: TaskAgentToolNames.updateRunningTimer,
              args: {
                'timerId': 'timer-2',
                'summary': 'Focus block',
              },
              humanSummary: summary,
            ),
          ],
        );

        final container = build(
          agent: agent,
          ledger: ProposalLedger(
            open: const [],
            resolved: const [],
            pendingSets: [changeSet],
          ),
        );
        final sub = container.listen(
          unifiedSuggestionListProvider('task-abc'),
          (_, _) {},
        );
        addTearDown(sub.close);

        final result = await container.read(
          unifiedSuggestionListProvider('task-abc').future,
        );

        expect(result.open, hasLength(2));
        expect(
          result.open
              .map((suggestion) => suggestion.item.args['timerId'])
              .toSet(),
          {'timer-1', 'timer-2'},
        );
      },
    );

    test(
      'keeps only the latest pending running timer update visible',
      () async {
        final agent = makeTestIdentity();
        final older = makeTestChangeSet(
          id: 'cs-old-running',
          agentId: agent.agentId,
          taskId: 'task-abc',
          createdAt: DateTime(2026, 4, 18, 9),
          items: const [
            ChangeItem(
              toolName: TaskAgentToolNames.updateRunningTimer,
              args: {
                'timerId': 'timer-1',
                'summary': 'Earlier timer text',
              },
              humanSummary: 'Update running timer text: "Earlier timer text"',
            ),
            ChangeItem(
              toolName: TaskAgentToolNames.updateRunningTimer,
              args: {
                'timerId': 'timer-2',
                'summary': 'Other timer text',
              },
              humanSummary: 'Update running timer text: "Other timer text"',
            ),
          ],
        );
        final newer = makeTestChangeSet(
          id: 'cs-new-running',
          agentId: agent.agentId,
          taskId: 'task-abc',
          createdAt: DateTime(2026, 4, 18, 10),
          items: const [
            ChangeItem(
              toolName: TaskAgentToolNames.updateRunningTimer,
              args: {
                'timerId': 'timer-1',
                'summary': 'Latest timer text',
              },
              humanSummary: 'Update running timer text: "Latest timer text"',
            ),
            ChangeItem(
              toolName: 'update_task_priority',
              args: {'priority': 'P1'},
              humanSummary: 'Set priority to P1',
            ),
          ],
        );

        final container = build(
          agent: agent,
          ledger: ProposalLedger(
            open: const [],
            resolved: const [],
            pendingSets: [older, newer],
          ),
        );
        final sub = container.listen(
          unifiedSuggestionListProvider('task-abc'),
          (_, _) {},
        );
        addTearDown(sub.close);

        final result = await container.read(
          unifiedSuggestionListProvider('task-abc').future,
        );

        final runningTimerSuggestions = result.open
            .where(
              (suggestion) =>
                  suggestion.item.toolName ==
                  TaskAgentToolNames.updateRunningTimer,
            )
            .toList();
        expect(
          runningTimerSuggestions.map((suggestion) {
            return (
              suggestion.changeSet.id,
              suggestion.item.args['timerId'],
              suggestion.item.args['summary'],
            );
          }),
          [
            ('cs-new-running', 'timer-1', 'Latest timer text'),
            ('cs-old-running', 'timer-2', 'Other timer text'),
          ],
        );
        expect(
          result.open.where((s) => s.item.toolName == 'update_task_priority'),
          hasLength(1),
        );
      },
    );

    test(
      'sorts open items newest-first by parent change set createdAt',
      () async {
        final agent = makeTestIdentity();
        final older = makeTestChangeSet(
          id: 'cs-older',
          agentId: agent.agentId,
          taskId: 'task-abc',
          createdAt: DateTime(2026, 4, 18, 8),
          items: const [
            ChangeItem(
              toolName: 'set_task_title',
              args: {'title': 'Old'},
              humanSummary: 'Old proposal',
            ),
          ],
        );
        final newer = makeTestChangeSet(
          id: 'cs-newer',
          agentId: agent.agentId,
          taskId: 'task-abc',
          createdAt: DateTime(2026, 4, 18, 12),
          items: const [
            ChangeItem(
              toolName: 'update_task_priority',
              args: {'priority': 'P2'},
              humanSummary: 'New proposal',
            ),
          ],
        );

        final container = build(
          agent: agent,
          ledger: ProposalLedger(
            open: const [],
            resolved: const [],
            pendingSets: [older, newer],
          ),
        );
        final sub = container.listen(
          unifiedSuggestionListProvider('task-abc'),
          (_, _) {},
        );
        addTearDown(sub.close);

        final result = await container.read(
          unifiedSuggestionListProvider('task-abc').future,
        );

        expect(result.open.map((s) => s.item.humanSummary).toList(), [
          'New proposal',
          'Old proposal',
        ]);
      },
    );

    test('passes resolved entries through as activity', () async {
      final agent = makeTestIdentity();
      final resolved = LedgerEntry(
        changeSetId: 'cs-old',
        itemIndex: 0,
        toolName: 'set_task_title',
        args: const {'title': 'Done'},
        humanSummary: 'Renamed',
        fingerprint: 'fp-x',
        status: ChangeItemStatus.confirmed,
        createdAt: DateTime(2026, 4, 17),
        resolvedAt: DateTime(2026, 4, 17, 1),
        resolvedBy: DecisionActor.user,
        verdict: ChangeDecisionVerdict.confirmed,
      );

      final container = build(
        agent: agent,
        ledger: ProposalLedger(
          open: const [],
          resolved: [resolved],
        ),
      );
      final sub = container.listen(
        unifiedSuggestionListProvider('task-abc'),
        (_, _) {},
      );
      addTearDown(sub.close);

      final result = await container.read(
        unifiedSuggestionListProvider('task-abc').future,
      );

      expect(result.open, isEmpty);
      expect(result.activity, hasLength(1));
      expect(result.activity.single.verdict, ChangeDecisionVerdict.confirmed);
      expect(result.activity.single.resolvedBy, DecisionActor.user);
    });

    test(
      'dedupes activity entries by fingerprint, keeping the newest decision',
      () async {
        // Repository ledger is newest-first and may emit multiple
        // decision entries for the same `(toolName, args)` fingerprint
        // (e.g. the same proposal confirmed across two separate change
        // sets). The UI strip must collapse those to one row.
        final agent = makeTestIdentity();
        LedgerEntry entry({
          required String changeSetId,
          required DateTime resolvedAt,
        }) => LedgerEntry(
          changeSetId: changeSetId,
          itemIndex: 0,
          toolName: 'update_checklist_item',
          args: const {'id': 'chk-1', 'isChecked': true},
          humanSummary: 'Check off: "Buy milk"',
          fingerprint: 'update_checklist_item:chk-1',
          status: ChangeItemStatus.confirmed,
          createdAt: resolvedAt,
          resolvedAt: resolvedAt,
          resolvedBy: DecisionActor.user,
          verdict: ChangeDecisionVerdict.confirmed,
        );

        // Newest-first, as the repository produces them.
        final newest = entry(
          changeSetId: 'cs-new',
          resolvedAt: DateTime(2026, 4, 19, 10),
        );
        final older = entry(
          changeSetId: 'cs-old',
          resolvedAt: DateTime(2026, 4, 17),
        );

        final container = build(
          agent: agent,
          ledger: ProposalLedger(
            open: const [],
            resolved: [newest, older],
          ),
        );
        final sub = container.listen(
          unifiedSuggestionListProvider('task-abc'),
          (_, _) {},
        );
        addTearDown(sub.close);

        final result = await container.read(
          unifiedSuggestionListProvider('task-abc').future,
        );

        expect(result.activity, hasLength(1));
        expect(result.activity.single.changeSetId, 'cs-new');
      },
    );

    test(
      'preserves activity entries with distinct fingerprints even when '
      'they share a human summary',
      () async {
        // Two decisions whose `humanSummary` happens to read identically
        // (e.g. checking off two different checklist items that share a
        // title) must not collapse — the fingerprints differ.
        final agent = makeTestIdentity();
        LedgerEntry entry({required String itemId, required String fp}) =>
            LedgerEntry(
              changeSetId: 'cs-shared',
              itemIndex: 0,
              toolName: 'update_checklist_item',
              args: {'id': itemId, 'isChecked': true},
              humanSummary: 'Check off: "Same title"',
              fingerprint: fp,
              status: ChangeItemStatus.confirmed,
              createdAt: DateTime(2026, 4, 19),
              resolvedAt: DateTime(2026, 4, 19, 1),
              resolvedBy: DecisionActor.user,
              verdict: ChangeDecisionVerdict.confirmed,
            );

        final container = build(
          agent: agent,
          ledger: ProposalLedger(
            open: const [],
            resolved: [
              entry(itemId: 'chk-a', fp: 'fp-a'),
              entry(itemId: 'chk-b', fp: 'fp-b'),
            ],
          ),
        );
        final sub = container.listen(
          unifiedSuggestionListProvider('task-abc'),
          (_, _) {},
        );
        addTearDown(sub.close);

        final result = await container.read(
          unifiedSuggestionListProvider('task-abc').future,
        );

        expect(result.activity, hasLength(2));
      },
    );
  });

  group('debugKeepLatestRunningTimerUpdate (pure dedup property)', () {
    String? timerIdOf(PendingSuggestion s) {
      final raw = s.item.args['timerId'];
      if (raw is! String) return null;
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    glados.Glados(
      glados.any.timerDedupSpecs,
      glados.ExploreConfig(numRuns: 120),
    ).test('keeps exactly the newest update per timer id and passes '
        'non-timer items through unchanged', (specs) {
      final base = DateTime(2026, 5, 24, 9);
      final input = <PendingSuggestion>[];
      for (final (i, spec) in specs.indexed) {
        final item = ChangeItem(
          toolName: spec.isTimerUpdate
              ? TaskAgentToolNames.updateRunningTimer
              : 'set_task_title',
          args: {
            if (spec.isTimerUpdate && spec.rawTimerId != null)
              'timerId': spec.rawTimerId,
            'note': 'n$i',
          },
          humanSummary: 'entry $i',
        );
        input.add(
          PendingSuggestion(
            changeSet: makeTestChangeSet(
              id: 'cs-$i',
              createdAt: base.add(Duration(minutes: spec.createdAtMinutes)),
              items: [item],
            ),
            itemIndex: spec.itemIndex,
            item: item,
            fingerprint: 'fp-$i',
          ),
        );
      }

      final result = debugKeepLatestRunningTimerUpdate(input);

      // Oracle: newest createdAt per timer id, ties broken by the higher
      // itemIndex, first-seen wins exact ties — mirroring the documented
      // contract.
      final winners = <String?, PendingSuggestion>{};
      for (final s in input) {
        if (s.item.toolName != TaskAgentToolNames.updateRunningTimer) {
          continue;
        }
        final id = timerIdOf(s);
        final current = winners[id];
        if (current == null ||
            s.changeSet.createdAt.isAfter(current.changeSet.createdAt) ||
            (s.changeSet.createdAt == current.changeSet.createdAt &&
                s.itemIndex > current.itemIndex)) {
          winners[id] = s;
        }
      }
      final expected = input
          .where(
            (s) =>
                s.item.toolName != TaskAgentToolNames.updateRunningTimer ||
                identical(s, winners[timerIdOf(s)]),
          )
          .toList();

      // Same instances, same relative order (identity equality).
      expect(result, expected, reason: '$specs');

      // Explicit invariants on top of the oracle comparison:
      expect(result.length, lessThanOrEqualTo(input.length));
      final nonTimer = input
          .where(
            (s) => s.item.toolName != TaskAgentToolNames.updateRunningTimer,
          )
          .toList();
      for (final s in nonTimer) {
        expect(result, contains(s), reason: 'non-timer item must survive');
      }
      final survivingTimerIds = result
          .where(
            (s) => s.item.toolName == TaskAgentToolNames.updateRunningTimer,
          )
          .map(timerIdOf)
          .toList();
      expect(
        survivingTimerIds.toSet().length,
        survivingTimerIds.length,
        reason: 'at most one timer update per timer id',
      );
    }, tags: 'glados');
  });
}
