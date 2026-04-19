import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/agents/state/unified_suggestion_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

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
}
