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
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

enum _GeneratedSuggestionItemStatusSlot {
  pending,
  confirmed,
  rejected,
  deferred,
  retracted,
}

enum _GeneratedSuggestionFingerprintSlot {
  title,
  priority,
  status,
  estimate,
  checklist,
}

enum _GeneratedSuggestionCreatedAtSlot { oldest, older, middle, newer, newest }

enum _GeneratedSuggestionVerdictSlot {
  confirmed,
  rejected,
  deferred,
  retracted,
}

typedef _GeneratedOpenSuggestionExpectation = ({
  String changeSetId,
  int itemIndex,
  String toolName,
  Map<String, dynamic> args,
  String humanSummary,
  String fingerprint,
});

typedef _GeneratedActivityExpectation = ({
  String changeSetId,
  String fingerprint,
  ChangeItemStatus status,
  ChangeDecisionVerdict? verdict,
  DecisionActor? resolvedBy,
});

final _generatedSuggestionBase = DateTime(2026, 5, 24, 9);

ChangeItemStatus _generatedSuggestionStatus(
  _GeneratedSuggestionItemStatusSlot slot,
) {
  return switch (slot) {
    _GeneratedSuggestionItemStatusSlot.pending => ChangeItemStatus.pending,
    _GeneratedSuggestionItemStatusSlot.confirmed => ChangeItemStatus.confirmed,
    _GeneratedSuggestionItemStatusSlot.rejected => ChangeItemStatus.rejected,
    _GeneratedSuggestionItemStatusSlot.deferred => ChangeItemStatus.deferred,
    _GeneratedSuggestionItemStatusSlot.retracted => ChangeItemStatus.retracted,
  };
}

ChangeDecisionVerdict _generatedSuggestionVerdict(
  _GeneratedSuggestionVerdictSlot slot,
) {
  return switch (slot) {
    _GeneratedSuggestionVerdictSlot.confirmed =>
      ChangeDecisionVerdict.confirmed,
    _GeneratedSuggestionVerdictSlot.rejected => ChangeDecisionVerdict.rejected,
    _GeneratedSuggestionVerdictSlot.deferred => ChangeDecisionVerdict.deferred,
    _GeneratedSuggestionVerdictSlot.retracted =>
      ChangeDecisionVerdict.retracted,
  };
}

ChangeItemStatus _generatedSuggestionStatusForVerdict(
  ChangeDecisionVerdict verdict,
) {
  return switch (verdict) {
    ChangeDecisionVerdict.confirmed => ChangeItemStatus.confirmed,
    ChangeDecisionVerdict.rejected => ChangeItemStatus.rejected,
    ChangeDecisionVerdict.deferred => ChangeItemStatus.deferred,
    ChangeDecisionVerdict.retracted => ChangeItemStatus.retracted,
  };
}

DecisionActor _generatedSuggestionActorForVerdict(
  ChangeDecisionVerdict verdict,
) {
  return switch (verdict) {
    ChangeDecisionVerdict.retracted => DecisionActor.agent,
    _ => DecisionActor.user,
  };
}

DateTime _generatedSuggestionCreatedAt(
  _GeneratedSuggestionCreatedAtSlot slot,
  int index,
) {
  final hours = switch (slot) {
    _GeneratedSuggestionCreatedAtSlot.oldest => 0,
    _GeneratedSuggestionCreatedAtSlot.older => 4,
    _GeneratedSuggestionCreatedAtSlot.middle => 8,
    _GeneratedSuggestionCreatedAtSlot.newer => 12,
    _GeneratedSuggestionCreatedAtSlot.newest => 16,
  };
  return _generatedSuggestionBase.add(Duration(hours: hours, seconds: index));
}

String _generatedSuggestionToolName(
  _GeneratedSuggestionFingerprintSlot slot,
) {
  return switch (slot) {
    _GeneratedSuggestionFingerprintSlot.title => 'set_task_title',
    _GeneratedSuggestionFingerprintSlot.priority => 'update_task_priority',
    _GeneratedSuggestionFingerprintSlot.status => 'set_task_status',
    _GeneratedSuggestionFingerprintSlot.estimate => 'update_task_estimate',
    _GeneratedSuggestionFingerprintSlot.checklist => 'update_checklist_item',
  };
}

Map<String, dynamic> _generatedSuggestionArgs(
  _GeneratedSuggestionFingerprintSlot slot,
) {
  return switch (slot) {
    _GeneratedSuggestionFingerprintSlot.title => const {
      'title': 'Generated title',
    },
    _GeneratedSuggestionFingerprintSlot.priority => const {'priority': 'P1'},
    _GeneratedSuggestionFingerprintSlot.status => const {
      'status': 'IN_PROGRESS',
    },
    _GeneratedSuggestionFingerprintSlot.estimate => const {'minutes': 45},
    _GeneratedSuggestionFingerprintSlot.checklist => const {
      'id': 'generated-checklist-item',
      'isChecked': true,
    },
  };
}

class _GeneratedSuggestionItemSpec {
  const _GeneratedSuggestionItemSpec({
    required this.fingerprintSlot,
    required this.statusSlot,
  });

  final _GeneratedSuggestionFingerprintSlot fingerprintSlot;
  final _GeneratedSuggestionItemStatusSlot statusSlot;

  ChangeItem item(int changeSetIndex, int itemIndex) {
    return ChangeItem(
      toolName: _generatedSuggestionToolName(fingerprintSlot),
      args: _generatedSuggestionArgs(fingerprintSlot),
      humanSummary:
          'Generated proposal ${fingerprintSlot.name} '
          '$changeSetIndex/$itemIndex/${statusSlot.name}',
      status: _generatedSuggestionStatus(statusSlot),
    );
  }

  @override
  String toString() {
    return '_GeneratedSuggestionItemSpec('
        'fingerprintSlot: $fingerprintSlot, statusSlot: $statusSlot)';
  }
}

class _GeneratedSuggestionChangeSetSpec {
  const _GeneratedSuggestionChangeSetSpec({
    required this.createdAtSlot,
    required this.items,
  });

  final _GeneratedSuggestionCreatedAtSlot createdAtSlot;
  final List<_GeneratedSuggestionItemSpec> items;

  String id(int index) => 'generated-change-set-$index';

  DateTime createdAt(int index) => _generatedSuggestionCreatedAt(
    createdAtSlot,
    index,
  );

  ChangeSetEntity changeSet(int index) {
    final changeItems = [
      for (final (itemIndex, item) in items.indexed)
        item.item(index, itemIndex),
    ];
    return makeTestChangeSet(
      id: id(index),
      agentId: 'generated-agent',
      taskId: 'task-abc',
      status: ChangeItem.deriveSetStatus(changeItems),
      items: changeItems,
      createdAt: createdAt(index),
    );
  }

  @override
  String toString() {
    return '_GeneratedSuggestionChangeSetSpec('
        'createdAtSlot: $createdAtSlot, items: $items)';
  }
}

class _GeneratedSuggestionActivitySpec {
  const _GeneratedSuggestionActivitySpec({
    required this.fingerprintSlot,
    required this.verdictSlot,
    required this.createdAtSlot,
  });

  final _GeneratedSuggestionFingerprintSlot fingerprintSlot;
  final _GeneratedSuggestionVerdictSlot verdictSlot;
  final _GeneratedSuggestionCreatedAtSlot createdAtSlot;

  String id(int index) => 'generated-activity-change-set-$index';

  LedgerEntry entry(int index) {
    final verdict = _generatedSuggestionVerdict(verdictSlot);
    final args = _generatedSuggestionArgs(fingerprintSlot);
    final toolName = _generatedSuggestionToolName(fingerprintSlot);
    return LedgerEntry(
      changeSetId: id(index),
      itemIndex: index,
      toolName: toolName,
      args: args,
      humanSummary:
          'Generated activity ${fingerprintSlot.name}/${verdictSlot.name}',
      fingerprint: ChangeItem.fingerprintFromParts(toolName, args),
      status: _generatedSuggestionStatusForVerdict(verdict),
      createdAt: _generatedSuggestionCreatedAt(createdAtSlot, index),
      resolvedAt: _generatedSuggestionCreatedAt(createdAtSlot, index).add(
        const Duration(minutes: 1),
      ),
      resolvedBy: _generatedSuggestionActorForVerdict(verdict),
      verdict: verdict,
    );
  }

  @override
  String toString() {
    return '_GeneratedSuggestionActivitySpec('
        'fingerprintSlot: $fingerprintSlot, verdictSlot: $verdictSlot, '
        'createdAtSlot: $createdAtSlot)';
  }
}

class _GeneratedUnifiedSuggestionScenario {
  const _GeneratedUnifiedSuggestionScenario({
    required this.changeSets,
    required this.activity,
  });

  final List<_GeneratedSuggestionChangeSetSpec> changeSets;
  final List<_GeneratedSuggestionActivitySpec> activity;

  List<ChangeSetEntity> get pendingSets => [
    for (final (index, spec) in changeSets.indexed) spec.changeSet(index),
  ];

  // Sorted newest-first to mirror the repository contract the provider
  // relies on (see unifiedSuggestionList): first occurrence of each
  // fingerprint after dedup is the most recent decision.
  List<LedgerEntry> get resolvedEntries {
    return [
      for (final (index, spec) in activity.indexed) spec.entry(index),
    ]..sort((a, b) => b.resolvedAt!.compareTo(a.resolvedAt!));
  }

  ProposalLedger get ledger => ProposalLedger(
    open: const [],
    resolved: resolvedEntries,
    pendingSets: pendingSets,
  );

  List<_GeneratedOpenSuggestionExpectation> get expectedOpen {
    final seen = <String>{};
    final open = <_GeneratedOpenSuggestionExpectation>[];
    for (final changeSet in pendingSets) {
      for (final (itemIndex, item) in changeSet.items.indexed) {
        if (item.status != ChangeItemStatus.pending) continue;
        final fingerprint = ChangeItem.fingerprint(item);
        if (!seen.add(fingerprint)) continue;
        open.add(
          (
            changeSetId: changeSet.id,
            itemIndex: itemIndex,
            toolName: item.toolName,
            args: item.args,
            humanSummary: item.humanSummary,
            fingerprint: fingerprint,
          ),
        );
      }
    }
    open.sort((a, b) {
      final aSet = pendingSets.singleWhere((set) => set.id == a.changeSetId);
      final bSet = pendingSets.singleWhere((set) => set.id == b.changeSetId);
      return bSet.createdAt.compareTo(aSet.createdAt);
    });
    return open;
  }

  List<_GeneratedActivityExpectation> get expectedActivity {
    final seen = <String>{};
    return [
      for (final entry in resolvedEntries)
        if (seen.add(entry.fingerprint))
          (
            changeSetId: entry.changeSetId,
            fingerprint: entry.fingerprint,
            status: entry.status,
            verdict: entry.verdict,
            resolvedBy: entry.resolvedBy,
          ),
    ];
  }

  @override
  String toString() {
    return '_GeneratedUnifiedSuggestionScenario('
        'changeSets: $changeSets, activity: $activity)';
  }
}

extension _AnyGeneratedUnifiedSuggestionScenario on glados.Any {
  glados.Generator<_GeneratedSuggestionItemStatusSlot>
  get suggestionItemStatusSlot =>
      glados.AnyUtils(this).choose(_GeneratedSuggestionItemStatusSlot.values);

  glados.Generator<_GeneratedSuggestionFingerprintSlot>
  get suggestionFingerprintSlot =>
      glados.AnyUtils(this).choose(_GeneratedSuggestionFingerprintSlot.values);

  glados.Generator<_GeneratedSuggestionCreatedAtSlot>
  get suggestionCreatedAtSlot =>
      glados.AnyUtils(this).choose(_GeneratedSuggestionCreatedAtSlot.values);

  glados.Generator<_GeneratedSuggestionVerdictSlot> get suggestionVerdictSlot =>
      glados.AnyUtils(this).choose(_GeneratedSuggestionVerdictSlot.values);

  glados.Generator<_GeneratedSuggestionItemSpec> get suggestionItemSpec =>
      glados.CombinableAny(this).combine2(
        suggestionFingerprintSlot,
        suggestionItemStatusSlot,
        (
          _GeneratedSuggestionFingerprintSlot fingerprintSlot,
          _GeneratedSuggestionItemStatusSlot statusSlot,
        ) => _GeneratedSuggestionItemSpec(
          fingerprintSlot: fingerprintSlot,
          statusSlot: statusSlot,
        ),
      );

  glados.Generator<_GeneratedSuggestionChangeSetSpec>
  get suggestionChangeSetSpec => glados.CombinableAny(this).combine2(
    suggestionCreatedAtSlot,
    glados.ListAnys(this).listWithLengthInRange(0, 6, suggestionItemSpec),
    (
      _GeneratedSuggestionCreatedAtSlot createdAtSlot,
      List<_GeneratedSuggestionItemSpec> items,
    ) => _GeneratedSuggestionChangeSetSpec(
      createdAtSlot: createdAtSlot,
      items: items,
    ),
  );

  glados.Generator<_GeneratedSuggestionActivitySpec>
  get suggestionActivitySpec => glados.CombinableAny(this).combine3(
    suggestionFingerprintSlot,
    suggestionVerdictSlot,
    suggestionCreatedAtSlot,
    (
      _GeneratedSuggestionFingerprintSlot fingerprintSlot,
      _GeneratedSuggestionVerdictSlot verdictSlot,
      _GeneratedSuggestionCreatedAtSlot createdAtSlot,
    ) => _GeneratedSuggestionActivitySpec(
      fingerprintSlot: fingerprintSlot,
      verdictSlot: verdictSlot,
      createdAtSlot: createdAtSlot,
    ),
  );

  glados.Generator<_GeneratedUnifiedSuggestionScenario>
  get unifiedSuggestionScenario => glados.CombinableAny(this).combine2(
    glados.ListAnys(
      this,
    ).listWithLengthInRange(0, 8, suggestionChangeSetSpec),
    glados.ListAnys(this).listWithLengthInRange(0, 10, suggestionActivitySpec),
    (
      List<_GeneratedSuggestionChangeSetSpec> changeSets,
      List<_GeneratedSuggestionActivitySpec> activity,
    ) => _GeneratedUnifiedSuggestionScenario(
      changeSets: changeSets,
      activity: activity,
    ),
  );
}

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
