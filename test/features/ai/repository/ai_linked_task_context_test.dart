import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/features/tasks/repository/task_progress_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockSelectable<T> extends Mock implements Selectable<T> {}

class MockTaskProgressRepository extends Mock
    implements TaskProgressRepository {
  @override
  TaskProgressState getTaskProgress({
    required Map<String, Duration> durations,
    Duration? estimate,
  }) {
    var progress = Duration.zero;
    for (final duration in durations.values) {
      progress = progress + duration;
    }
    return TaskProgressState(
      progress: progress,
      estimate: estimate ?? Duration.zero,
    );
  }
}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

void main() {
  group('AiLinkedTaskContext', () {
    final testDate = DateTime(2025, 12, 20, 14, 30);
    final createdDate = DateTime(2025, 12, 15, 10);

    test('serializes to JSON correctly', () {
      final context = AiLinkedTaskContext(
        id: 'task-123',
        title: 'Implement login form',
        status: 'DONE',
        statusSince: testDate,
        priority: 'P1',
        estimate: '02:00',
        timeSpent: '01:45',
        createdAt: createdDate,
        labels: [
          {'id': 'l1', 'name': 'frontend'},
        ],
        languageCode: 'en',
        latestSummary: 'Implemented the login form with validation.',
      );

      final json = context.toJson();

      expect(json['id'], equals('task-123'));
      expect(json['title'], equals('Implement login form'));
      expect(json['status'], equals('DONE'));
      expect(json['statusSince'], equals(testDate.toIso8601String()));
      expect(json['priority'], equals('P1'));
      expect(json['estimate'], equals('02:00'));
      expect(json['timeSpent'], equals('01:45'));
      expect(json['createdAt'], equals(createdDate.toIso8601String()));
      expect(json['labels'], isA<List<Map<String, String>>>());
      expect((json['labels']! as List<Map<String, String>>).length, equals(1));
      expect(json['languageCode'], equals('en'));
      expect(
        json['latestSummary'],
        equals('Implemented the login form with validation.'),
      );
    });

    test('deserializes from JSON correctly', () {
      final json = {
        'id': 'task-456',
        'title': 'Authentication Epic',
        'status': 'IN PROGRESS',
        'statusSince': testDate.toIso8601String(),
        'priority': 'P0',
        'estimate': '40:00',
        'timeSpent': '12:30',
        'createdAt': createdDate.toIso8601String(),
        'labels': [
          {'id': 'l2', 'name': 'auth'},
          {'id': 'l3', 'name': 'epic'},
        ],
        'languageCode': 'en',
        'latestSummary': 'Parent epic for authentication.',
      };

      final context = AiLinkedTaskContext.fromJson(json);

      expect(context.id, equals('task-456'));
      expect(context.title, equals('Authentication Epic'));
      expect(context.status, equals('IN PROGRESS'));
      expect(context.statusSince, equals(testDate));
      expect(context.priority, equals('P0'));
      expect(context.estimate, equals('40:00'));
      expect(context.timeSpent, equals('12:30'));
      expect(context.createdAt, equals(createdDate));
      expect(context.labels.length, equals(2));
      expect(context.languageCode, equals('en'));
      expect(context.latestSummary, equals('Parent epic for authentication.'));
    });

    test('handles null latestSummary', () {
      final context = AiLinkedTaskContext(
        id: 'task-789',
        title: 'New Task',
        status: 'OPEN',
        statusSince: testDate,
        priority: 'P2',
        estimate: '00:00',
        timeSpent: '00:00',
        createdAt: createdDate,
        labels: [],
      );

      final json = context.toJson();

      expect(json['latestSummary'], isNull);

      // Round-trip test
      final restored = AiLinkedTaskContext.fromJson(json);
      expect(restored.latestSummary, isNull);
    });

    test('handles null languageCode', () {
      final context = AiLinkedTaskContext(
        id: 'task-abc',
        title: 'Task without language',
        status: 'GROOMED',
        statusSince: testDate,
        priority: 'P3',
        estimate: '01:00',
        timeSpent: '00:00',
        createdAt: createdDate,
        labels: [],
      );

      final json = context.toJson();

      expect(json['languageCode'], isNull);

      // Round-trip test
      final restored = AiLinkedTaskContext.fromJson(json);
      expect(restored.languageCode, isNull);
    });

    test('handles empty labels list', () {
      final context = AiLinkedTaskContext(
        id: 'task-xyz',
        title: 'Task without labels',
        status: 'BLOCKED',
        statusSince: testDate,
        priority: 'P1',
        estimate: '03:00',
        timeSpent: '02:00',
        createdAt: createdDate,
        labels: [],
      );

      final json = context.toJson();

      expect(json['labels'], isA<List<Map<String, String>>>());
      expect((json['labels']! as List<Map<String, String>>).isEmpty, isTrue);
    });

    test('JSON output is valid for prompt injection', () {
      final linkedFrom = [
        AiLinkedTaskContext(
          id: 'child-1',
          title: 'Child Task 1',
          status: 'DONE',
          statusSince: testDate,
          priority: 'P2',
          estimate: '01:00',
          timeSpent: '00:45',
          createdAt: createdDate,
          labels: [
            {'id': 'l1', 'name': 'frontend'},
          ],
          languageCode: 'en',
          latestSummary:
              'Completed the UI.\n\n## Links\n- [PR #123](https://github.com/org/repo/pull/123)',
        ),
      ];

      final linkedTo = [
        AiLinkedTaskContext(
          id: 'parent-1',
          title: 'Parent Epic',
          status: 'IN PROGRESS',
          statusSince: testDate,
          priority: 'P0',
          estimate: '40:00',
          timeSpent: '12:30',
          createdAt: createdDate,
          labels: [
            {'id': 'l2', 'name': 'epic'},
          ],
          languageCode: 'en',
          latestSummary: 'Epic for the feature.',
        ),
      ];

      final data = <String, dynamic>{
        'linked_from': linkedFrom.map((c) => c.toJson()).toList(),
        'linked_to': linkedTo.map((c) => c.toJson()).toList(),
        'note': 'If summaries contain links to GitHub PRs, Issues, or similar '
            'platforms, use web search to retrieve additional context when relevant.',
      };

      const encoder = JsonEncoder.withIndent('    ');
      final jsonString = encoder.convert(data);

      // Verify the JSON is valid
      expect(() => jsonDecode(jsonString), returnsNormally);

      // Verify structure
      final parsed = jsonDecode(jsonString) as Map<String, dynamic>;
      expect(parsed['linked_from'], isA<List<dynamic>>());
      expect(parsed['linked_to'], isA<List<dynamic>>());
      expect(parsed['note'], contains('web search'));

      // Verify linked_from content
      final linkedFromParsed = parsed['linked_from'] as List<dynamic>;
      expect(linkedFromParsed.length, equals(1));
      final linkedFromFirst = linkedFromParsed[0] as Map<String, dynamic>;
      expect(linkedFromFirst['title'], equals('Child Task 1'));
      expect(linkedFromFirst['latestSummary'], contains('[PR #123]'));

      // Verify linked_to content
      final linkedToParsed = parsed['linked_to'] as List<dynamic>;
      expect(linkedToParsed.length, equals(1));
      final linkedToFirst = linkedToParsed[0] as Map<String, dynamic>;
      expect(linkedToFirst['title'], equals('Parent Epic'));
    });

    test('handles all task statuses', () {
      final statuses = [
        'OPEN',
        'GROOMED',
        'IN PROGRESS',
        'BLOCKED',
        'ON HOLD',
        'DONE',
        'REJECTED',
      ];

      for (final status in statuses) {
        final context = AiLinkedTaskContext(
          id: 'task-$status',
          title: 'Task with status $status',
          status: status,
          statusSince: testDate,
          priority: 'P2',
          estimate: '01:00',
          timeSpent: '00:30',
          createdAt: createdDate,
          labels: [],
        );

        final json = context.toJson();
        expect(json['status'], equals(status));

        final restored = AiLinkedTaskContext.fromJson(json);
        expect(restored.status, equals(status));
      }
    });

    test('handles all priority levels', () {
      final priorities = ['P0', 'P1', 'P2', 'P3'];

      for (final priority in priorities) {
        final context = AiLinkedTaskContext(
          id: 'task-$priority',
          title: 'Task with priority $priority',
          status: 'OPEN',
          statusSince: testDate,
          priority: priority,
          estimate: '01:00',
          timeSpent: '00:00',
          createdAt: createdDate,
          labels: [],
        );

        final json = context.toJson();
        expect(json['priority'], equals(priority));

        final restored = AiLinkedTaskContext.fromJson(json);
        expect(restored.priority, equals(priority));
      }
    });
  });

  group('AiInputRepository - Linked Task Context', () {
    late MockJournalDb mockDb;
    late MockTaskProgressRepository mockTaskProgressRepository;
    late MockPersistenceLogic mockPersistenceLogic;
    late MockEntitiesCacheService mockCacheService;
    late ProviderContainer container;
    late AiInputRepository repository;

    final testDate = DateTime(2025, 12, 20, 14, 30);
    final createdDate = DateTime(2025, 12, 15, 10);
    const taskId = 'task-123';
    const childTaskId = 'child-task-456';
    const parentTaskId = 'parent-task-789';

    setUp(() {
      mockDb = MockJournalDb();
      mockTaskProgressRepository = MockTaskProgressRepository();
      mockPersistenceLogic = MockPersistenceLogic();
      mockCacheService = MockEntitiesCacheService();
      container = ProviderContainer(
        overrides: [
          taskProgressRepositoryProvider
              .overrideWithValue(mockTaskProgressRepository),
        ],
      );

      getIt
        ..registerSingleton<JournalDb>(mockDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<EntitiesCacheService>(mockCacheService);

      repository = container.read(aiInputRepositoryProvider);

      // Default mocks
      when(() => mockTaskProgressRepository.getTaskProgressData(
            id: any(named: 'id'),
          )).thenAnswer((_) async => (null, <String, Duration>{}));
      when(() => mockDb.journalEntityById(any())).thenAnswer((_) async => null);
      when(() => mockDb.getLinkedEntities(any()))
          .thenAnswer((_) async => <JournalEntity>[]);
      when(() => mockDb.getBulkLinkedEntities(any()))
          .thenAnswer((_) async => <String, List<JournalEntity>>{});
      when(() => mockDb.getAllLabelDefinitions())
          .thenAnswer((_) async => <LabelDefinition>[]);
      when(() => mockCacheService.getLabelById(any())).thenReturn(null);
    });

    tearDown(() {
      container.dispose();
      getIt
        ..unregister<JournalDb>()
        ..unregister<PersistenceLogic>()
        ..unregister<EntitiesCacheService>();
    });

    Task createTestTask({
      required String id,
      required String title,
      TaskStatus? status,
      DateTime? createdAt,
      List<String>? labelIds,
      Duration? estimate,
      String? languageCode,
      DateTime? deletedAt,
    }) {
      final taskStatus = status ??
          TaskStatus.inProgress(
            id: 'status-$id',
            createdAt: createdAt ?? createdDate,
            utcOffset: 0,
          );
      return Task(
        meta: Metadata(
          id: id,
          dateFrom: createdAt ?? createdDate,
          dateTo: createdAt ?? createdDate,
          createdAt: createdAt ?? createdDate,
          updatedAt: createdAt ?? createdDate,
          labelIds: labelIds,
          deletedAt: deletedAt,
        ),
        data: TaskData(
          title: title,
          status: taskStatus,
          statusHistory: [],
          dateFrom: createdAt ?? createdDate,
          dateTo: createdAt ?? createdDate,
          estimate: estimate,
          languageCode: languageCode,
        ),
      );
    }

    JournalDbEntity createDbEntityFromTask(Task task) {
      return JournalDbEntity(
        id: task.id,
        createdAt: task.meta.createdAt,
        updatedAt: task.meta.updatedAt,
        dateFrom: task.meta.dateFrom,
        dateTo: task.meta.dateTo,
        deleted: task.meta.deletedAt != null,
        starred: false,
        private: false,
        task: true,
        flag: 0,
        type: 'Task',
        serialized: jsonEncode(task.toJson()),
        schemaVersion: 1,
        plainText: task.data.title,
        category: '',
      );
    }

    /// Creates a JournalEntry with specified duration for time tracking tests.
    JournalEntity createJournalEntryWithDuration({
      required String id,
      required Duration duration,
      DateTime? dateFrom,
    }) {
      final from = dateFrom ?? createdDate;
      return JournalEntity.journalEntry(
        meta: Metadata(
          id: id,
          dateFrom: from,
          dateTo: from.add(duration),
          createdAt: from,
          updatedAt: from,
        ),
      );
    }

    group('buildLinkedFromContext', () {
      test('returns empty list when no tasks link to this task', () async {
        final mockSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockDb.linkedToJournalEntities(taskId))
            .thenReturn(mockSelectable);
        when(mockSelectable.get).thenAnswer((_) async => []);

        final result = await repository.buildLinkedFromContext(taskId);

        expect(result, isEmpty);
        verify(() => mockDb.linkedToJournalEntities(taskId)).called(1);
      });

      test('returns context for child tasks linking to this task', () async {
        final childTask = createTestTask(
          id: childTaskId,
          title: 'Child Task',
          estimate: const Duration(hours: 2),
          languageCode: 'en',
        );
        final childDbEntity = createDbEntityFromTask(childTask);

        // Create a journal entry with 45 minutes duration for time tracking
        final timeEntry = createJournalEntryWithDuration(
          id: 'time-entry-1',
          duration: const Duration(minutes: 45),
        );

        final mockSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockDb.linkedToJournalEntities(taskId))
            .thenReturn(mockSelectable);
        when(mockSelectable.get).thenAnswer((_) async => [childDbEntity]);
        // Bulk fetch returns entities for time calculation
        when(() => mockDb.getBulkLinkedEntities({childTaskId}))
            .thenAnswer((_) async => {
                  childTaskId: [timeEntry]
                });

        final result = await repository.buildLinkedFromContext(taskId);

        expect(result.length, equals(1));
        expect(result[0].id, equals(childTaskId));
        expect(result[0].title, equals('Child Task'));
        expect(result[0].status, equals('IN PROGRESS'));
        expect(result[0].estimate, equals('02:00'));
        expect(result[0].timeSpent, equals('00:45'));
        expect(result[0].languageCode, equals('en'));
      });

      test('filters out deleted tasks', () async {
        final deletedTask = createTestTask(
          id: 'deleted-task',
          title: 'Deleted Task',
          status: TaskStatus.open(
            id: 'status-deleted',
            createdAt: createdDate,
            utcOffset: 0,
          ),
          deletedAt: testDate, // Marked as deleted
        );
        final deletedDbEntity = createDbEntityFromTask(deletedTask);

        final mockSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockDb.linkedToJournalEntities(taskId))
            .thenReturn(mockSelectable);
        when(mockSelectable.get).thenAnswer((_) async => [deletedDbEntity]);

        final result = await repository.buildLinkedFromContext(taskId);

        expect(result, isEmpty);
      });

      test('sorts tasks by creation date (oldest first)', () async {
        final olderTask = createTestTask(
          id: 'older-task',
          title: 'Older Task',
          createdAt: DateTime(2025, 12, 10),
        );
        final newerTask = createTestTask(
          id: 'newer-task',
          title: 'Newer Task',
          createdAt: DateTime(2025, 12, 20),
        );
        final olderDbEntity = createDbEntityFromTask(olderTask);
        final newerDbEntity = createDbEntityFromTask(newerTask);

        final mockSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockDb.linkedToJournalEntities(taskId))
            .thenReturn(mockSelectable);
        // Return in reverse order to test sorting
        when(mockSelectable.get)
            .thenAnswer((_) async => [newerDbEntity, olderDbEntity]);
        when(() => mockDb.getLinkedEntities(any())).thenAnswer((_) async => []);
        when(() => mockTaskProgressRepository.getTaskProgressData(
              id: any(named: 'id'),
            )).thenAnswer((_) async => (null, <String, Duration>{}));

        final result = await repository.buildLinkedFromContext(taskId);

        expect(result.length, equals(2));
        expect(result[0].title, equals('Older Task'));
        expect(result[1].title, equals('Newer Task'));
      });
    });

    group('buildLinkedToContext', () {
      test('returns empty list when task has no parent links', () async {
        when(() => mockDb.getLinkedEntities(taskId))
            .thenAnswer((_) async => []);

        final result = await repository.buildLinkedToContext(taskId);

        expect(result, isEmpty);
        verify(() => mockDb.getLinkedEntities(taskId)).called(1);
      });

      test('returns context for parent tasks this task links to', () async {
        final parentTask = createTestTask(
          id: parentTaskId,
          title: 'Parent Epic',
          status: TaskStatus.inProgress(
            id: 'status-parent',
            createdAt: createdDate,
            utcOffset: 0,
          ),
          estimate: const Duration(hours: 40),
        );

        // Create time entry for 12 hours 30 minutes
        final timeEntry = createJournalEntryWithDuration(
          id: 'work-entry',
          duration: const Duration(hours: 12, minutes: 30),
        );

        when(() => mockDb.getLinkedEntities(taskId))
            .thenAnswer((_) async => [parentTask]);
        // Bulk fetch returns entities for time calculation
        when(() => mockDb.getBulkLinkedEntities({parentTaskId}))
            .thenAnswer((_) async => {
                  parentTaskId: [timeEntry]
                });

        final result = await repository.buildLinkedToContext(taskId);

        expect(result.length, equals(1));
        expect(result[0].id, equals(parentTaskId));
        expect(result[0].title, equals('Parent Epic'));
        expect(result[0].estimate, equals('40:00'));
        expect(result[0].timeSpent, equals('12:30'));
      });

      test('filters non-Task entities from results', () async {
        final parentTask = createTestTask(
          id: parentTaskId,
          title: 'Parent Task',
        );
        final journalEntry = JournalEntry(
          meta: Metadata(
            id: 'entry-1',
            dateFrom: createdDate,
            dateTo: createdDate,
            createdAt: createdDate,
            updatedAt: createdDate,
          ),
          entryText: const EntryText(plainText: 'Some entry'),
        );

        when(() => mockDb.getLinkedEntities(taskId))
            .thenAnswer((_) async => [parentTask, journalEntry]);
        when(() => mockDb.getLinkedEntities(parentTaskId))
            .thenAnswer((_) async => []);
        when(() => mockTaskProgressRepository.getTaskProgressData(
              id: parentTaskId,
            )).thenAnswer((_) async => (null, <String, Duration>{}));

        final result = await repository.buildLinkedToContext(taskId);

        expect(result.length, equals(1));
        expect(result[0].id, equals(parentTaskId));
      });
    });

    group('buildLinkedTasksJson', () {
      test('returns JSON with empty arrays when no linked tasks', () async {
        final mockSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockDb.linkedToJournalEntities(taskId))
            .thenReturn(mockSelectable);
        when(mockSelectable.get).thenAnswer((_) async => []);
        when(() => mockDb.getLinkedEntities(taskId))
            .thenAnswer((_) async => []);

        final result = await repository.buildLinkedTasksJson(taskId);
        final parsed = jsonDecode(result) as Map<String, dynamic>;

        expect(parsed['linked_from'], isA<List<dynamic>>());
        expect((parsed['linked_from'] as List<dynamic>).isEmpty, isTrue);
        expect(parsed['linked_to'], isA<List<dynamic>>());
        expect((parsed['linked_to'] as List<dynamic>).isEmpty, isTrue);
        expect(parsed['note'], isNull);
      });

      test('does not include note (note is added by prompt builder)', () async {
        final childTask = createTestTask(
          id: childTaskId,
          title: 'Child Task',
        );
        final childDbEntity = createDbEntityFromTask(childTask);

        final mockSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockDb.linkedToJournalEntities(taskId))
            .thenReturn(mockSelectable);
        when(mockSelectable.get).thenAnswer((_) async => [childDbEntity]);
        when(() => mockDb.getLinkedEntities(taskId))
            .thenAnswer((_) async => []);
        when(() => mockDb.getBulkLinkedEntities({childTaskId}))
            .thenAnswer((_) async => {childTaskId: <JournalEntity>[]});

        final result = await repository.buildLinkedTasksJson(taskId);
        final parsed = jsonDecode(result) as Map<String, dynamic>;

        // Note is intentionally NOT included in repository output
        // The prompt builder is responsible for adding contextual notes
        expect(parsed['note'], isNull);
        expect(parsed['linked_from'], isNotEmpty);
      });

      test('produces valid JSON that can be parsed', () async {
        final childTask = createTestTask(
          id: childTaskId,
          title: 'Child Task',
          labelIds: ['label-1'],
          languageCode: 'de',
        );
        final parentTask = createTestTask(
          id: parentTaskId,
          title: 'Parent Epic',
        );
        final childDbEntity = createDbEntityFromTask(childTask);

        final mockSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockDb.linkedToJournalEntities(taskId))
            .thenReturn(mockSelectable);
        when(mockSelectable.get).thenAnswer((_) async => [childDbEntity]);
        when(() => mockDb.getLinkedEntities(taskId))
            .thenAnswer((_) async => [parentTask]);
        when(() => mockDb.getLinkedEntities(childTaskId))
            .thenAnswer((_) async => []);
        when(() => mockDb.getLinkedEntities(parentTaskId))
            .thenAnswer((_) async => []);
        when(() => mockTaskProgressRepository.getTaskProgressData(
              id: any(named: 'id'),
            )).thenAnswer((_) async => (null, <String, Duration>{}));

        // Use cache service for label lookups
        when(() => mockCacheService.getLabelById('label-1')).thenReturn(
          LabelDefinition(
            id: 'label-1',
            name: 'Test Label',
            color: '#FF0000',
            createdAt: createdDate,
            updatedAt: createdDate,
            vectorClock: null,
            private: false,
          ),
        );

        final result = await repository.buildLinkedTasksJson(taskId);

        expect(() => jsonDecode(result), returnsNormally);

        final parsed = jsonDecode(result) as Map<String, dynamic>;
        expect(parsed['linked_from'], isA<List<dynamic>>());
        expect(parsed['linked_to'], isA<List<dynamic>>());
        expect((parsed['linked_from'] as List<dynamic>).length, equals(1));
        expect((parsed['linked_to'] as List<dynamic>).length, equals(1));
      });
    });

    group('_getLatestTaskSummary', () {
      test('returns null when task has no AI summaries', () async {
        final childTask = createTestTask(
          id: childTaskId,
          title: 'Child Task',
        );
        final childDbEntity = createDbEntityFromTask(childTask);

        final mockSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockDb.linkedToJournalEntities(taskId))
            .thenReturn(mockSelectable);
        when(mockSelectable.get).thenAnswer((_) async => [childDbEntity]);
        when(() => mockDb.getLinkedEntities(childTaskId))
            .thenAnswer((_) async => []);
        when(() =>
                mockTaskProgressRepository.getTaskProgressData(id: childTaskId))
            .thenAnswer((_) async => (null, <String, Duration>{}));

        final result = await repository.buildLinkedFromContext(taskId);

        expect(result.length, equals(1));
        expect(result[0].latestSummary, isNull);
      });

      test('returns latest summary when AI response exists', () async {
        final childTask = createTestTask(
          id: childTaskId,
          title: 'Child Task',
        );
        final childDbEntity = createDbEntityFromTask(childTask);

        final summaryEntry = AiResponseEntry(
          meta: Metadata(
            id: 'summary-1',
            dateFrom: testDate,
            dateTo: testDate,
            createdAt: testDate,
            updatedAt: testDate,
          ),
          data: const AiResponseData(
            model: 'test-model',
            systemMessage: 'system',
            prompt: 'prompt',
            thoughts: 'thoughts',
            response:
                'This is the task summary with\n## Links\n- [PR #123](https://github.com/org/repo/pull/123)',
            type: AiResponseType.taskSummary,
          ),
        );

        final mockSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockDb.linkedToJournalEntities(taskId))
            .thenReturn(mockSelectable);
        when(mockSelectable.get).thenAnswer((_) async => [childDbEntity]);
        // Bulk fetch returns the AI summary entry
        when(() => mockDb.getBulkLinkedEntities({childTaskId}))
            .thenAnswer((_) async => {
                  childTaskId: [summaryEntry]
                });

        final result = await repository.buildLinkedFromContext(taskId);

        expect(result.length, equals(1));
        expect(result[0].latestSummary, isNotNull);
        expect(result[0].latestSummary, contains('task summary'));
        expect(result[0].latestSummary, contains('[PR #123]'));
      });

      test('returns most recent summary when multiple exist', () async {
        final childTask = createTestTask(
          id: childTaskId,
          title: 'Child Task',
        );
        final childDbEntity = createDbEntityFromTask(childTask);

        final olderSummary = AiResponseEntry(
          meta: Metadata(
            id: 'summary-old',
            dateFrom: DateTime(2025, 12, 10),
            dateTo: DateTime(2025, 12, 10),
            createdAt: DateTime(2025, 12, 10),
            updatedAt: DateTime(2025, 12, 10),
          ),
          data: const AiResponseData(
            model: 'test-model',
            systemMessage: 'system',
            prompt: 'prompt',
            thoughts: 'thoughts',
            response: 'Old summary',
            type: AiResponseType.taskSummary,
          ),
        );

        final newerSummary = AiResponseEntry(
          meta: Metadata(
            id: 'summary-new',
            dateFrom: DateTime(2025, 12, 20),
            dateTo: DateTime(2025, 12, 20),
            createdAt: DateTime(2025, 12, 20),
            updatedAt: DateTime(2025, 12, 20),
          ),
          data: const AiResponseData(
            model: 'test-model',
            systemMessage: 'system',
            prompt: 'prompt',
            thoughts: 'thoughts',
            response: 'Newer summary - this is the latest',
            type: AiResponseType.taskSummary,
          ),
        );

        final mockSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockDb.linkedToJournalEntities(taskId))
            .thenReturn(mockSelectable);
        when(mockSelectable.get).thenAnswer((_) async => [childDbEntity]);
        // Return in wrong order to test sorting
        when(() => mockDb.getBulkLinkedEntities({childTaskId}))
            .thenAnswer((_) async => {
                  childTaskId: [olderSummary, newerSummary]
                });

        final result = await repository.buildLinkedFromContext(taskId);

        expect(result.length, equals(1));
        expect(
          result[0].latestSummary,
          equals('Newer summary - this is the latest'),
        );
      });

      test('ignores non-taskSummary AI responses', () async {
        final childTask = createTestTask(
          id: childTaskId,
          title: 'Child Task',
        );
        final childDbEntity = createDbEntityFromTask(childTask);

        final imageAnalysis = AiResponseEntry(
          meta: Metadata(
            id: 'image-analysis',
            dateFrom: testDate,
            dateTo: testDate,
            createdAt: testDate,
            updatedAt: testDate,
          ),
          data: const AiResponseData(
            model: 'test-model',
            systemMessage: 'system',
            prompt: 'prompt',
            thoughts: 'thoughts',
            response: 'This is image analysis, not a summary',
            type: AiResponseType.imageAnalysis,
          ),
        );

        final mockSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockDb.linkedToJournalEntities(taskId))
            .thenReturn(mockSelectable);
        when(mockSelectable.get).thenAnswer((_) async => [childDbEntity]);
        when(() => mockDb.getLinkedEntities(childTaskId))
            .thenAnswer((_) async => [imageAnalysis]);
        when(() =>
                mockTaskProgressRepository.getTaskProgressData(id: childTaskId))
            .thenAnswer((_) async => (null, <String, Duration>{}));

        final result = await repository.buildLinkedFromContext(taskId);

        expect(result.length, equals(1));
        expect(result[0].latestSummary, isNull);
      });
    });

    group('label resolution', () {
      test('resolves label IDs to names', () async {
        final childTask = createTestTask(
          id: childTaskId,
          title: 'Child Task',
          labelIds: ['label-1', 'label-2'],
        );
        final childDbEntity = createDbEntityFromTask(childTask);

        final mockSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockDb.linkedToJournalEntities(taskId))
            .thenReturn(mockSelectable);
        when(mockSelectable.get).thenAnswer((_) async => [childDbEntity]);
        when(() => mockDb.getLinkedEntities(childTaskId))
            .thenAnswer((_) async => []);
        when(() =>
                mockTaskProgressRepository.getTaskProgressData(id: childTaskId))
            .thenAnswer((_) async => (null, <String, Duration>{}));

        // Use cache service for label lookups (O(1) per label)
        when(() => mockCacheService.getLabelById('label-1')).thenReturn(
          LabelDefinition(
            id: 'label-1',
            name: 'Frontend',
            color: '#FF0000',
            createdAt: createdDate,
            updatedAt: createdDate,
            vectorClock: null,
            private: false,
          ),
        );
        when(() => mockCacheService.getLabelById('label-2')).thenReturn(
          LabelDefinition(
            id: 'label-2',
            name: 'Bug',
            color: '#00FF00',
            createdAt: createdDate,
            updatedAt: createdDate,
            vectorClock: null,
            private: false,
          ),
        );

        final result = await repository.buildLinkedFromContext(taskId);

        expect(result.length, equals(1));
        expect(result[0].labels.length, equals(2));
        final labelNames = result[0].labels.map((l) => l['name']).toSet();
        expect(labelNames, contains('Frontend'));
        expect(labelNames, contains('Bug'));
      });

      test('returns empty labels list when task has no labels', () async {
        final childTask = createTestTask(
          id: childTaskId,
          title: 'Child Task',
        );
        final childDbEntity = createDbEntityFromTask(childTask);

        final mockSelectable = MockSelectable<JournalDbEntity>();
        when(() => mockDb.linkedToJournalEntities(taskId))
            .thenReturn(mockSelectable);
        when(mockSelectable.get).thenAnswer((_) async => [childDbEntity]);
        when(() => mockDb.getLinkedEntities(childTaskId))
            .thenAnswer((_) async => []);
        when(() =>
                mockTaskProgressRepository.getTaskProgressData(id: childTaskId))
            .thenAnswer((_) async => (null, <String, Duration>{}));

        final result = await repository.buildLinkedFromContext(taskId);

        expect(result.length, equals(1));
        expect(result[0].labels, isEmpty);
      });
    });
  });
}
