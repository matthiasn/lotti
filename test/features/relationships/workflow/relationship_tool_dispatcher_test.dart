import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/relationships/workflow/relationship_tool_dispatcher.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../agents/test_data/entity_factories.dart';

void main() {
  setUpAll(registerAllFallbackValues);
  final now = DateTime(2026, 9, 6, 12);
  final person = testRelationship.copyWith(
    data: testRelationship.data.copyWith(important: true),
    meta: testRelationship.meta.copyWith(categoryId: 'category', private: true),
  );
  final task = testTask.copyWith(
    meta: testTask.meta.copyWith(id: 'created-task', categoryId: 'category'),
  );
  final evidence = CheckInEntry(
    meta: person.meta.copyWith(id: 'evidence'),
    data: CheckInData(
      relationshipId: person.id,
      interactionType: CheckInInteractionType.call,
    ),
    entryText: const EntryText(plainText: 'I promised to send the checklist.'),
  );
  final args = <String, dynamic>{
    'title': 'Send the checklist',
    'description': 'I promised to send the checklist.',
    'sourceCheckInId': evidence.id,
    'reason': 'An explicit commitment.',
    'dueDate': '2026-09-10',
  };
  late MockRelationshipRepository relationships;
  late MockPersistenceLogic persistence;
  late MockEntitiesCacheService cache;
  late MockTaskAgentService agents;
  late MockJournalDb db;
  late RelationshipToolDispatcher dispatcher;
  setUp(() {
    relationships = MockRelationshipRepository();
    persistence = MockPersistenceLogic();
    cache = MockEntitiesCacheService();
    agents = MockTaskAgentService();
    db = MockJournalDb();
    when(() => db.journalEntityById(any())).thenAnswer(
      (call) async => call.positionalArguments.single == task.id ? task : null,
    );
    when(
      () => db.linksForEntryIdsBidirectional(any()),
    ).thenAnswer((_) async => []);
    dispatcher = RelationshipToolDispatcher(
      relationshipRepository: relationships,
      persistenceLogic: persistence,
      entitiesCacheService: cache,
      taskAgentService: agents,
      journalDb: db,
    );
    when(
      () => relationships.getRelationshipById(person.id),
    ).thenAnswer((_) async => person);
    when(
      () => relationships.getCheckInsForRelationship(person.id),
    ).thenAnswer((_) async => [evidence]);
    when(() => cache.getCategoryById('category')).thenReturn(null);
    when(
      () => persistence.createTaskEntry(
        id: any(named: 'id'),
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        categoryId: any(named: 'categoryId'),
        private: any(named: 'private'),
      ),
    ).thenAnswer((_) async => task);
    when(
      () => relationships.linkTask(relationshipId: person.id, taskId: task.id),
    ).thenAnswer((_) async => true);
    when(
      () => persistence.updateMetadata(
        task.meta,
        deletedAt: any(named: 'deletedAt'),
      ),
    ).thenAnswer((_) async => task.meta.copyWith(deletedAt: now));
    when(
      () => persistence.updateDbEntity(
        any(),
        precondition: any(named: 'precondition'),
      ),
    ).thenAnswer((call) async {
      final guard =
          call.namedArguments[#precondition] as Future<bool> Function()?;
      return guard == null || await guard();
    });
  });

  test(
    'confirmation creates and links the private task with due date and evidence',
    () async {
      final result = await withClock(
        Clock.fixed(now),
        () => dispatcher.dispatch('create_and_link_task', args, person.id),
      );
      expect(result.success, isTrue);
      expect(result.mutatedEntityId, task.id);
      expect((result as RelationshipTaskCreationResult).task, task);
      final captured = verify(
        () => persistence.createTaskEntry(
          id: any(named: 'id'),
          data: captureAny(named: 'data'),
          entryText: captureAny(named: 'entryText'),
          categoryId: 'category',
          private: true,
        ),
      ).captured;
      final data = captured[0] as TaskData;
      expect(data.title, args['title']);
      expect(data.due, DateTime(2026, 9, 10));
      expect(
        (captured[1] as EntryText).plainText,
        contains(args['description']),
      );
      verify(
        () =>
            relationships.linkTask(relationshipId: person.id, taskId: task.id),
      ).called(1);
    },
  );

  for (final throwing in [false, true]) {
    test(
      'a ${throwing ? 'throwing' : 'refused'} link compensates task creation',
      () async {
        final stub = when(
          () => relationships.linkTask(
            relationshipId: person.id,
            taskId: task.id,
          ),
        );
        if (throwing) {
          stub.thenThrow(StateError('link failed'));
        } else {
          stub.thenAnswer((_) async => false);
        }
        final result = await dispatcher.dispatch(
          'create_and_link_task',
          args,
          person.id,
        );
        expect(result.success, isFalse);
        expect(result.nonRetryable, isFalse);
        final deleted =
            verify(
                  () => persistence.updateDbEntity(
                    captureAny(),
                    precondition: any(named: 'precondition'),
                  ),
                ).captured.single
                as Task;
        expect(deleted.meta.deletedAt, now);
      },
    );
  }

  test(
    'failed compensation retracts instead of allowing duplicate tasks on retry',
    () async {
      when(
        () =>
            relationships.linkTask(relationshipId: person.id, taskId: task.id),
      ).thenAnswer((_) async => false);
      when(
        () => persistence.updateDbEntity(
          any(),
          precondition: any(named: 'precondition'),
        ),
      ).thenAnswer((_) async => false);
      final result = await dispatcher.dispatch(
        'create_and_link_task',
        args,
        person.id,
      );
      expect(result.success, isFalse);
      expect(result.nonRetryable, isTrue);
    },
  );

  test(
    'rejects missing evidence, another person’s evidence and withdrawn consent',
    () async {
      for (final source in [
        null,
        evidence.copyWith(
          data: evidence.data.copyWith(relationshipId: 'someone-else'),
        ),
      ]) {
        when(
          () => relationships.getCheckInsForRelationship(person.id),
        ).thenAnswer((_) async => [?source]);
        expect(
          (await dispatcher.dispatch(
            'create_and_link_task',
            args,
            person.id,
          )).nonRetryable,
          isTrue,
        );
      }
      when(
        () => relationships.getRelationshipById(person.id),
      ).thenAnswer((_) async => null);
      expect(
        (await dispatcher.dispatch(
          'create_and_link_task',
          args,
          person.id,
        )).nonRetryable,
        isTrue,
      );
      verifyNever(
        () => persistence.createTaskEntry(
          id: any(named: 'id'),
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: any(named: 'categoryId'),
          private: any(named: 'private'),
        ),
      );
    },
  );

  test(
    'inherits category profile and provisions the category default agent',
    () async {
      when(() => cache.getCategoryById('category')).thenReturn(
        CategoryDefinition(
          id: 'category',
          createdAt: now,
          updatedAt: now,
          name: 'Penguin crew',
          vectorClock: null,
          private: false,
          active: true,
          defaultProfileId: 'profile',
          defaultTemplateId: 'template',
        ),
      );
      when(
        () => agents.createTaskAgent(
          taskId: task.id,
          templateId: 'template',
          profileId: 'profile',
          setupOrigin: AgentInferenceSetupOrigin.categorySnapshot,
          setupOriginEntityId: 'category',
          allowedCategoryIds: {'category'},
          awaitContent: true,
          automaticUpdatesEnabled: any(named: 'automaticUpdatesEnabled'),
        ),
      ).thenAnswer((_) async => makeTestIdentity());
      expect(
        (await dispatcher.dispatch(
          'create_and_link_task',
          args,
          person.id,
        )).success,
        isTrue,
      );
      final data =
          verify(
                () => persistence.createTaskEntry(
                  id: any(named: 'id'),
                  data: captureAny(named: 'data'),
                  entryText: any(named: 'entryText'),
                  categoryId: 'category',
                  private: true,
                ),
              ).captured.single
              as TaskData;
      expect(data.profileId, 'profile');
      verify(
        () => agents.createTaskAgent(
          taskId: task.id,
          templateId: 'template',
          profileId: 'profile',
          setupOrigin: AgentInferenceSetupOrigin.categorySnapshot,
          setupOriginEntityId: 'category',
          allowedCategoryIds: {'category'},
          awaitContent: true,
          automaticUpdatesEnabled: any(named: 'automaticUpdatesEnabled'),
        ),
      ).called(1);
    },
  );

  test('a changed quote retracts before creating a task', () async {
    final result = await dispatcher.dispatch('create_and_link_task', {
      ...args,
      'description': 'I promised something else.',
    }, person.id);
    expect(result.success, isFalse);
    expect(result.nonRetryable, isTrue);
    verifyNever(
      () => persistence.createTaskEntry(
        id: any(named: 'id'),
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        categoryId: any(named: 'categoryId'),
        private: any(named: 'private'),
      ),
    );
  });

  test(
    'consent withdrawn during creation rolls back without linking',
    () async {
      var reads = 0;
      when(() => relationships.getRelationshipById(person.id)).thenAnswer(
        (_) async => reads++ == 0
            ? person
            : person.copyWith(data: person.data.copyWith(important: false)),
      );
      final result = await dispatcher.dispatch(
        'create_and_link_task',
        args,
        person.id,
      );
      expect(result.success, isFalse);
      verifyNever(
        () =>
            relationships.linkTask(relationshipId: person.id, taskId: task.id),
      );
      verify(
        () => persistence.updateDbEntity(
          any(),
          precondition: any(named: 'precondition'),
        ),
      ).called(1);
    },
  );

  test('unknown tools and malformed proposals cannot create a task', () async {
    for (final input in [
      ('unknown', args),
      ('create_and_link_task', <String, dynamic>{}),
      ('create_and_link_task', {...args, 'dueDate': '2026-02-30'}),
    ]) {
      final result = await dispatcher.dispatch(input.$1, input.$2, person.id);
      expect(result.success, isFalse);
      expect(result.nonRetryable, isTrue);
    }
    verifyNever(
      () => persistence.createTaskEntry(
        id: any(named: 'id'),
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        categoryId: any(named: 'categoryId'),
        private: any(named: 'private'),
      ),
    );
  });

  test(
    'refused creation stays retryable and never attempts a relationship link',
    () async {
      when(
        () => persistence.createTaskEntry(
          id: any(named: 'id'),
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: any(named: 'categoryId'),
          private: any(named: 'private'),
        ),
      ).thenAnswer((_) async => null);
      final result = await dispatcher.dispatch(
        'create_and_link_task',
        args,
        person.id,
      );
      expect(result.success, isFalse);
      expect(result.nonRetryable, isFalse);
      verifyNever(
        () =>
            relationships.linkTask(relationshipId: person.id, taskId: task.id),
      );
    },
  );

  test(
    'metadata failures and refused tombstone writes refuse compensation',
    () async {
      when(
        () => persistence.updateDbEntity(
          any(),
          precondition: any(named: 'precondition'),
        ),
      ).thenAnswer((_) async => null);
      expect(await dispatcher.removeTask(task), isFalse);
      when(
        () => persistence.updateMetadata(
          task.meta,
          deletedAt: any(named: 'deletedAt'),
        ),
      ).thenThrow(StateError('database unavailable'));
      expect(await dispatcher.removeTask(task), isFalse);
    },
  );

  test(
    'private evidence keeps a public person’s task private, and no due date stays absent',
    () async {
      when(() => relationships.getRelationshipById(person.id)).thenAnswer(
        (_) async =>
            person.copyWith(meta: person.meta.copyWith(private: false)),
      );
      final input = {...args}..remove('dueDate');
      expect(
        (await dispatcher.dispatch(
          'create_and_link_task',
          input,
          person.id,
        )).success,
        isTrue,
      );
      final captured = verify(
        () => persistence.createTaskEntry(
          id: any(named: 'id'),
          data: captureAny(named: 'data'),
          entryText: captureAny(named: 'entryText'),
          categoryId: 'category',
          private: true,
        ),
      ).captured;
      expect((captured[0] as TaskData).due, isNull);
      expect(
        (captured[1] as EntryText).markdown,
        contains('(lotti://journal/${evidence.id})'),
      );
    },
  );

  test(
    'two independent devices create the same task identity despite different clocks',
    () async {
      final other = RelationshipToolDispatcher(
        relationshipRepository: relationships,
        persistenceLogic: persistence,
        entitiesCacheService: cache,
        taskAgentService: agents,
        journalDb: db,
      );
      expect(
        (await withClock(
          Clock.fixed(now),
          () => dispatcher.dispatch('create_and_link_task', args, person.id),
        )).success,
        isTrue,
      );
      expect(
        (await withClock(
          Clock.fixed(now.add(const Duration(hours: 2))),
          () => other.dispatch('create_and_link_task', Map.of(args), person.id),
        )).success,
        isTrue,
      );
      final captures = verify(
        () => persistence.createTaskEntry(
          id: captureAny(named: 'id'),
          data: captureAny(named: 'data'),
          entryText: any(named: 'entryText'),
          categoryId: any(named: 'categoryId'),
          private: any(named: 'private'),
        ),
      ).captured;
      final ids = captures.whereType<String>().toList();
      final payloads = captures.whereType<TaskData>().toList();
      expect(ids.first, isNotEmpty);
      expect(ids.first, ids.last);
      expect(payloads.first.dateFrom, now);
      expect(
        payloads.last.dateFrom,
        now.add(const Duration(hours: 2)),
      );
    },
  );

  for (final linked in [true, false]) {
    test(
      'an existing peer task is never overwritten or made undoable (linked: $linked)',
      () async {
        when(() => db.journalEntityById(any())).thenAnswer(
          (invocation) async => task.copyWith(
            meta: task.meta.copyWith(
              id: invocation.positionalArguments.first as String,
            ),
            data: task.data.copyWith(title: 'Already edited by a peer'),
          ),
        );
        when(
          () => relationships.linkTask(
            relationshipId: person.id,
            taskId: any(named: 'taskId'),
          ),
        ).thenAnswer((_) async => linked);
        final result = await dispatcher.dispatch(
          'create_and_link_task',
          args,
          person.id,
        );
        expect(result.success, linked);
        expect(result, isNot(isA<RelationshipTaskCreationResult>()));
        verifyNever(
          () => persistence.createTaskEntry(
            id: any(named: 'id'),
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
            private: any(named: 'private'),
          ),
        );
        verifyNever(
          () => persistence.updateDbEntity(
            any(),
            precondition: any(named: 'precondition'),
          ),
        );
      },
    );
  }

  for (final saved in [true, false]) {
    test(
      'confirmation after undo restores the tombstoned identity (saved: $saved)',
      () async {
        String? identity;
        when(() => db.journalEntityById(any())).thenAnswer((invocation) async {
          identity = invocation.positionalArguments.first as String;
          return task.copyWith(
            meta: task.meta.copyWith(id: identity!, deletedAt: now),
          );
        });
        when(
          () => persistence.updateMetadata(
            any(),
            dateFrom: any(named: 'dateFrom'),
            dateTo: any(named: 'dateTo'),
          ),
        ).thenAnswer(
          (invocation) async =>
              invocation.positionalArguments.first as Metadata,
        );
        when(
          () => persistence.updateDbEntity(
            any(),
            precondition: any(named: 'precondition'),
          ),
        ).thenAnswer((_) async => saved);
        when(
          () => relationships.linkTask(
            relationshipId: person.id,
            taskId: any(named: 'taskId'),
          ),
        ).thenAnswer((_) async => true);
        final result = await dispatcher.dispatch(
          'create_and_link_task',
          args,
          person.id,
        );
        expect(result.success, saved);
        final restored =
            verify(
                  () => persistence.updateDbEntity(
                    captureAny(),
                    precondition: any(named: 'precondition'),
                  ),
                ).captured.single
                as Task;
        expect(restored.id, identity);
        expect(restored.meta.deletedAt, isNull);
        expect(restored.data.title, args['title']);
        if (saved) {
          expect((result as RelationshipTaskCreationResult).task, restored);
        } else {
          verifyNever(
            () => relationships.linkTask(
              relationshipId: person.id,
              taskId: any(named: 'taskId'),
            ),
          );
        }
        verifyNever(
          () => persistence.createTaskEntry(
            id: any(named: 'id'),
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            categoryId: any(named: 'categoryId'),
            private: any(named: 'private'),
          ),
        );
      },
    );
  }

  test('a non-task identity collision refuses creation', () async {
    when(() => db.journalEntityById(any())).thenAnswer((_) async => person);
    final result = await dispatcher.dispatch(
      'create_and_link_task',
      args,
      person.id,
    );
    expect(result.success, isFalse);
    expect(result.nonRetryable, isTrue);
    verifyNever(
      () => persistence.createTaskEntry(
        id: any(named: 'id'),
        data: any(named: 'data'),
        entryText: any(named: 'entryText'),
        categoryId: any(named: 'categoryId'),
        private: any(named: 'private'),
      ),
    );
  });

  test(
    'a failed default agent assignment keeps the successfully linked task',
    () async {
      when(() => cache.getCategoryById('category')).thenReturn(
        CategoryDefinition(
          id: 'category',
          createdAt: now,
          updatedAt: now,
          name: 'Penguin crew',
          vectorClock: null,
          private: false,
          active: true,
          defaultProfileId: 'profile',
          defaultTemplateId: 'template',
        ),
      );
      when(
        () => agents.createTaskAgent(
          taskId: task.id,
          templateId: 'template',
          profileId: 'profile',
          setupOrigin: AgentInferenceSetupOrigin.categorySnapshot,
          setupOriginEntityId: 'category',
          allowedCategoryIds: {'category'},
          awaitContent: true,
          automaticUpdatesEnabled: any(named: 'automaticUpdatesEnabled'),
        ),
      ).thenThrow(StateError('agent unavailable'));
      final result = await dispatcher.dispatch(
        'create_and_link_task',
        args,
        person.id,
      );
      expect(result.success, isTrue);
      expect(result.mutatedEntityId, task.id);
      verify(
        () =>
            relationships.linkTask(relationshipId: person.id, taskId: task.id),
      ).called(1);
      verifyNever(
        () => persistence.updateDbEntity(
          any(),
          precondition: any(named: 'precondition'),
        ),
      );
    },
  );
  EntryLink personLink({
    String? from,
    String? to,
    bool hidden = false,
    bool deleted = false,
  }) => EntryLink.relationship(
    id: 'peer-link',
    fromId: from ?? person.id,
    toId: to ?? task.id,
    createdAt: now,
    updatedAt: now,
    vectorClock: null,
    hidden: hidden,
    deletedAt: deleted ? now : null,
  );

  for (final reverse in [false, true]) {
    test(
      'duplicate relationship link is success without an undo receipt (reverse=$reverse)',
      () async {
        when(
          () => relationships.linkTask(
            relationshipId: person.id,
            taskId: task.id,
          ),
        ).thenAnswer((_) async {
          when(() => db.linksForEntryIdsBidirectional({task.id})).thenAnswer(
            (_) async => [
              personLink(
                from: reverse ? task.id : person.id,
                to: reverse ? person.id : task.id,
              ),
            ],
          );
          return false;
        });
        final result = await dispatcher.dispatch(
          'create_and_link_task',
          args,
          person.id,
        );
        expect(result.success, isTrue);
        expect(result.mutatedEntityId, task.id);
        expect(result, isNot(isA<RelationshipTaskCreationResult>()));
        verifyNever(
          () => persistence.updateMetadata(
            any(),
            deletedAt: any(named: 'deletedAt'),
          ),
        );
      },
    );
  }

  test(
    'a throwing link write preserves a peer-linked task during compensation',
    () async {
      when(
        () =>
            relationships.linkTask(relationshipId: person.id, taskId: task.id),
      ).thenAnswer((_) async {
        when(
          () => db.linksForEntryIdsBidirectional({task.id}),
        ).thenAnswer((_) async => [personLink()]);
        throw StateError('local link failure');
      });
      final result = await dispatcher.dispatch(
        'create_and_link_task',
        args,
        person.id,
      );
      expect(result.success, isFalse);
      expect(result.nonRetryable, isTrue);
      expect(result.errorMessage, contains('rollback failed'));
    },
  );

  for (final (name, link, personId, allowed) in [
    ('peer', personLink(), null, false),
    ('hidden', personLink(hidden: true), null, false),
    ('other person', personLink(from: 'other-person'), person.id, false),
    ('reverse', personLink(from: task.id, to: person.id), person.id, true),
    ('deleted link', personLink(deleted: true), null, true),
  ]) {
    test('transactional removal guard handles $name', () async {
      when(
        () => db.linksForEntryIdsBidirectional({task.id}),
      ).thenAnswer((_) async => [link]);
      expect(
        await dispatcher.removeTask(task, allowedRelationshipId: personId),
        allowed,
      );
    });
  }

  for (final (name, current) in [
    ('edit', task.copyWith(data: task.data.copyWith(title: 'Edited by user'))),
    ('missing', null),
    ('deleted', task.copyWith(meta: task.meta.copyWith(deletedAt: now))),
  ]) {
    test('transactional removal guard refuses a $name snapshot', () async {
      when(
        () => persistence.updateMetadata(
          task.meta,
          deletedAt: any(named: 'deletedAt'),
        ),
      ).thenAnswer((_) async {
        when(
          () => db.journalEntityById(task.id),
        ).thenAnswer((_) async => current);
        return task.meta.copyWith(deletedAt: now);
      });
      expect(await dispatcher.removeTask(task), isFalse);
    });
  }
}
