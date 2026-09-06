import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/model/proposal_ledger.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/relationship_proposal_service.dart';
import 'package:lotti/features/relationships/state/relationship_proposal_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';
import '../../agents/test_data/change_set_factories.dart';

void main() {
  setUpAll(registerAllFallbackValues);
  test(
    'reads the relationship scope and deduplicates pending proposals',
    () async {
      final repository = MockAgentRepository();
      final agentId = relationshipAgentIdFor('person');
      final set = makeTestChangeSet(
        agentId: agentId,
        taskId: 'person',
        items: const [
          ChangeItem(
            toolName: 'create_and_link_task',
            args: {'title': 'Pack fish'},
            humanSummary: 'Create task: Pack fish',
          ),
        ],
      );
      when(
        () => repository.getProposalLedger(agentId, taskId: 'person'),
      ).thenAnswer(
        (_) async => ProposalLedger(
          open: const [],
          resolved: const [],
          pendingSets: [
            set,
            set.copyWith(id: 'duplicate'),
          ],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(repository),
          agentUpdateStreamProvider(
            agentId,
          ).overrideWith((ref) => const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);
      final provider = relationshipSuggestionListProvider('person');
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final snapshot = await container.read(provider.future);
      expect(snapshot.suggestions.open, hasLength(1));
      expect(snapshot.suggestions.open.single.changeSet.taskId, 'person');
      expect(snapshot.suggestions.open.single.item.args['title'], 'Pack fish');
      verify(
        () => repository.getProposalLedger(agentId, taskId: 'person'),
      ).called(1);
    },
  );
  for (final durable in [true, false]) {
    test(
      'resolved history retains its run and destination (durable: $durable)',
      () async {
        final repository = MockAgentRepository();
        final agentId = relationshipAgentIdFor('person');
        final set = makeTestChangeSet(
          agentId: agentId,
          taskId: 'person',
          runKey: 'chat-run',
        );
        final item = set.items.first;
        final entry = LedgerEntry(
          runKey: 'chat-run',
          changeSetId: set.id,
          itemIndex: 0,
          toolName: item.toolName,
          args: item.args,
          humanSummary: item.humanSummary,
          fingerprint: ChangeItem.fingerprint(item),
          status: ChangeItemStatus.confirmed,
          createdAt: set.createdAt,
        );
        when(
          () => repository.getProposalLedger(agentId, taskId: 'person'),
        ).thenAnswer(
          (_) async => ProposalLedger(open: const [], resolved: [entry, entry]),
        );
        when(() => repository.getEntity(set.id)).thenAnswer((_) async => set);
        when(
          () => repository.getEntitiesByAgentId(
            agentId,
            type: AgentEntityTypes.changeDecision,
          ),
        ).thenAnswer(
          (_) async => [
            makeTestChangeDecision(
              agentId: agentId,
              changeSetId: set.id,
              args: durable
                  ? {RelationshipProposalService.receiptKey: testTask.toJson()}
                  : {},
            ),
          ],
        );
        final service = MockRelationshipProposalService();
        when(() => service.cachedReceipt(set.id, 0)).thenReturn(testTask);
        final container = ProviderContainer(
          overrides: [
            agentRepositoryProvider.overrideWithValue(repository),
            relationshipProposalServiceProvider.overrideWithValue(service),
            agentUpdateStreamProvider(
              agentId,
            ).overrideWith((ref) => const Stream.empty()),
          ],
        );
        addTearDown(container.dispose);
        final provider = relationshipSuggestionListProvider('person');
        final sub = container.listen(provider, (_, _) {});
        addTearDown(sub.close);
        final snapshot = await container.read(provider.future);
        expect(snapshot.suggestions.activity, [entry]);
        if (durable) {
          verifyNever(() => service.cachedReceipt(any(), any()));
        } else {
          verify(() => service.cachedReceipt(set.id, 0)).called(1);
        }
        expect(snapshot.runKeys, {set.id: 'chat-run'});
        expect(
          snapshot.receipts[RelationshipProposalSnapshot.itemKey(set.id, 0)],
          testTask,
        );
      },
    );
  }

  test(
    'provider wiring records a rejection in the relationship ledger',
    () async {
      final repository = MockAgentRepository();
      final sync = MockAgentSyncService();
      final persistence = MockPersistenceLogic();
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..registerSingleton<PersistenceLogic>(persistence)
            ..registerSingleton<EntitiesCacheService>(
              MockEntitiesCacheService(),
            );
        },
      );
      addTearDown(tearDownTestGetIt);
      final set = makeTestChangeSet(
        agentId: relationshipAgentIdFor('person'),
        taskId: 'person',
        items: const [
          ChangeItem(
            toolName: 'create_and_link_task',
            args: {'title': 'Pack fish'},
            humanSummary: 'Create task: Pack fish',
          ),
        ],
      );
      when(() => sync.repository).thenReturn(repository);
      when(() => repository.getEntity(set.id)).thenAnswer((_) async => set);
      when(() => sync.upsertEntity(any())).thenAnswer((_) async {});
      final container = ProviderContainer(
        overrides: [
          agentRepositoryProvider.overrideWithValue(repository),
          agentSyncServiceProvider.overrideWithValue(sync),
          taskAgentServiceProvider.overrideWithValue(MockTaskAgentService()),
          labelsRepositoryProvider.overrideWithValue(MockLabelsRepository()),
          relationshipRepositoryProvider.overrideWithValue(
            MockRelationshipRepository(),
          ),
          journalDbProvider.overrideWithValue(MockJournalDb()),
          domainLoggerProvider.overrideWithValue(MockDomainLogger()),
        ],
      );
      addTearDown(container.dispose);
      expect(
        await container
            .read(relationshipProposalServiceProvider)
            .reject(set, 0),
        isTrue,
      );
      final writes = verify(() => sync.upsertEntity(captureAny())).captured;
      final decision = writes.whereType<ChangeDecisionEntity>().single;
      expect(decision.agentId, set.agentId);
      expect(decision.taskId, 'person');
      expect(decision.verdict, ChangeDecisionVerdict.rejected);
      expect(
        writes.whereType<ChangeSetEntity>().last.items.single.status,
        ChangeItemStatus.rejected,
      );
      verifyNever(
        () => persistence.createTaskEntry(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: any(named: 'categoryId'),
          private: any(named: 'private'),
        ),
      );
    },
  );

  test(
    'disposing highlights cancels pending expiry and repeated highlights reset it',
    () {
      fakeAsync((async) {
        final container = ProviderContainer();
        final highlighter = container.read(
          relationshipTaskHighlightProvider.notifier,
        )..highlight('task');
        async.elapse(const Duration(seconds: 2));
        highlighter.highlight('task');
        async.elapse(const Duration(seconds: 2));
        expect(container.read(relationshipTaskHighlightProvider), {'task'});
        expect(async.nonPeriodicTimerCount, 1);
        container.dispose();
        expect(async.nonPeriodicTimerCount, 0);
      });
    },
  );
}
