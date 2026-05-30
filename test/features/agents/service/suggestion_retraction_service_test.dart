import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/service/suggestion_retraction_service.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

enum _GeneratedRetractionItemKind { priority, title, estimate }

enum _GeneratedRetractionRequestSlot { priority, title, estimate, missing }

enum _GeneratedRetractionRereadSlot {
  latest,
  missing,
  allConfirmed,
  truncatedLast,
}

enum _ExpectedRetractionUpsertKind { decision, changeSet }

class _GeneratedRetractionItemSpec {
  const _GeneratedRetractionItemSpec({
    required this.kind,
    required this.status,
  });

  final _GeneratedRetractionItemKind kind;
  final ChangeItemStatus status;

  @override
  String toString() {
    return '_GeneratedRetractionItemSpec(kind: $kind, status: $status)';
  }
}

class _GeneratedRetractionSetSpec {
  const _GeneratedRetractionSetSpec({
    required this.items,
    required this.rereadSlot,
  });

  final List<_GeneratedRetractionItemSpec> items;
  final _GeneratedRetractionRereadSlot rereadSlot;

  @override
  String toString() {
    return '_GeneratedRetractionSetSpec('
        'items: $items, rereadSlot: $rereadSlot)';
  }
}

class _GeneratedRetractionScenario {
  const _GeneratedRetractionScenario({
    required this.sets,
    required this.requests,
  });

  final List<_GeneratedRetractionSetSpec> sets;
  final List<_GeneratedRetractionRequestSlot> requests;

  @override
  String toString() {
    return '_GeneratedRetractionScenario(sets: $sets, requests: $requests)';
  }
}

/// Scenario for the `applyStaged` churn guard: a list of staged item kinds
/// (each in its own single-item change set) plus the kinds whose fingerprints
/// are being re-proposed this wake and must therefore be skipped.
class _GeneratedSkipScenario {
  const _GeneratedSkipScenario({
    required this.stagedKinds,
    required this.skipKinds,
  });

  final List<_GeneratedRetractionItemKind> stagedKinds;
  final List<_GeneratedRetractionItemKind> skipKinds;

  @override
  String toString() {
    return '_GeneratedSkipScenario(stagedKinds: $stagedKinds, '
        'skipKinds: $skipKinds)';
  }
}

class _ExpectedRetractionResult {
  const _ExpectedRetractionResult({
    required this.fingerprint,
    required this.outcome,
    this.toolName,
    this.humanSummary,
  });

  final String fingerprint;
  final RetractionOutcome outcome;
  final String? toolName;
  final String? humanSummary;
}

class _ExpectedRetractionDecision {
  const _ExpectedRetractionDecision({
    required this.changeSetId,
    required this.itemIndex,
    required this.item,
    required this.reason,
  });

  final String changeSetId;
  final int itemIndex;
  final ChangeItem item;
  final String reason;
}

class _ExpectedRetractionModel {
  const _ExpectedRetractionModel({
    required this.results,
    required this.upsertKinds,
    required this.decisions,
    required this.updatedSets,
  });

  final List<_ExpectedRetractionResult> results;
  final List<_ExpectedRetractionUpsertKind> upsertKinds;
  final List<_ExpectedRetractionDecision> decisions;
  final List<ChangeSetEntity> updatedSets;
}

class _GeneratedRetractionMatch {
  const _GeneratedRetractionMatch({
    required this.changeSet,
    required this.itemIndex,
    required this.item,
  });

  final ChangeSetEntity changeSet;
  final int itemIndex;
  final ChangeItem item;
}

extension _GeneratedRetractionItemKindX on _GeneratedRetractionItemKind {
  ChangeItem item({ChangeItemStatus status = ChangeItemStatus.pending}) {
    return switch (this) {
      _GeneratedRetractionItemKind.priority => ChangeItem(
        toolName: 'update_task_priority',
        args: const {'priority': 'P1'},
        humanSummary: 'Set priority to P1',
        status: status,
      ),
      _GeneratedRetractionItemKind.title => ChangeItem(
        toolName: 'set_task_title',
        args: const {'title': 'Generated title'},
        humanSummary: 'Rename task to generated title',
        status: status,
      ),
      _GeneratedRetractionItemKind.estimate => ChangeItem(
        toolName: 'update_task_estimate',
        args: const {'minutes': 30},
        humanSummary: 'Set estimate to 30 minutes',
        status: status,
      ),
    };
  }
}

extension _GeneratedRetractionRequestSlotX on _GeneratedRetractionRequestSlot {
  ChangeItem get item {
    return switch (this) {
      _GeneratedRetractionRequestSlot.priority =>
        _GeneratedRetractionItemKind.priority.item(),
      _GeneratedRetractionRequestSlot.title =>
        _GeneratedRetractionItemKind.title.item(),
      _GeneratedRetractionRequestSlot.estimate =>
        _GeneratedRetractionItemKind.estimate.item(),
      _GeneratedRetractionRequestSlot.missing => const ChangeItem(
        toolName: 'generated_missing_tool',
        args: {'missing': true},
        humanSummary: 'Missing generated item',
      ),
    };
  }

  String get fingerprint => ChangeItem.fingerprint(item);
}

extension _AnyGeneratedSuggestionRetractionScenario on glados.Any {
  glados.Generator<_GeneratedRetractionItemKind> get retractionItemKind =>
      glados.AnyUtils(this).choose(_GeneratedRetractionItemKind.values);

  glados.Generator<ChangeItemStatus> get retractionItemStatus =>
      glados.AnyUtils(this).choose(ChangeItemStatus.values);

  glados.Generator<_GeneratedRetractionRequestSlot> get retractionRequestSlot =>
      glados.AnyUtils(this).choose(_GeneratedRetractionRequestSlot.values);

  glados.Generator<_GeneratedRetractionRereadSlot> get retractionRereadSlot =>
      glados.AnyUtils(this).choose(_GeneratedRetractionRereadSlot.values);

  glados.Generator<_GeneratedRetractionItemSpec> get retractionItemSpec =>
      glados.CombinableAny(this).combine2(
        retractionItemKind,
        retractionItemStatus,
        (
          _GeneratedRetractionItemKind kind,
          ChangeItemStatus status,
        ) => _GeneratedRetractionItemSpec(kind: kind, status: status),
      );

  glados.Generator<_GeneratedRetractionSetSpec> get retractionSetSpec =>
      glados.CombinableAny(this).combine2(
        glados.ListAnys(
          this,
        ).listWithLengthInRange(0, 4, retractionItemSpec),
        retractionRereadSlot,
        (
          List<_GeneratedRetractionItemSpec> items,
          _GeneratedRetractionRereadSlot rereadSlot,
        ) => _GeneratedRetractionSetSpec(
          items: items,
          rereadSlot: rereadSlot,
        ),
      );

  glados.Generator<_GeneratedRetractionScenario> get retractionScenario =>
      glados.CombinableAny(this).combine2(
        glados.ListAnys(
          this,
        ).listWithLengthInRange(0, 4, retractionSetSpec),
        glados.ListAnys(
          this,
        ).listWithLengthInRange(0, 6, retractionRequestSlot),
        (
          List<_GeneratedRetractionSetSpec> sets,
          List<_GeneratedRetractionRequestSlot> requests,
        ) => _GeneratedRetractionScenario(sets: sets, requests: requests),
      );

  glados.Generator<_GeneratedSkipScenario> get retractionSkipScenario =>
      glados.CombinableAny(this).combine2(
        glados.ListAnys(
          this,
        ).listWithLengthInRange(0, 5, retractionItemKind),
        glados.ListAnys(
          this,
        ).listWithLengthInRange(0, 3, retractionItemKind),
        (
          List<_GeneratedRetractionItemKind> stagedKinds,
          List<_GeneratedRetractionItemKind> skipKinds,
        ) => _GeneratedSkipScenario(
          stagedKinds: stagedKinds,
          skipKinds: skipKinds,
        ),
      );
}

/// Runs the two-phase retraction (validate, then persist) the way the workflow
/// does at end-of-wake, returning the LLM-facing results.
///
/// Most tests assert on this combined behavior — it is exactly what the old
/// single-step `retract` did. Dedicated tests below exercise
/// [SuggestionRetractionService.plan] and
/// [SuggestionRetractionService.applyStaged] in isolation to lock in the
/// read-only / persist split.
Future<List<RetractionResult>> _planThenApply(
  SuggestionRetractionService service, {
  required String agentId,
  required String taskId,
  required List<RetractionRequest> requests,
}) async {
  final plan = await service.plan(
    agentId: agentId,
    taskId: taskId,
    requests: requests,
  );
  await service.applyStaged(plan.staged);
  return plan.results;
}

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentSyncService mockSyncService;
  late MockAgentRepository mockRepository;
  late MockDomainLogger mockDomainLogger;
  late SuggestionRetractionService service;

  final testClock = Clock.fixed(DateTime(2026, 4, 18, 9, 30));

  setUp(() {
    mockSyncService = MockAgentSyncService();
    mockRepository = MockAgentRepository();
    mockDomainLogger = MockDomainLogger();

    when(() => mockSyncService.repository).thenReturn(mockRepository);
    // Default: subsequent reads mirror what upsert wrote, but concrete
    // tests stub explicitly when they care about re-read behavior.
    when(() => mockRepository.getEntity(any())).thenAnswer((_) async => null);
    when(
      () => mockRepository.getProposalLedger(
        any(),
        taskId: any(named: 'taskId'),
        changeSetFetchLimit: any(named: 'changeSetFetchLimit'),
        resolvedLimit: any(named: 'resolvedLimit'),
      ),
    ).thenAnswer((_) async => const ProposalLedger.empty());
    when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
    when(
      () => mockDomainLogger.log(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);

    service = SuggestionRetractionService(
      syncService: mockSyncService,
      domainLogger: mockDomainLogger,
    );
  });

  const priorityItem = ChangeItem(
    toolName: 'update_task_priority',
    args: {'priority': 'P1'},
    humanSummary: 'Set priority to P1',
  );
  const titleItem = ChangeItem(
    toolName: 'set_task_title',
    args: {'title': 'New title'},
    humanSummary: 'Rename task to "New title"',
  );

  ChangeSetEntity setWith(List<ChangeItem> items, {String id = 'cs-1'}) {
    return makeTestChangeSet(
      id: id,
      taskId: 'task-xyz',
      items: items,
    );
  }

  void stubPendingSets(List<ChangeSetEntity> sets) {
    when(
      () => mockRepository.getPendingChangeSets(
        any(),
        taskId: any(named: 'taskId'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => sets);
  }

  group('SuggestionRetractionService.plan + applyStaged', () {
    glados.Glados(
      glados.any.retractionScenario,
      glados.ExploreConfig(numRuns: 220),
    ).test('matches generated request, sibling, and reread semantics', (
      scenario,
    ) async {
      const agentId = 'generated-agent';
      const taskId = 'generated-task';
      final raceResolvedAt = DateTime(2026, 4, 17, 8);
      final now = testClock.now();
      final localSyncService = MockAgentSyncService();
      final localRepository = MockAgentRepository();
      final localDomainLogger = MockDomainLogger();
      final localService = SuggestionRetractionService(
        syncService: localSyncService,
        domainLogger: localDomainLogger,
      );

      ChangeSetEntity withDerivedStatus(ChangeSetEntity set) {
        final status = ChangeItem.deriveSetStatus(set.items);
        return set.copyWith(
          status: status,
          resolvedAt: ChangeItem.deriveResolvedAt(
            newStatus: status,
            existingResolvedAt: set.resolvedAt,
            now: raceResolvedAt,
          ),
        );
      }

      ChangeSetEntity buildSet(int index, _GeneratedRetractionSetSpec spec) {
        final items = spec.items
            .map((item) => item.kind.item(status: item.status))
            .toList();
        return withDerivedStatus(
          makeTestChangeSet(
            id: 'generated-cs-$index',
            agentId: agentId,
            taskId: taskId,
            threadId: 'generated-thread-$index',
            runKey: 'generated-run-$index',
            items: items,
          ),
        );
      }

      final initialSets = [
        for (var i = 0; i < scenario.sets.length; i++)
          buildSet(i, scenario.sets[i]),
      ];
      final specBySetId = {
        for (var i = 0; i < initialSets.length; i++)
          initialSets[i].id: scenario.sets[i],
      };

      ChangeSetEntity? rereadEntity(
        ChangeSetEntity initial,
        Map<String, ChangeSetEntity> latestById,
      ) {
        final latest = latestById[initial.id] ?? initial;
        return switch (specBySetId[initial.id]!.rereadSlot) {
          _GeneratedRetractionRereadSlot.latest => latest,
          _GeneratedRetractionRereadSlot.missing => null,
          _GeneratedRetractionRereadSlot.allConfirmed => withDerivedStatus(
            latest.copyWith(
              items: [
                for (final item in latest.items)
                  item.copyWith(status: ChangeItemStatus.confirmed),
              ],
            ),
          ),
          _GeneratedRetractionRereadSlot.truncatedLast => withDerivedStatus(
            latest.copyWith(
              items: latest.items.isEmpty
                  ? const <ChangeItem>[]
                  : latest.items.take(latest.items.length - 1).toList(),
            ),
          ),
        };
      }

      List<_GeneratedRetractionMatch> locateAll(String fingerprint) {
        final matches = <_GeneratedRetractionMatch>[];
        for (final set in initialSets) {
          for (var i = 0; i < set.items.length; i++) {
            final item = set.items[i];
            if (ChangeItem.fingerprint(item) != fingerprint) continue;
            matches.add(
              _GeneratedRetractionMatch(
                changeSet: set,
                itemIndex: i,
                item: item,
              ),
            );
          }
        }
        return matches;
      }

      String reasonFor(int index, _GeneratedRetractionRequestSlot slot) =>
          'generated reason $index ${slot.name}';

      _ExpectedRetractionModel buildExpectedModel() {
        final results = <_ExpectedRetractionResult>[];
        final decisions = <_ExpectedRetractionDecision>[];
        final retractedThisCall = <String>{};

        // Phase 0 — replicate plan(): staging order is request-outer,
        // match-inner; one staged decision per pending match.
        for (var i = 0; i < scenario.requests.length; i++) {
          final request = scenario.requests[i];
          final fingerprint = request.fingerprint;
          final matches = locateAll(fingerprint);
          if (matches.isEmpty) {
            results.add(
              _ExpectedRetractionResult(
                fingerprint: fingerprint,
                outcome: RetractionOutcome.notFound,
              ),
            );
            continue;
          }

          if (retractedThisCall.contains(fingerprint)) {
            final first = matches.first;
            results.add(
              _ExpectedRetractionResult(
                fingerprint: fingerprint,
                outcome: RetractionOutcome.notOpen,
                toolName: first.item.toolName,
                humanSummary: first.item.humanSummary,
              ),
            );
            continue;
          }

          final pendingMatches = matches
              .where((m) => m.item.status == ChangeItemStatus.pending)
              .toList();
          if (pendingMatches.isEmpty) {
            final first = matches.first;
            results.add(
              _ExpectedRetractionResult(
                fingerprint: fingerprint,
                outcome: RetractionOutcome.notOpen,
                toolName: first.item.toolName,
                humanSummary: first.item.humanSummary,
              ),
            );
            continue;
          }

          final reason = reasonFor(i, request);
          for (final match in pendingMatches) {
            decisions.add(
              _ExpectedRetractionDecision(
                changeSetId: match.changeSet.id,
                itemIndex: match.itemIndex,
                item: match.item,
                reason: reason,
              ),
            );
          }
          retractedThisCall.add(fingerprint);
          final first = pendingMatches.first;
          results.add(
            _ExpectedRetractionResult(
              fingerprint: fingerprint,
              outcome: RetractionOutcome.retracted,
              toolName: first.item.toolName,
              humanSummary: first.item.humanSummary,
            ),
          );
        }

        // Phase 1 — applyStaged persists every decision first, in staged order.
        final upsertKinds = <_ExpectedRetractionUpsertKind>[
          ...List.filled(
            decisions.length,
            _ExpectedRetractionUpsertKind.decision,
          ),
        ];

        // Phase 2 — applyStaged then re-reads each change set ONCE (in
        // first-seen order) and applies all of its still-valid flips in a
        // single write. Each set is read before any write touches it, so the
        // re-read always resolves against the static initial snapshot.
        final staticInitialById = {for (final set in initialSets) set.id: set};
        final updatedSets = <ChangeSetEntity>[];
        final groupOrder = <String>[];
        final groups = <String, List<_ExpectedRetractionDecision>>{};
        for (final decision in decisions) {
          groups
              .putIfAbsent(decision.changeSetId, () {
                groupOrder.add(decision.changeSetId);
                return <_ExpectedRetractionDecision>[];
              })
              .add(decision);
        }

        for (final setId in groupOrder) {
          final initial = initialSets.firstWhere((set) => set.id == setId);
          final reread = rereadEntity(initial, staticInitialById);
          final current = reread ?? initial;
          var items = current.items;
          var changed = false;
          for (final decision in groups[setId]!) {
            final index = decision.itemIndex;
            if (index < 0 || index >= items.length) continue;
            final existing = items[index];
            if (existing.status != ChangeItemStatus.pending) continue;
            if (ChangeItem.fingerprint(existing) !=
                ChangeItem.fingerprint(decision.item)) {
              continue;
            }
            if (!changed) {
              items = List<ChangeItem>.from(items);
              changed = true;
            }
            items[index] = existing.copyWith(
              status: ChangeItemStatus.retracted,
            );
          }
          if (!changed) continue;

          final newStatus = ChangeItem.deriveSetStatus(items);
          updatedSets.add(
            current.copyWith(
              items: items,
              status: newStatus,
              resolvedAt: ChangeItem.deriveResolvedAt(
                newStatus: newStatus,
                existingResolvedAt: current.resolvedAt,
                now: now,
              ),
            ),
          );
          upsertKinds.add(_ExpectedRetractionUpsertKind.changeSet);
        }

        return _ExpectedRetractionModel(
          results: results,
          upsertKinds: upsertKinds,
          decisions: decisions,
          updatedSets: updatedSets,
        );
      }

      final expected = buildExpectedModel();
      final actualLatestById = {for (final set in initialSets) set.id: set};
      final upserts = <AgentDomainEntity>[];

      when(() => localSyncService.repository).thenReturn(localRepository);
      when(
        () => localRepository.getPendingChangeSets(
          agentId,
          taskId: taskId,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => initialSets);
      when(
        () => localRepository.getProposalLedger(
          agentId,
          taskId: taskId,
          changeSetFetchLimit: any(named: 'changeSetFetchLimit'),
          resolvedLimit: any(named: 'resolvedLimit'),
        ),
      ).thenAnswer((_) async => const ProposalLedger.empty());
      when(() => localRepository.getEntity(any())).thenAnswer((invocation) {
        final id = invocation.positionalArguments.single as String;
        final initial = initialSets.where((set) => set.id == id).firstOrNull;
        if (initial == null) return Future<AgentDomainEntity?>.value();
        return Future<AgentDomainEntity?>.value(
          rereadEntity(initial, actualLatestById),
        );
      });
      when(() => localSyncService.upsertEntity(any())).thenAnswer((
        invocation,
      ) async {
        final entity =
            invocation.positionalArguments.single as AgentDomainEntity;
        upserts.add(entity);
        if (entity is ChangeSetEntity) {
          actualLatestById[entity.id] = entity;
        }
      });
      when(
        () => localDomainLogger.log(
          any(),
          any(),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenReturn(null);

      final requests = [
        for (var i = 0; i < scenario.requests.length; i++)
          RetractionRequest(
            fingerprint: scenario.requests[i].fingerprint,
            reason: reasonFor(i, scenario.requests[i]),
          ),
      ];

      final plan = await withClock(
        testClock,
        () => localService.plan(
          agentId: agentId,
          taskId: taskId,
          requests: requests,
        ),
      );

      // plan() is read-only — validation must not persist anything.
      expect(upserts, isEmpty, reason: 'plan() must not upsert: $scenario');

      // One staged retraction per pending match, in request/match order —
      // the exact set the apply step will later persist as decisions.
      expect(
        plan.staged,
        hasLength(expected.decisions.length),
        reason: '$scenario',
      );
      for (var i = 0; i < expected.decisions.length; i++) {
        expect(
          plan.staged[i].changeSet.id,
          expected.decisions[i].changeSetId,
          reason: '$scenario',
        );
        expect(
          plan.staged[i].itemIndex,
          expected.decisions[i].itemIndex,
          reason: '$scenario',
        );
        expect(
          plan.staged[i].reason,
          expected.decisions[i].reason,
          reason: '$scenario',
        );
        expect(
          plan.staged[i].item.toolName,
          expected.decisions[i].item.toolName,
          reason: '$scenario',
        );
      }

      final results = plan.results;

      // Apply the staged retractions — this is where persistence happens.
      await withClock(testClock, () => localService.applyStaged(plan.staged));

      expect(results, hasLength(expected.results.length), reason: '$scenario');
      for (var i = 0; i < expected.results.length; i++) {
        final actual = results[i];
        final expectedResult = expected.results[i];
        expect(actual.fingerprint, expectedResult.fingerprint);
        expect(actual.outcome, expectedResult.outcome, reason: '$scenario');
        expect(actual.toolName, expectedResult.toolName, reason: '$scenario');
        expect(
          actual.humanSummary,
          expectedResult.humanSummary,
          reason: '$scenario',
        );
      }

      _ExpectedRetractionUpsertKind upsertKind(AgentDomainEntity entity) {
        if (entity is ChangeDecisionEntity) {
          return _ExpectedRetractionUpsertKind.decision;
        }
        if (entity is ChangeSetEntity) {
          return _ExpectedRetractionUpsertKind.changeSet;
        }
        throw StateError('Unexpected generated upsert: $entity');
      }

      expect(
        upserts.map(upsertKind).toList(),
        expected.upsertKinds,
        reason: '$scenario',
      );

      final decisions = upserts.whereType<ChangeDecisionEntity>().toList();
      expect(decisions, hasLength(expected.decisions.length));
      for (var i = 0; i < expected.decisions.length; i++) {
        final actual = decisions[i];
        final expectedDecision = expected.decisions[i];
        expect(actual.changeSetId, expectedDecision.changeSetId);
        expect(actual.itemIndex, expectedDecision.itemIndex);
        expect(actual.toolName, expectedDecision.item.toolName);
        expect(actual.args, expectedDecision.item.args);
        expect(actual.humanSummary, expectedDecision.item.humanSummary);
        expect(actual.retractionReason, expectedDecision.reason);
        expect(actual.verdict, ChangeDecisionVerdict.retracted);
        expect(actual.actor, DecisionActor.agent);
        expect(actual.taskId, taskId);
        expect(actual.createdAt, now);
      }

      final updatedSets = upserts.whereType<ChangeSetEntity>().toList();
      expect(updatedSets, hasLength(expected.updatedSets.length));
      for (var i = 0; i < expected.updatedSets.length; i++) {
        final actual = updatedSets[i];
        final expectedSet = expected.updatedSets[i];
        expect(actual.id, expectedSet.id);
        expect(actual.items, expectedSet.items, reason: '$scenario');
        expect(actual.status, expectedSet.status, reason: '$scenario');
        expect(actual.resolvedAt, expectedSet.resolvedAt, reason: '$scenario');
      }
    }, tags: 'glados');

    test(
      'retracts a matching open item and persists decision + set update',
      () async {
        final cs = setWith([priorityItem, titleItem]);
        stubPendingSets([cs]);

        final fp = ChangeItem.fingerprint(priorityItem);
        final results = await withClock(
          testClock,
          () => _planThenApply(
            service,
            agentId: 'agent-1',
            taskId: 'task-xyz',
            requests: [
              RetractionRequest(
                fingerprint: fp,
                reason: 'Already P1 on the task',
              ),
            ],
          ),
        );

        expect(results, hasLength(1));
        expect(results.single.outcome, RetractionOutcome.retracted);
        expect(results.single.toolName, 'update_task_priority');
        expect(results.single.humanSummary, 'Set priority to P1');

        // Two upserts: the decision entity and the updated change set.
        final upserts = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        expect(upserts, hasLength(2));

        final decision = upserts.whereType<ChangeDecisionEntity>().single;
        expect(decision.verdict, ChangeDecisionVerdict.retracted);
        expect(decision.actor, DecisionActor.agent);
        expect(decision.retractionReason, 'Already P1 on the task');
        expect(decision.rejectionReason, isNull);
        expect(decision.toolName, 'update_task_priority');
        expect(decision.changeSetId, 'cs-1');
        expect(decision.itemIndex, 0);
        expect(decision.args, const {'priority': 'P1'});
        expect(decision.humanSummary, 'Set priority to P1');
        expect(decision.createdAt, DateTime(2026, 4, 18, 9, 30));

        final updatedSet = upserts.whereType<ChangeSetEntity>().single;
        expect(updatedSet.id, 'cs-1');
        expect(updatedSet.items[0].status, ChangeItemStatus.retracted);
        expect(
          updatedSet.items[1].status,
          ChangeItemStatus.pending,
          reason: 'sibling items untouched',
        );
        // Some items still pending → change set transitions to
        // partiallyResolved.
        expect(updatedSet.status, ChangeSetStatus.partiallyResolved);
      },
    );

    test(
      'transitions change-set status to resolved when the retracted item '
      'was the last pending one',
      () async {
        final cs = setWith([priorityItem]);
        stubPendingSets([cs]);

        final results = await withClock(
          testClock,
          () => _planThenApply(
            service,
            agentId: 'agent-1',
            taskId: 'task-xyz',
            requests: [
              RetractionRequest(
                fingerprint: ChangeItem.fingerprint(priorityItem),
                reason: 'Duplicate',
              ),
            ],
          ),
        );

        expect(results.single.outcome, RetractionOutcome.retracted);
        final updated = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured.whereType<ChangeSetEntity>().single;
        expect(updated.status, ChangeSetStatus.resolved);
        expect(updated.resolvedAt, DateTime(2026, 4, 18, 9, 30));
      },
    );

    test(
      'notifies post-retraction callback with the updated change set',
      () async {
        final cs = setWith([priorityItem]);
        final notified = <ChangeSetEntity>[];
        final serviceWithCallback = SuggestionRetractionService(
          syncService: mockSyncService,
          domainLogger: mockDomainLogger,
          onChangeSetRetracted: (changeSet) async {
            notified.add(changeSet);
          },
        );
        stubPendingSets([cs]);

        await withClock(
          testClock,
          () => _planThenApply(
            serviceWithCallback,
            agentId: 'agent-1',
            taskId: 'task-xyz',
            requests: [
              RetractionRequest(
                fingerprint: ChangeItem.fingerprint(priorityItem),
                reason: 'Already done',
              ),
            ],
          ),
        );

        expect(notified, hasLength(1));
        expect(notified.single.items.single.status, ChangeItemStatus.retracted);
        expect(notified.single.status, ChangeSetStatus.resolved);
      },
    );

    test(
      'keeps successful retraction when post-retraction callback fails',
      () async {
        final cs = setWith([priorityItem]);
        final serviceWithCallback = SuggestionRetractionService(
          syncService: mockSyncService,
          domainLogger: mockDomainLogger,
          onChangeSetRetracted: (_) async {
            throw StateError('notification-sync-boom');
          },
        );
        stubPendingSets([cs]);

        final results = await withClock(
          testClock,
          () => _planThenApply(
            serviceWithCallback,
            agentId: 'agent-1',
            taskId: 'task-xyz',
            requests: [
              RetractionRequest(
                fingerprint: ChangeItem.fingerprint(priorityItem),
                reason: 'Already done',
              ),
            ],
          ),
        );

        expect(results.single.outcome, RetractionOutcome.retracted);
        verify(
          () => mockDomainLogger.error(
            LogDomain.agentWorkflow,
            any(),
            message: any(
              named: 'message',
              that: contains('Post-retraction notification sync failed'),
            ),
            subDomain: any(named: 'subDomain'),
            stackTrace: any(named: 'stackTrace'),
          ),
        ).called(1);
      },
    );

    test('returns notOpen for an item whose status is not pending', () async {
      final cs = setWith([
        priorityItem.copyWith(status: ChangeItemStatus.confirmed),
      ]);
      stubPendingSets([cs]);

      final results = await _planThenApply(
        service,
        agentId: 'agent-1',
        taskId: 'task-xyz',
        requests: [
          RetractionRequest(
            fingerprint: ChangeItem.fingerprint(priorityItem),
            reason: 'stale',
          ),
        ],
      );

      expect(results.single.outcome, RetractionOutcome.notOpen);
      expect(results.single.toolName, 'update_task_priority');
      // No upsert should have happened.
      verifyNever(() => mockSyncService.upsertEntity(any()));
    });

    test(
      'returns notFound when no open set contains the fingerprint',
      () async {
        stubPendingSets([
          setWith([titleItem]),
        ]);

        final results = await _planThenApply(
          service,
          agentId: 'agent-1',
          taskId: 'task-xyz',
          requests: [
            RetractionRequest(
              fingerprint: ChangeItem.fingerprint(priorityItem),
              reason: 'no-op',
            ),
          ],
        );

        expect(results.single.outcome, RetractionOutcome.notFound);
        expect(results.single.toolName, isNull);
        verifyNever(() => mockSyncService.upsertEntity(any()));
      },
    );

    test(
      'reports notOpen when the fingerprint only exists in resolved ledger',
      () async {
        stubPendingSets([
          setWith([titleItem]),
        ]);
        final fingerprint = ChangeItem.fingerprint(priorityItem);
        when(
          () => mockRepository.getProposalLedger(
            'agent-1',
            taskId: 'task-xyz',
            changeSetFetchLimit: any(named: 'changeSetFetchLimit'),
            resolvedLimit: any(named: 'resolvedLimit'),
          ),
        ).thenAnswer(
          (_) async => ProposalLedger(
            open: const [],
            resolved: [
              LedgerEntry(
                changeSetId: 'cs-resolved',
                itemIndex: 0,
                toolName: priorityItem.toolName,
                args: priorityItem.args,
                humanSummary: priorityItem.humanSummary,
                fingerprint: fingerprint,
                status: ChangeItemStatus.retracted,
                createdAt: DateTime(2026, 4, 18, 8),
                resolvedAt: DateTime(2026, 4, 18, 9),
                resolvedBy: DecisionActor.agent,
                verdict: ChangeDecisionVerdict.retracted,
              ),
            ],
          ),
        );

        final results = await _planThenApply(
          service,
          agentId: 'agent-1',
          taskId: 'task-xyz',
          requests: [
            RetractionRequest(
              fingerprint: fingerprint,
              reason: 'already gone',
            ),
          ],
        );

        expect(results.single.outcome, RetractionOutcome.notOpen);
        expect(results.single.toolName, priorityItem.toolName);
        expect(results.single.humanSummary, priorityItem.humanSummary);
        verifyNever(() => mockSyncService.upsertEntity(any()));
      },
    );

    test(
      'when resolved ledger contains duplicate fingerprints, the newest '
      'entry wins (resolved is sorted newest-first)',
      () async {
        stubPendingSets([
          setWith([titleItem]),
        ]);
        final fingerprint = ChangeItem.fingerprint(priorityItem);
        when(
          () => mockRepository.getProposalLedger(
            'agent-1',
            taskId: 'task-xyz',
            changeSetFetchLimit: any(named: 'changeSetFetchLimit'),
            resolvedLimit: any(named: 'resolvedLimit'),
          ),
        ).thenAnswer(
          (_) async => ProposalLedger(
            open: const [],
            // Newest-first ordering: the first entry is the canonical one
            // the LLM should see in the retraction result.
            resolved: [
              LedgerEntry(
                changeSetId: 'cs-newest',
                itemIndex: 0,
                toolName: priorityItem.toolName,
                args: priorityItem.args,
                humanSummary: 'newest summary',
                fingerprint: fingerprint,
                status: ChangeItemStatus.retracted,
                createdAt: DateTime(2026, 4, 18, 8),
                resolvedAt: DateTime(2026, 4, 18, 10),
                resolvedBy: DecisionActor.agent,
                verdict: ChangeDecisionVerdict.retracted,
              ),
              LedgerEntry(
                changeSetId: 'cs-older',
                itemIndex: 0,
                toolName: priorityItem.toolName,
                args: priorityItem.args,
                humanSummary: 'older summary',
                fingerprint: fingerprint,
                status: ChangeItemStatus.retracted,
                createdAt: DateTime(2026, 4, 17, 8),
                resolvedAt: DateTime(2026, 4, 17, 9),
                resolvedBy: DecisionActor.agent,
                verdict: ChangeDecisionVerdict.retracted,
              ),
            ],
          ),
        );

        final results = await _planThenApply(
          service,
          agentId: 'agent-1',
          taskId: 'task-xyz',
          requests: [
            RetractionRequest(
              fingerprint: fingerprint,
              reason: 'check newest wins',
            ),
          ],
        );

        expect(results.single.outcome, RetractionOutcome.notOpen);
        expect(results.single.humanSummary, 'newest summary');
      },
    );

    test(
      'a fingerprint passed twice in the same call is idempotent — second '
      'occurrence reports notOpen',
      () async {
        final cs = setWith([priorityItem]);
        stubPendingSets([cs]);

        final fp = ChangeItem.fingerprint(priorityItem);
        final results = await withClock(
          testClock,
          () => _planThenApply(
            service,
            agentId: 'agent-1',
            taskId: 'task-xyz',
            requests: [
              RetractionRequest(fingerprint: fp, reason: 'first call'),
              RetractionRequest(fingerprint: fp, reason: 'second call'),
            ],
          ),
        );

        expect(results, hasLength(2));
        expect(results[0].outcome, RetractionOutcome.retracted);
        expect(results[1].outcome, RetractionOutcome.notOpen);

        final decisions = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured.whereType<ChangeDecisionEntity>().toList();
        expect(
          decisions,
          hasLength(1),
          reason: 'only the first call should produce a decision',
        );
      },
    );

    test(
      'returns empty list and makes no calls when given no requests',
      () async {
        final results = await _planThenApply(
          service,
          agentId: 'agent-1',
          taskId: 'task-xyz',
          requests: const [],
        );

        expect(results, isEmpty);
        verifyNever(
          () => mockRepository.getPendingChangeSets(
            any(),
            taskId: any(named: 'taskId'),
            limit: any(named: 'limit'),
          ),
        );
        verifyNever(() => mockSyncService.upsertEntity(any()));
      },
    );

    test(
      'sibling sweep: retracts every pending duplicate across separate '
      'change sets when they share a fingerprint',
      () async {
        // Consecutive wakes can write the same `(toolName, args)` into
        // separate change sets before cross-set dedup catches them. A
        // single agent retraction intent must clear every open copy so
        // the user doesn't keep seeing ghosts in the UI.
        final csA = setWith([priorityItem], id: 'cs-a');
        final csB = setWith([priorityItem], id: 'cs-b');
        final csC = setWith([priorityItem], id: 'cs-c');
        stubPendingSets([csA, csB, csC]);

        final results = await withClock(
          testClock,
          () => _planThenApply(
            service,
            agentId: 'agent-1',
            taskId: 'task-xyz',
            requests: [
              RetractionRequest(
                fingerprint: ChangeItem.fingerprint(priorityItem),
                reason: 'Already P1 on the task',
              ),
            ],
          ),
        );

        expect(results, hasLength(1));
        expect(results.single.outcome, RetractionOutcome.retracted);

        final upserts = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;

        // One decision + one updated set per sibling — 3 decisions and
        // 3 set updates for three duplicates.
        final decisions = upserts.whereType<ChangeDecisionEntity>().toList();
        final updatedSets = upserts.whereType<ChangeSetEntity>().toList();
        expect(decisions, hasLength(3));
        expect(updatedSets, hasLength(3));
        expect(
          updatedSets.map((s) => s.id).toSet(),
          {'cs-a', 'cs-b', 'cs-c'},
          reason: 'every sibling set must be updated, not just the first',
        );
        for (final s in updatedSets) {
          expect(s.items.single.status, ChangeItemStatus.retracted);
          expect(s.status, ChangeSetStatus.resolved);
        }
        for (final d in decisions) {
          expect(d.verdict, ChangeDecisionVerdict.retracted);
          expect(d.retractionReason, 'Already P1 on the task');
        }
      },
    );

    test(
      'sibling sweep skips already-resolved matches and retracts only the '
      'remaining pending ones',
      () async {
        final pendingMatch = setWith([priorityItem], id: 'cs-open');
        final resolvedMatch = setWith(
          [priorityItem.copyWith(status: ChangeItemStatus.confirmed)],
          id: 'cs-resolved',
        );
        stubPendingSets([pendingMatch, resolvedMatch]);

        final results = await withClock(
          testClock,
          () => _planThenApply(
            service,
            agentId: 'agent-1',
            taskId: 'task-xyz',
            requests: [
              RetractionRequest(
                fingerprint: ChangeItem.fingerprint(priorityItem),
                reason: 'Duplicate',
              ),
            ],
          ),
        );

        expect(results.single.outcome, RetractionOutcome.retracted);
        final upserts = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final updatedSets = upserts.whereType<ChangeSetEntity>().toList();
        expect(
          updatedSets,
          hasLength(1),
          reason:
              'only the pending sibling gets a retraction; the already '
              'confirmed one is left alone',
        );
        expect(updatedSets.single.id, 'cs-open');
      },
    );

    test(
      'reports notOpen when every match is already resolved',
      () async {
        final a = setWith(
          [priorityItem.copyWith(status: ChangeItemStatus.confirmed)],
          id: 'cs-a',
        );
        final b = setWith(
          [priorityItem.copyWith(status: ChangeItemStatus.rejected)],
          id: 'cs-b',
        );
        stubPendingSets([a, b]);

        final results = await _planThenApply(
          service,
          agentId: 'agent-1',
          taskId: 'task-xyz',
          requests: [
            RetractionRequest(
              fingerprint: ChangeItem.fingerprint(priorityItem),
              reason: 'stale',
            ),
          ],
        );

        expect(results.single.outcome, RetractionOutcome.notOpen);
        expect(results.single.toolName, 'update_task_priority');
        verifyNever(() => mockSyncService.upsertEntity(any()));
      },
    );

    test(
      'logs a structured retraction message via the domain logger',
      () async {
        final cs = setWith([priorityItem]);
        stubPendingSets([cs]);

        await withClock(
          testClock,
          () => _planThenApply(
            service,
            agentId: 'agent-1',
            taskId: 'task-xyz',
            requests: [
              RetractionRequest(
                fingerprint: ChangeItem.fingerprint(priorityItem),
                reason: 'Duplicate',
              ),
            ],
          ),
        );

        verify(
          () => mockDomainLogger.log(
            any(),
            any(that: contains('Retracting item')),
            subDomain: 'SuggestionRetraction',
          ),
        ).called(1);
      },
    );

    test('plan() validates and stages without persisting anything', () async {
      final cs = setWith([priorityItem, titleItem]);
      stubPendingSets([cs]);

      final plan = await service.plan(
        agentId: 'agent-1',
        taskId: 'task-xyz',
        requests: [
          RetractionRequest(
            fingerprint: ChangeItem.fingerprint(priorityItem),
            reason: 'stale',
          ),
        ],
      );

      expect(plan.results.single.outcome, RetractionOutcome.retracted);
      expect(plan.results.single.toolName, 'update_task_priority');
      expect(plan.staged, hasLength(1));
      expect(plan.staged.single.changeSet.id, 'cs-1');
      expect(plan.staged.single.itemIndex, 0);
      expect(plan.staged.single.reason, 'stale');
      expect(plan.staged.single.key, 'cs-1:0');
      // The whole point of the split: nothing is written during planning.
      verifyNever(() => mockSyncService.upsertEntity(any()));
    });

    test(
      'applyStaged() persists the decision and flips only the staged item',
      () async {
        final cs = setWith([priorityItem, titleItem]);
        stubPendingSets([cs]);

        final plan = await service.plan(
          agentId: 'agent-1',
          taskId: 'task-xyz',
          requests: [
            RetractionRequest(
              fingerprint: ChangeItem.fingerprint(priorityItem),
              reason: 'stale',
            ),
          ],
        );
        await withClock(testClock, () => service.applyStaged(plan.staged));

        final upserts = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final decision = upserts.whereType<ChangeDecisionEntity>().single;
        expect(decision.verdict, ChangeDecisionVerdict.retracted);
        expect(decision.actor, DecisionActor.agent);
        expect(decision.retractionReason, 'stale');
        expect(decision.createdAt, DateTime(2026, 4, 18, 9, 30));

        final updated = upserts.whereType<ChangeSetEntity>().single;
        expect(updated.items[0].status, ChangeItemStatus.retracted);
        expect(
          updated.items[1].status,
          ChangeItemStatus.pending,
          reason: 'sibling proposals are untouched by an unrelated retraction',
        );
      },
    );

    test('applyStaged([]) is a no-op', () async {
      await service.applyStaged(const []);
      verifyNever(() => mockSyncService.upsertEntity(any()));
    });

    test(
      'alreadyStagedKeys keeps a repeat retraction idempotent across calls in '
      'one wake (nothing is persisted between calls)',
      () async {
        final cs = setWith([priorityItem]);
        stubPendingSets([cs]);
        final fp = ChangeItem.fingerprint(priorityItem);

        final first = await service.plan(
          agentId: 'agent-1',
          taskId: 'task-xyz',
          requests: [RetractionRequest(fingerprint: fp, reason: 'first')],
        );
        expect(first.staged, hasLength(1));

        // The item is staged but NOT yet persisted, so a second plan still
        // sees it as pending. Without the staged key it would be staged again
        // — leading to a duplicate retraction decision at apply time.
        final second = await service.plan(
          agentId: 'agent-1',
          taskId: 'task-xyz',
          requests: [RetractionRequest(fingerprint: fp, reason: 'second')],
          alreadyStagedKeys: {first.staged.single.key},
        );

        expect(second.results.single.outcome, RetractionOutcome.notOpen);
        expect(second.staged, isEmpty);
      },
    );

    test(
      'applyStaged dedupes overlapping staged retractions for the same item',
      () async {
        final cs = setWith([priorityItem]);
        stubPendingSets([cs]);
        final plan = await service.plan(
          agentId: 'agent-1',
          taskId: 'task-xyz',
          requests: [
            RetractionRequest(
              fingerprint: ChangeItem.fingerprint(priorityItem),
              reason: 'r',
            ),
          ],
        );

        // Apply the same staged item twice (defensive against overlapping
        // accumulated plans) — only one decision must be written.
        await withClock(
          testClock,
          () => service.applyStaged([...plan.staged, ...plan.staged]),
        );

        final decisions = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured.whereType<ChangeDecisionEntity>().toList();
        expect(decisions, hasLength(1));
      },
    );

    test(
      'applyStaged writes a change set once even with multiple retractions '
      'targeting it',
      () async {
        // Two distinct pending proposals in the SAME change set.
        final cs = setWith([priorityItem, titleItem]);
        stubPendingSets([cs]);

        final plan = await service.plan(
          agentId: 'agent-1',
          taskId: 'task-xyz',
          requests: [
            RetractionRequest(
              fingerprint: ChangeItem.fingerprint(priorityItem),
              reason: 'a',
            ),
            RetractionRequest(
              fingerprint: ChangeItem.fingerprint(titleItem),
              reason: 'b',
            ),
          ],
        );
        expect(plan.staged, hasLength(2));

        await withClock(testClock, () => service.applyStaged(plan.staged));

        final upserts = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        // One decision per item, but the parent set is read and written once.
        expect(upserts.whereType<ChangeDecisionEntity>(), hasLength(2));
        final sets = upserts.whereType<ChangeSetEntity>().toList();
        expect(
          sets,
          hasLength(1),
          reason: 'batched: a change set is written exactly once per apply',
        );
        expect(sets.single.items[0].status, ChangeItemStatus.retracted);
        expect(sets.single.items[1].status, ChangeItemStatus.retracted);
        expect(sets.single.status, ChangeSetStatus.resolved);
      },
    );

    test(
      'applyStaged skips an item whose row changed under it but still records '
      'the decision (fingerprint guard)',
      () async {
        final cs = setWith([priorityItem]);
        stubPendingSets([cs]);

        final plan = await service.plan(
          agentId: 'agent-1',
          taskId: 'task-xyz',
          requests: [
            RetractionRequest(
              fingerprint: ChangeItem.fingerprint(priorityItem),
              reason: 'r',
            ),
          ],
        );
        expect(plan.staged, hasLength(1));

        // Between plan and apply, the row at index 0 is replaced by a different
        // proposal (concurrent reorder/insert/args change). The re-read returns
        // it; index alone would otherwise retract the wrong proposal.
        when(
          () => mockRepository.getEntity('cs-1'),
        ).thenAnswer((_) async => cs.copyWith(items: const [titleItem]));

        await withClock(testClock, () => service.applyStaged(plan.staged));

        final upserts = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        // The decision is still persisted (audit trail), but the set is NOT
        // flipped — the guard refuses to retract a non-matching row.
        expect(upserts.whereType<ChangeDecisionEntity>(), hasLength(1));
        expect(
          upserts.whereType<ChangeSetEntity>(),
          isEmpty,
          reason:
              'wrong-item guard: no change-set write when fingerprint moved',
        );
      },
    );

    test(
      'applyStaged skips a retraction whose item is being re-proposed this '
      'wake (churn guard)',
      () async {
        final cs = setWith([priorityItem]);
        stubPendingSets([cs]);
        final plan = await service.plan(
          agentId: 'agent-1',
          taskId: 'task-xyz',
          requests: [
            RetractionRequest(
              fingerprint: ChangeItem.fingerprint(priorityItem),
              reason: 'r',
            ),
          ],
        );

        // The agent re-proposed this exact item this wake → skip it entirely.
        await withClock(
          testClock,
          () => service.applyStaged(
            plan.staged,
            skipFingerprints: {ChangeItem.fingerprint(priorityItem)},
          ),
        );

        // No decision, no flip — the original proposal is left untouched so it
        // does not vanish and reappear under the user.
        verifyNever(() => mockSyncService.upsertEntity(any()));
      },
    );

    test(
      'applyStaged applies only the retractions not in skipFingerprints',
      () async {
        final cs = setWith([priorityItem, titleItem]);
        stubPendingSets([cs]);
        final plan = await service.plan(
          agentId: 'agent-1',
          taskId: 'task-xyz',
          requests: [
            RetractionRequest(
              fingerprint: ChangeItem.fingerprint(priorityItem),
              reason: 'a',
            ),
            RetractionRequest(
              fingerprint: ChangeItem.fingerprint(titleItem),
              reason: 'b',
            ),
          ],
        );
        expect(plan.staged, hasLength(2));

        // Re-proposing only the priority item → its retraction is skipped, the
        // title retraction proceeds.
        await withClock(
          testClock,
          () => service.applyStaged(
            plan.staged,
            skipFingerprints: {ChangeItem.fingerprint(priorityItem)},
          ),
        );

        final upserts = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final decision = upserts.whereType<ChangeDecisionEntity>().single;
        expect(decision.toolName, 'set_task_title');
        final updated = upserts.whereType<ChangeSetEntity>().single;
        expect(
          updated.items[0].status,
          ChangeItemStatus.pending,
          reason: 're-proposed priority item is left open',
        );
        expect(updated.items[1].status, ChangeItemStatus.retracted);
      },
    );

    glados.Glados(
      glados.any.retractionSkipScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test('applyStaged persists exactly the non-skipped staged items', (
      scenario,
    ) async {
      final localSyncService = MockAgentSyncService();
      final localRepository = MockAgentRepository();
      final localDomainLogger = MockDomainLogger();
      final localService = SuggestionRetractionService(
        syncService: localSyncService,
        domainLogger: localDomainLogger,
      );

      when(() => localSyncService.repository).thenReturn(localRepository);
      // Re-read falls back to the staged snapshot (item still pending).
      when(
        () => localRepository.getEntity(any()),
      ).thenAnswer((_) async => null);
      final upserts = <AgentDomainEntity>[];
      when(() => localSyncService.upsertEntity(any())).thenAnswer((inv) async {
        upserts.add(inv.positionalArguments.single as AgentDomainEntity);
      });
      when(
        () => localDomainLogger.log(
          any(),
          any(),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenReturn(null);

      // Each staged item lives in its own single-item change set, so every
      // target has a unique key (no dedupe collapsing) and one write each.
      final staged = [
        for (var i = 0; i < scenario.stagedKinds.length; i++)
          StagedRetraction(
            changeSet: makeTestChangeSet(
              id: 'skip-cs-$i',
              items: [scenario.stagedKinds[i].item()],
            ),
            itemIndex: 0,
            item: scenario.stagedKinds[i].item(),
            reason: 'reason-$i',
          ),
      ];
      final skipFingerprints = {
        for (final kind in scenario.skipKinds)
          ChangeItem.fingerprint(kind.item()),
      };

      await withClock(
        testClock,
        () => localService.applyStaged(
          staged,
          skipFingerprints: skipFingerprints,
        ),
      );

      final expectedApplied = [
        for (final kind in scenario.stagedKinds)
          if (!skipFingerprints.contains(ChangeItem.fingerprint(kind.item())))
            kind,
      ];
      final decisions = upserts.whereType<ChangeDecisionEntity>().toList();
      final sets = upserts.whereType<ChangeSetEntity>().toList();

      // One decision + one set write per applied (non-skipped) staged item.
      expect(decisions, hasLength(expectedApplied.length), reason: '$scenario');
      expect(sets, hasLength(expectedApplied.length), reason: '$scenario');

      // No persisted retraction may carry a skipped fingerprint.
      for (final decision in decisions) {
        final fingerprint = ChangeItem.fingerprintFromParts(
          decision.toolName,
          decision.args ?? const {},
        );
        expect(
          skipFingerprints.contains(fingerprint),
          isFalse,
          reason: '$scenario',
        );
      }
      for (final set in sets) {
        expect(
          set.items.single.status,
          ChangeItemStatus.retracted,
          reason: '$scenario',
        );
      }
    }, tags: 'glados');
  });
}
