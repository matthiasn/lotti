import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/service/suggestion_retraction_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

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

  group('SuggestionRetractionService.retract', () {
    test(
      'retracts a matching open item and persists decision + set update',
      () async {
        final cs = setWith([priorityItem, titleItem]);
        stubPendingSets([cs]);

        final fp = ChangeItem.fingerprint(priorityItem);
        final results = await withClock(
          testClock,
          () => service.retract(
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
          () => service.retract(
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

    test('returns notOpen for an item whose status is not pending', () async {
      final cs = setWith([
        priorityItem.copyWith(status: ChangeItemStatus.confirmed),
      ]);
      stubPendingSets([cs]);

      final results = await service.retract(
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

        final results = await service.retract(
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
      'a fingerprint passed twice in the same call is idempotent — second '
      'occurrence reports notOpen',
      () async {
        final cs = setWith([priorityItem]);
        stubPendingSets([cs]);

        final fp = ChangeItem.fingerprint(priorityItem);
        final results = await withClock(
          testClock,
          () => service.retract(
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
        final results = await service.retract(
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
          () => service.retract(
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
          () => service.retract(
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

        final results = await service.retract(
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
          () => service.retract(
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
  });
}
