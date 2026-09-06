import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
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
  late RelationshipToolDispatcher dispatcher;
  setUp(() {
    relationships = MockRelationshipRepository();
    persistence = MockPersistenceLogic();
    cache = MockEntitiesCacheService();
    agents = MockTaskAgentService();
    dispatcher = RelationshipToolDispatcher(
      relationshipRepository: relationships,
      persistenceLogic: persistence,
      entitiesCacheService: cache,
      taskAgentService: agents,
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
    when(() => persistence.updateDbEntity(any())).thenAnswer((_) async => true);
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
                  () => persistence.updateDbEntity(captureAny()),
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
        () => persistence.updateDbEntity(any()),
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
      verify(() => persistence.updateDbEntity(any())).called(1);
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
        () => persistence.updateDbEntity(any()),
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
}
