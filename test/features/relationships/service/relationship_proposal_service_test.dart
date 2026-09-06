import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/relationships/service/relationship_proposal_service.dart';
import 'package:lotti/features/relationships/workflow/relationship_tool_dispatcher.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../agents/test_data/change_set_factories.dart';

void main() {
  setUpAll(registerAllFallbackValues);
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
  final confirmed = set.copyWith(
    items: [set.items.single.copyWith(status: ChangeItemStatus.confirmed)],
  );
  late MockChangeSetConfirmationService confirmation;
  late MockAgentRepository repository;
  late MockAgentSyncService sync;
  late MockJournalDb db;
  late MockRelationshipRepository relationships;
  late RelationshipProposalService service;
  late List<Task> removed;
  late bool removeSucceeds;
  setUp(() {
    confirmation = MockChangeSetConfirmationService();
    repository = MockAgentRepository();
    sync = MockAgentSyncService();
    db = MockJournalDb();
    when(
      () => db.entityById(testTask.id),
    ).thenAnswer((_) async => toDbEntity(testTask));
    when(
      () => db.linksForEntryIdsBidirectional(any()),
    ).thenAnswer((_) async => []);
    relationships = MockRelationshipRepository();
    removed = [];
    removeSucceeds = true;
    service = RelationshipProposalService(
      confirmation: confirmation,
      repository: repository,
      syncService: sync,
      journalDb: db,
      relationshipRepository: relationships,
      taskRemover: (task, {allowedRelationshipId}) async {
        expect(allowedRelationshipId, set.taskId);
        removed.add(task);
        return removeSucceeds;
      },
    );
    when(() => repository.getEntity(set.id)).thenAnswer((_) async => confirmed);
    when(
      () => repository.getEntitiesByAgentId(
        set.agentId,
        type: AgentEntityTypes.changeDecision,
      ),
    ).thenAnswer(
      (_) async => [
        makeTestChangeDecision(
          agentId: set.agentId,
          changeSetId: set.id,
          args: {RelationshipProposalService.receiptKey: testTask.toJson()},
        ),
      ],
    );
    when(
      () => db.journalEntityById(testTask.id),
    ).thenAnswer((_) async => testTask);
    when(() => sync.upsertEntity(any())).thenAnswer((_) async {});
    when(
      () => relationships.unlinkTask(
        relationshipId: set.taskId,
        taskId: testTask.id,
      ),
    ).thenAnswer((_) async => true);
    when(
      () => relationships.linkTask(
        relationshipId: set.taskId,
        taskId: testTask.id,
      ),
    ).thenAnswer((_) async => true);
    when(
      () => confirmation.reopenItem(any(), any(), revert: any(named: 'revert')),
    ).thenAnswer((invocation) async {
      final revert =
          invocation.namedArguments[#revert] as Future<bool> Function()?;
      return revert == null || await revert();
    });
  });

  test(
    'confirmation persists a task receipt on the decision, leaving proposal args intact',
    () async {
      when(() => confirmation.confirmItem(set, 0)).thenAnswer(
        (_) async => RelationshipTaskCreationResult(testTask),
      );
      expect((await service.confirm(set, 0)).success, isTrue);
      expect(await service.receipt(set, 0), testTask);
      verify(() => sync.upsertEntity(any())).called(1);
      expect(set.items.single.args, {'title': 'Pack fish'});
    },
  );
  test(
    'undo reads the durable receipt and removes an unchanged task after unlinking',
    () async {
      expect(await service.undo(confirmed, 0), isTrue);
      expect(removed, [testTask]);
      verify(
        () => relationships.unlinkTask(
          relationshipId: set.taskId,
          taskId: testTask.id,
        ),
      ).called(1);
    },
  );
  test('undo refuses a task changed since confirmation', () async {
    when(() => db.journalEntityById(testTask.id)).thenAnswer(
      (_) async =>
          testTask.copyWith(data: testTask.data.copyWith(title: 'Edited')),
    );
    expect(await service.undo(confirmed, 0), isFalse);
    expect(removed, isEmpty);
    verifyNever(
      () => relationships.unlinkTask(
        relationshipId: set.taskId,
        taskId: testTask.id,
      ),
    );
  });
  test(
    'a failed delete preserves the original link and refuses undo',
    () async {
      removeSucceeds = false;
      expect(await service.undo(confirmed, 0), isFalse);
      verifyNever(
        () => relationships.unlinkTask(
          relationshipId: set.taskId,
          taskId: testTask.id,
        ),
      );
    },
  );
  test('rejection makes no journal mutation', () async {
    when(() => confirmation.rejectItem(set, 0)).thenAnswer((_) async => true);
    expect(await service.reject(set, 0), isTrue);
    expect(removed, isEmpty);
    verifyNever(() => db.journalEntityById(any()));
  });

  test(
    'receipt write failure preserves success and the creation snapshot',
    () async {
      when(
        () => confirmation.confirmItem(set, 0),
      ).thenAnswer((_) async => RelationshipTaskCreationResult(testTask));
      when(() => sync.upsertEntity(any())).thenThrow(StateError('offline'));
      expect((await service.confirm(set, 0)).success, isTrue);
      expect(await service.receipt(set, 0), testTask);
      verifyNever(() => db.journalEntityById(any()));
    },
  );

  test('malformed receipt cannot enable undo', () {
    expect(
      RelationshipProposalService.decodeReceipt({'runtimeType': 'task'}),
      isNull,
    );
    expect(RelationshipProposalService.decodeReceipt('broken'), isNull);
  });

  test(
    'an edit during validation refuses deletion without touching the link',
    () async {
      var reads = 0;
      when(() => db.journalEntityById(testTask.id)).thenAnswer(
        (_) async => reads++ == 0
            ? testTask
            : testTask.copyWith(
                data: testTask.data.copyWith(title: 'Edited during validation'),
              ),
      );
      expect(await service.undo(confirmed, 0), isFalse);
      expect(removed, isEmpty);
      verifyNever(
        () => relationships.unlinkTask(
          relationshipId: set.taskId,
          taskId: testTask.id,
        ),
      );
    },
  );

  test(
    'another agent scope cannot reject or reopen a relationship proposal',
    () async {
      final foreign = set.copyWith(agentId: 'task-agent');
      expect(await service.reject(foreign, 0), isFalse);
      expect(await service.undo(foreign, 0), isFalse);
      verifyNever(() => confirmation.rejectItem(any(), any()));
      verifyNever(() => repository.getEntity(any()));
    },
  );
  test(
    'a newly linked note prevents undo even if the task itself is unchanged',
    () async {
      when(() => db.linksForEntryIdsBidirectional({testTask.id})).thenAnswer(
        (_) async => [
          EntryLink.basic(
            id: 'new-note-link',
            fromId: testTask.id,
            toId: 'note',
            createdAt: testTask.meta.createdAt,
            updatedAt: testTask.meta.createdAt,
            vectorClock: null,
          ),
        ],
      );
      expect(await service.undo(confirmed, 0), isFalse);
      expect(removed, isEmpty);
      verifyNever(
        () => relationships.unlinkTask(
          relationshipId: set.taskId,
          taskId: testTask.id,
        ),
      );
    },
  );

  test(
    'an in-flight confirmation locks out duplicate confirm, reject and undo',
    () async {
      final pending = Completer<ToolExecutionResult>();
      when(
        () => confirmation.confirmItem(set, 0),
      ).thenAnswer((_) => pending.future);
      final first = service.confirm(set, 0);
      expect((await service.confirm(set, 0)).success, isFalse);
      expect(await service.reject(set, 0), isFalse);
      expect(await service.undo(set, 0), isFalse);
      pending.complete(
        const ToolExecutionResult(success: false, output: 'retry'),
      );
      expect((await first).success, isFalse);
      when(() => confirmation.rejectItem(set, 0)).thenAnswer((_) async => true);
      expect(await service.reject(set, 0), isTrue);
      verify(() => confirmation.confirmItem(set, 0)).called(1);
    },
  );

  test(
    'missing, malformed and still-pending history cannot be undone',
    () async {
      when(() => repository.getEntity('missing')).thenAnswer((_) async => null);
      expect(await service.undoById('missing', 0), isFalse);
      expect(await service.undo(set, -1), isFalse);
      expect(await service.undo(set, 10), isFalse);
      when(() => repository.getEntity(set.id)).thenAnswer((_) async => set);
      expect(await service.undoById(set.id, 0), isFalse);
      when(() => repository.getEntity(set.id)).thenAnswer((_) async => null);
      expect(await service.undo(set, 0), isFalse);
      expect(removed, isEmpty);
    },
  );

  test('undo rejection reopens without touching journal tasks', () async {
    final rejected = set.copyWith(
      items: [set.items.single.copyWith(status: ChangeItemStatus.rejected)],
    );
    when(() => repository.getEntity(set.id)).thenAnswer((_) async => rejected);
    expect(await service.undoById(set.id, 0), isTrue);
    verify(() => confirmation.reopenItem(rejected, 0)).called(1);
    verifyNever(() => db.journalEntityById(any()));
  });

  for (final throws in [false, true]) {
    test(
      'failed link cleanup leaves only a tombstoned task (throws: $throws)',
      () async {
        when(
          () => relationships.unlinkTask(
            relationshipId: set.taskId,
            taskId: testTask.id,
          ),
        ).thenAnswer((_) async {
          expect(removed, [
            testTask,
          ], reason: 'only unlink after the task is safely removed');
          if (throws) throw StateError('link write failed');
          return false;
        });
        expect(await service.undo(confirmed, 0), isTrue);
        expect(removed, [testTask]);
        verifyNever(
          () => relationships.linkTask(
            relationshipId: set.taskId,
            taskId: testTask.id,
          ),
        );
      },
    );
  }

  test(
    'a missing decision disables undo and a successful creation keeps a local receipt',
    () async {
      when(
        () => repository.getEntitiesByAgentId(
          set.agentId,
          type: AgentEntityTypes.changeDecision,
        ),
      ).thenAnswer((_) async => []);
      expect(await service.undo(confirmed, 0), isFalse);
      when(
        () => confirmation.confirmItem(set, 0),
      ).thenAnswer((_) async => RelationshipTaskCreationResult(testTask));
      expect((await service.confirm(set, 0)).success, isTrue);
      expect(service.cachedReceipt(set.id, 0), testTask);
      verifyNever(() => sync.upsertEntity(any()));
    },
  );

  test('a non-task receipt cannot enable task deletion', () {
    expect(
      RelationshipProposalService.decodeReceipt(testRelationship.toJson()),
      isNull,
    );
  });

  for (final reverse in [false, true]) {
    test(
      'the original relationship link permits undo in either direction (reverse: $reverse)',
      () async {
        when(() => db.linksForEntryIdsBidirectional({testTask.id})).thenAnswer(
          (_) async => [
            EntryLink.relationship(
              id: 'relationship-link',
              fromId: reverse ? testTask.id : set.taskId,
              toId: reverse ? set.taskId : testTask.id,
              createdAt: testTask.meta.createdAt,
              updatedAt: testTask.meta.createdAt,
              vectorClock: null,
            ),
          ],
        );
        expect(await service.undo(confirmed, 0), isTrue);
        expect(removed, [testTask]);
      },
    );
  }
  for (final lateNote in [false, true]) {
    test(
      'undo transaction preserves a late note but allows its own link (lateNote=$lateNote)',
      () async {
        final persistence = MockPersistenceLogic();
        final links = <EntryLink>[
          EntryLink.relationship(
            id: 'person-task',
            fromId: set.taskId,
            toId: testTask.id,
            createdAt: testTask.meta.createdAt,
            updatedAt: testTask.meta.updatedAt,
            vectorClock: null,
          ),
        ];
        var tombstoned = false;
        when(
          () => db.linksForEntryIdsBidirectional({testTask.id}),
        ).thenAnswer((_) async => links);
        when(
          () => persistence.updateMetadata(
            testTask.meta,
            deletedAt: any(named: 'deletedAt'),
          ),
        ).thenAnswer((_) async {
          if (lateNote) {
            links.add(
              EntryLink.basic(
                id: 'late-note',
                fromId: testTask.id,
                toId: 'new-note',
                createdAt: testTask.meta.createdAt,
                updatedAt: testTask.meta.updatedAt,
                vectorClock: null,
              ),
            );
          }
          return testTask.meta.copyWith(deletedAt: testTask.meta.updatedAt);
        });
        when(
          () => persistence.updateDbEntity(
            any(),
            precondition: any(named: 'precondition'),
          ),
        ).thenAnswer((call) async {
          final guard =
              call.namedArguments[#precondition] as Future<bool> Function()?;
          return tombstoned = guard == null || await guard();
        });
        final dispatcher = RelationshipToolDispatcher(
          relationshipRepository: relationships,
          persistenceLogic: persistence,
          entitiesCacheService: MockEntitiesCacheService(),
          taskAgentService: MockTaskAgentService(),
          journalDb: db,
        );
        service = RelationshipProposalService(
          confirmation: confirmation,
          repository: repository,
          syncService: sync,
          journalDb: db,
          relationshipRepository: relationships,
          taskRemover: dispatcher.removeTask,
        );
        expect(await service.undo(confirmed, 0), !lateNote);
        expect(tombstoned, !lateNote);
        if (lateNote) {
          verifyNever(
            () => relationships.unlinkTask(
              relationshipId: set.taskId,
              taskId: testTask.id,
            ),
          );
          expect(await service.receipt(confirmed, 0), testTask);
        } else {
          verify(
            () => relationships.unlinkTask(
              relationshipId: set.taskId,
              taskId: testTask.id,
            ),
          ).called(1);
        }
      },
    );
  }
}
