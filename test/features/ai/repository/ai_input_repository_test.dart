// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
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
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

// Mock for TaskProgressRepository
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

// Mock for PersistenceLogic
class MockPersistenceLogic extends Mock implements PersistenceLogic {}

// Mock classes for parameters
class FakeId extends Mock {
  FakeId(this.value);
  final String value;
}

// Create real implementations rather than mocks that can cause test issues
class TestTaskProgressState implements TaskProgressState {
  TestTaskProgressState(this._progress, {Duration? estimate})
      : _estimate = estimate ?? Duration.zero;
  final Duration _progress;
  final Duration _estimate;

  @override
  Duration get progress => _progress;

  @override
  Duration get estimate => _estimate;

  // Skip implementation of copyWith since we don't use it in tests
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #copyWith) {
      return null;
    }
    return super.noSuchMethod(invocation);
  }

  @override
  String toString() =>
      'TestTaskProgressState(progress: $_progress, estimate: $_estimate)';
}

// ignore: subtype_of_sealed_class
class TestAsyncValue<T> implements AsyncValue<T> {
  TestAsyncValue(this._value);
  final T? _value;

  @override
  bool get hasValue => _value != null;

  @override
  T get value => _value as T;

  @override
  String toString() => 'TestAsyncValue<$T>(value: $_value)';

  // We only need to implement the properties used by the repository
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestRef implements Ref {
  TestRef(this._mockTaskProgressRepository) {
    // Add the mock repository to the values map
    _values[taskProgressRepositoryProvider] = _mockTaskProgressRepository;
  }
  final Map<ProviderListenable<Object?>, Object> _values = {};
  // Add a mock for the taskProgressRepositoryProvider
  final TaskProgressRepository _mockTaskProgressRepository;

  void setTaskProgress(String taskId, Duration? progress) {
    final provider = taskProgressControllerProvider(id: taskId);

    final progressState =
        progress != null ? TestTaskProgressState(progress) : null;

    _values[provider] = TestAsyncValue<TaskProgressState?>(progressState);
  }

  @override
  T read<T>(ProviderListenable<T> provider) {
    if (_values.containsKey(provider)) {
      return _values[provider] as T;
    }
    throw UnimplementedError('Provider not found: $provider');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const taskId = 'task-123';
  final creationDate = DateTime(2023);

  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(FakeId(taskId));
    registerFallbackValue(<String, Duration>{});
    registerFallbackValue(Duration.zero);
    registerFallbackValue(
      const AiResponseData(
        model: 'test-model',
        systemMessage: 'test-system-message',
        prompt: 'test-prompt',
        thoughts: 'test-thoughts',
        response: 'test-response',
      ),
    );
    registerFallbackValue(DateTime.now());
  });

  group('AiInputRepository', () {
    late MockJournalDb mockDb;
    late MockTaskProgressRepository mockTaskProgressRepository;
    late MockPersistenceLogic mockPersistenceLogic;
    late TestRef testRef;
    late AiInputRepository repository;

    setUp(() {
      mockDb = MockJournalDb();
      mockTaskProgressRepository = MockTaskProgressRepository();
      mockPersistenceLogic = MockPersistenceLogic();
      testRef = TestRef(mockTaskProgressRepository);

      // Register function for service locator
      getIt
        ..registerSingleton<JournalDb>(mockDb)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

      repository = AiInputRepository(testRef);

      // Set initial value to null
      testRef.setTaskProgress(taskId, null);

      // Set default mock for taskProgressRepository if not overridden in tests
      when(
        () => mockTaskProgressRepository.getTaskProgressData(
          id: any(named: 'id'),
        ),
      ).thenAnswer((_) async => (null, <String, Duration>{}));
    });

    tearDown(() {
      getIt
        ..unregister<JournalDb>()
        ..unregister<PersistenceLogic>();
    });

    test('generate returns null when entity is not a Task', () async {
      // Arrange
      when(() => mockDb.journalEntityById(taskId)).thenAnswer(
        (_) async => JournalEntity.journalEntry(
          meta: Metadata(
            id: taskId,
            dateFrom: creationDate,
            dateTo: creationDate,
            createdAt: creationDate,
            updatedAt: creationDate,
          ),
          entryText: const EntryText(plainText: ''),
        ),
      );

      // Act
      final result = await repository.generate(taskId);

      // Assert
      expect(result, isNull);
      verify(() => mockDb.journalEntityById(taskId)).called(1);
    });

    test('generate returns AiInputTaskObject with correct data for a Task',
        () async {
      // Arrange
      const taskTitle = 'Test Task';
      const checklistId = 'checklist-123';
      const checklistItemId = 'checklist-item-123';
      const linkedEntryId = 'linked-entry-123';
      const statusId = 'status-123';

      // Set up specific mock for the task progress repository for this test
      when(() => mockTaskProgressRepository.getTaskProgressData(id: taskId))
          .thenAnswer(
        (_) async => (
          const Duration(minutes: 60), // estimate
          {'entry1': const Duration(minutes: 45)}, // durations
        ),
      );

      // Mock the task
      final task = JournalEntity.task(
        meta: Metadata(
          id: taskId,
          dateFrom: creationDate,
          dateTo: creationDate,
          createdAt: creationDate,
          updatedAt: creationDate,
        ),
        data: TaskData(
          title: taskTitle,
          status: TaskStatus.started(
            id: statusId,
            createdAt: creationDate,
            utcOffset: 0,
          ),
          statusHistory: [],
          dateFrom: creationDate,
          dateTo: creationDate,
          checklistIds: [checklistId],
          estimate: const Duration(minutes: 60),
        ),
      );

      // Mock the checklist
      final checklist = JournalEntity.checklist(
        meta: Metadata(
          id: checklistId,
          dateFrom: creationDate,
          dateTo: creationDate,
          createdAt: creationDate,
          updatedAt: creationDate,
        ),
        data: const ChecklistData(
          title: 'Test Checklist',
          linkedChecklistItems: [checklistItemId],
          linkedTasks: [taskId],
        ),
      );

      // Mock the checklist item
      final checklistItem = JournalEntity.checklistItem(
        meta: Metadata(
          id: checklistItemId,
          dateFrom: creationDate,
          dateTo: creationDate,
          createdAt: creationDate,
          updatedAt: creationDate,
        ),
        data: const ChecklistItemData(
          title: 'Test Checklist Item',
          isChecked: true,
          linkedChecklists: [checklistId],
        ),
      );

      // Mock the linked entry
      final linkedEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: linkedEntryId,
          dateFrom: creationDate,
          dateTo: creationDate.add(const Duration(minutes: 30)),
          createdAt: creationDate,
          updatedAt: creationDate,
        ),
        entryText: const EntryText(plainText: 'Test Journal Entry'),
      );

      // Set up mocks
      when(() => mockDb.journalEntityById(taskId))
          .thenAnswer((_) async => task);
      when(() => mockDb.getLinkedEntities(taskId))
          .thenAnswer((_) async => [linkedEntry]);
      when(() => mockDb.journalEntityById(checklistId))
          .thenAnswer((_) async => checklist);
      when(() => mockDb.journalEntityById(checklistItemId))
          .thenAnswer((_) async => checklistItem);

      // Set task progress
      testRef.setTaskProgress(taskId, const Duration(minutes: 45));

      // Act
      final result = await repository.generate(taskId);

      // Assert
      expect(result, isNotNull);
      expect(result!.title, equals(taskTitle));
      expect(result.status, equals('STARTED'));
      expect(result.creationDate, isNotNull);
      expect(result.estimatedDuration, equals('01:00'));
      expect(result.timeSpent, equals('00:45'));

      // Check action items
      expect(result.actionItems.length, 1);
      expect(result.actionItems[0].title, 'Test Checklist Item');
      expect(result.actionItems[0].completed, true);

      // Check log entries
      expect(result.logEntries.length, 1);
      expect(result.logEntries[0].text, 'Test Journal Entry');
      expect(result.logEntries[0].creationTimestamp, equals(creationDate));
      expect(result.logEntries[0].loggedDuration, equals('00:30'));

      // Verify calls
      verify(() => mockDb.journalEntityById(taskId)).called(1);
      verify(() => mockDb.getLinkedEntities(taskId)).called(1);
      verify(() => mockDb.journalEntityById(checklistId)).called(1);
      verify(() => mockDb.journalEntityById(checklistItemId)).called(1);
    });

    test('generate handles null checklist items and time properly', () async {
      // Arrange
      const taskTitle = 'Test Task';
      const statusId = 'status-123';

      // Set up specific mock for the task progress repository for this test
      when(() => mockTaskProgressRepository.getTaskProgressData(id: taskId))
          .thenAnswer(
        (_) async => (
          null, // null estimate
          <String, Duration>{}, // empty durations
        ),
      );

      // Mock the task with no checklist ids and no estimate
      final task = JournalEntity.task(
        meta: Metadata(
          id: taskId,
          dateFrom: creationDate,
          dateTo: creationDate,
          createdAt: creationDate,
          updatedAt: creationDate,
        ),
        data: TaskData(
          title: taskTitle,
          status: TaskStatus.open(
            id: statusId,
            createdAt: creationDate,
            utcOffset: 0,
          ),
          dateFrom: creationDate,
          dateTo: creationDate,
          statusHistory: [],
        ),
      );

      // Set up mocks
      when(() => mockDb.journalEntityById(taskId))
          .thenAnswer((_) async => task);
      when(() => mockDb.getLinkedEntities(taskId)).thenAnswer((_) async => []);

      // Don't set any progress to keep the default null

      // Act
      final result = await repository.generate(taskId);

      // Assert
      expect(result, isNotNull);
      expect(result!.title, equals(taskTitle));
      expect(result.status, equals('OPEN'));
      expect(result.estimatedDuration, equals('00:00'));
      expect(result.timeSpent, equals('00:00'));
      expect(result.actionItems, isEmpty);
      expect(result.logEntries, isEmpty);

      // Verify calls
      verify(() => mockDb.journalEntityById(taskId)).called(1);
      verify(() => mockDb.getLinkedEntities(taskId)).called(1);
    });

    test('generate processes different types of linked entities correctly',
        () async {
      // Arrange
      const taskTitle = 'Test Task';
      const entryId = 'entry-123';
      const imageId = 'image-123';
      const audioId = 'audio-123';
      const statusId = 'status-123';

      // Set up specific mock for the task progress repository for this test
      when(() => mockTaskProgressRepository.getTaskProgressData(id: taskId))
          .thenAnswer(
        (_) async => (
          const Duration(minutes: 30), // estimate
          {
            'entry-123': const Duration(minutes: 15),
            'image-123': const Duration(minutes: 30),
            'audio-123': const Duration(minutes: 45),
          }, // durations
        ),
      );

      // Mock the task
      final task = JournalEntity.task(
        meta: Metadata(
          id: taskId,
          dateFrom: creationDate,
          dateTo: creationDate,
          createdAt: creationDate,
          updatedAt: creationDate,
        ),
        data: TaskData(
          title: taskTitle,
          status: TaskStatus.inProgress(
            id: statusId,
            createdAt: creationDate,
            utcOffset: 0,
          ),
          dateFrom: creationDate,
          dateTo: creationDate,
          statusHistory: [],
          checklistIds: [],
        ),
      );

      // Mock different types of linked entities
      final journalEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: entryId,
          dateFrom: creationDate,
          dateTo: creationDate.add(const Duration(minutes: 15)),
          createdAt: creationDate,
          updatedAt: creationDate,
        ),
        entryText: const EntryText(plainText: 'Journal Entry Text'),
      );

      final journalImage = JournalEntity.journalImage(
        meta: Metadata(
          id: imageId,
          dateFrom: creationDate,
          dateTo: creationDate.add(const Duration(minutes: 30)),
          createdAt: creationDate,
          updatedAt: creationDate,
        ),
        data: ImageData(
          capturedAt: creationDate,
          imageId: 'img-1',
          imageFile: 'test.jpg',
          imageDirectory: '/test',
        ),
        entryText: const EntryText(plainText: 'Image Caption'),
      );

      final journalAudio = JournalEntity.journalAudio(
        meta: Metadata(
          id: audioId,
          dateFrom: creationDate,
          dateTo: creationDate.add(const Duration(minutes: 45)),
          createdAt: creationDate,
          updatedAt: creationDate,
        ),
        data: AudioData(
          dateFrom: creationDate,
          dateTo: creationDate.add(const Duration(minutes: 45)),
          audioFile: 'test.mp3',
          audioDirectory: '/test',
          duration: const Duration(minutes: 45),
        ),
        entryText: const EntryText(plainText: 'Audio Transcription'),
      );

      // Set up mocks
      when(() => mockDb.journalEntityById(taskId))
          .thenAnswer((_) async => task);
      when(() => mockDb.getLinkedEntities(taskId))
          .thenAnswer((_) async => [journalEntry, journalImage, journalAudio]);

      // Act
      final result = await repository.generate(taskId);

      // Assert
      expect(result, isNotNull);
      expect(result!.logEntries.length, 3);

      // Verify the journal entry
      expect(result.logEntries[0].text, 'Journal Entry Text');
      expect(result.logEntries[0].loggedDuration, '00:15');

      // Verify the image entry
      expect(result.logEntries[1].text, 'Image Caption');
      expect(result.logEntries[1].loggedDuration, '00:30');

      // Verify the audio entry
      expect(result.logEntries[2].text, 'Audio Transcription');
      expect(result.logEntries[2].loggedDuration, '00:45');
    });

    // Tests for getEntity method
    group('getEntity', () {
      test('returns entity when entity exists', () async {
        // Arrange
        final expectedEntity = JournalEntity.task(
          meta: Metadata(
            id: taskId,
            dateFrom: creationDate,
            dateTo: creationDate,
            createdAt: creationDate,
            updatedAt: creationDate,
          ),
          data: TaskData(
            title: 'Test Task',
            status: TaskStatus.open(
              id: 'status-123',
              createdAt: creationDate,
              utcOffset: 0,
            ),
            dateFrom: creationDate,
            dateTo: creationDate,
            statusHistory: [],
          ),
        );

        when(() => mockDb.journalEntityById(taskId))
            .thenAnswer((_) async => expectedEntity);

        // Act
        final result = await repository.getEntity(taskId);

        // Assert
        expect(result, equals(expectedEntity));
        verify(() => mockDb.journalEntityById(taskId)).called(1);
      });

      test('returns null when entity does not exist', () async {
        // Arrange
        when(() => mockDb.journalEntityById(taskId))
            .thenAnswer((_) async => null);

        // Act
        final result = await repository.getEntity(taskId);

        // Assert
        expect(result, isNull);
        verify(() => mockDb.journalEntityById(taskId)).called(1);
      });
    });

    // Tests for createAiResponseEntry method
    group('createAiResponseEntry', () {
      test(
          'calls PersistenceLogic.createAiResponseEntry with correct parameters',
          () async {
        // Arrange
        const testData = AiResponseData(
          model: 'test-model',
          systemMessage: 'test-system-message',
          prompt: 'test-prompt',
          thoughts: 'test-thoughts',
          response: 'test-response',
        );

        final testStart = DateTime(2023);
        const testLinkedId = 'linked-123';
        const testCategoryId = 'category-123';

        when(
          () => mockPersistenceLogic.createAiResponseEntry(
            data: any(named: 'data'),
            dateFrom: any(named: 'dateFrom'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);

        // Act
        await repository.createAiResponseEntry(
          data: testData,
          start: testStart,
          linkedId: testLinkedId,
          categoryId: testCategoryId,
        );

        // Assert
        verify(
          () => mockPersistenceLogic.createAiResponseEntry(
            data: testData,
            dateFrom: testStart,
            linkedId: testLinkedId,
            categoryId: testCategoryId,
          ),
        ).called(1);
      });

      test('handles optional parameters correctly', () async {
        // Arrange
        const testData = AiResponseData(
          model: 'test-model',
          systemMessage: 'test-system-message',
          prompt: 'test-prompt',
          thoughts: 'test-thoughts',
          response: 'test-response',
        );

        final testStart = DateTime(2023);

        when(
          () => mockPersistenceLogic.createAiResponseEntry(
            data: any(named: 'data'),
            dateFrom: any(named: 'dateFrom'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);

        // Act - omit optional parameters
        await repository.createAiResponseEntry(
          data: testData,
          start: testStart,
        );

        // Assert
        verify(
          () => mockPersistenceLogic.createAiResponseEntry(
            data: testData,
            dateFrom: testStart,
          ),
        ).called(1);
      });

      test('handles response with suggested action items', () async {
        // Arrange
        const testData = AiResponseData(
          model: 'test-model',
          systemMessage: 'test-system-message',
          prompt: 'test-prompt',
          thoughts: 'test-thoughts',
          response: 'test-response',
          suggestedActionItems: [
            AiActionItem(title: 'Action 1', completed: false),
            AiActionItem(title: 'Action 2', completed: true),
          ],
          type: AiResponseType.actionItemSuggestions,
        );

        final testStart = DateTime(2023);

        when(
          () => mockPersistenceLogic.createAiResponseEntry(
            data: any(named: 'data'),
            dateFrom: any(named: 'dateFrom'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).thenAnswer((_) async => null);

        // Act
        await repository.createAiResponseEntry(
          data: testData,
          start: testStart,
        );

        // Assert
        verify(
          () => mockPersistenceLogic.createAiResponseEntry(
            data: testData,
            dateFrom: testStart,
          ),
        ).called(1);
      });
    });

    // Tests for buildTaskDetailsJson method
    group('buildTaskDetailsJson', () {
      test('returns JSON string for valid task', () async {
        // Arrange
        const taskTitle = 'Test Task';
        const statusId = 'status-123';

        // Set up specific mock for the task progress repository
        when(() => mockTaskProgressRepository.getTaskProgressData(id: taskId))
            .thenAnswer(
          (_) async => (
            const Duration(minutes: 30), // estimate
            {'entry1': const Duration(minutes: 15)}, // durations
          ),
        );

        // Mock the task
        final task = JournalEntity.task(
          meta: Metadata(
            id: taskId,
            dateFrom: creationDate,
            dateTo: creationDate,
            createdAt: creationDate,
            updatedAt: creationDate,
          ),
          data: TaskData(
            title: taskTitle,
            status: TaskStatus.started(
              id: statusId,
              createdAt: creationDate,
              utcOffset: 0,
            ),
            statusHistory: [],
            dateFrom: creationDate,
            dateTo: creationDate,
            estimate: const Duration(minutes: 30),
          ),
        );

        // Set up mocks
        when(() => mockDb.journalEntityById(taskId))
            .thenAnswer((_) async => task);
        when(() => mockDb.getLinkedEntities(taskId))
            .thenAnswer((_) async => []);

        // Act
        final result = await repository.buildTaskDetailsJson(id: taskId);

        // Assert
        expect(result, isNotNull);
        expect(result, contains('"title": "Test Task"'));
        expect(result, contains('"status": "STARTED"'));
        expect(result, contains('"estimatedDuration": "00:30"'));
        expect(result, contains('"timeSpent": "00:15"'));
        expect(result, contains('"actionItems": []'));
        expect(result, contains('"logEntries": []'));

        // Verify the JSON is properly formatted
        expect(() => jsonDecode(result!), returnsNormally);
      });

      test('returns null for non-task entity', () async {
        // Arrange
        when(() => mockDb.journalEntityById(taskId)).thenAnswer(
          (_) async => JournalEntity.journalEntry(
            meta: Metadata(
              id: taskId,
              dateFrom: creationDate,
              dateTo: creationDate,
              createdAt: creationDate,
              updatedAt: creationDate,
            ),
            entryText: const EntryText(plainText: 'Not a task'),
          ),
        );

        // Act
        final result = await repository.buildTaskDetailsJson(id: taskId);

        // Assert
        expect(result, isNull);
      });

      test('returns null for non-existent entity', () async {
        // Arrange
        when(() => mockDb.journalEntityById(taskId))
            .thenAnswer((_) async => null);

        // Act
        final result = await repository.buildTaskDetailsJson(id: taskId);

        // Assert
        expect(result, isNull);
      });

      test('includes action items and log entries in JSON', () async {
        // Arrange
        const taskTitle = 'Test Task';
        const checklistId = 'checklist-123';
        const checklistItemId = 'checklist-item-123';
        const linkedEntryId = 'linked-entry-123';
        const statusId = 'status-123';

        // Set up specific mock for the task progress repository
        when(() => mockTaskProgressRepository.getTaskProgressData(id: taskId))
            .thenAnswer(
          (_) async => (
            const Duration(minutes: 60), // estimate
            {'entry1': const Duration(minutes: 45)}, // durations
          ),
        );

        // Mock the task
        final task = JournalEntity.task(
          meta: Metadata(
            id: taskId,
            dateFrom: creationDate,
            dateTo: creationDate,
            createdAt: creationDate,
            updatedAt: creationDate,
          ),
          data: TaskData(
            title: taskTitle,
            status: TaskStatus.inProgress(
              id: statusId,
              createdAt: creationDate,
              utcOffset: 0,
            ),
            statusHistory: [],
            dateFrom: creationDate,
            dateTo: creationDate,
            checklistIds: [checklistId],
            estimate: const Duration(minutes: 60),
          ),
        );

        // Mock the checklist
        final checklist = JournalEntity.checklist(
          meta: Metadata(
            id: checklistId,
            dateFrom: creationDate,
            dateTo: creationDate,
            createdAt: creationDate,
            updatedAt: creationDate,
          ),
          data: const ChecklistData(
            title: 'Test Checklist',
            linkedChecklistItems: [checklistItemId],
            linkedTasks: [taskId],
          ),
        );

        // Mock the checklist item
        final checklistItem = JournalEntity.checklistItem(
          meta: Metadata(
            id: checklistItemId,
            dateFrom: creationDate,
            dateTo: creationDate,
            createdAt: creationDate,
            updatedAt: creationDate,
          ),
          data: const ChecklistItemData(
            title: 'Test Checklist Item',
            isChecked: true,
            linkedChecklists: [checklistId],
          ),
        );

        // Mock the linked entry
        final linkedEntry = JournalEntity.journalEntry(
          meta: Metadata(
            id: linkedEntryId,
            dateFrom: creationDate,
            dateTo: creationDate.add(const Duration(minutes: 30)),
            createdAt: creationDate,
            updatedAt: creationDate,
          ),
          entryText: const EntryText(plainText: 'Test Journal Entry'),
        );

        // Set up mocks
        when(() => mockDb.journalEntityById(taskId))
            .thenAnswer((_) async => task);
        when(() => mockDb.getLinkedEntities(taskId))
            .thenAnswer((_) async => [linkedEntry]);
        when(() => mockDb.journalEntityById(checklistId))
            .thenAnswer((_) async => checklist);
        when(() => mockDb.journalEntityById(checklistItemId))
            .thenAnswer((_) async => checklistItem);

        // Act
        final result = await repository.buildTaskDetailsJson(id: taskId);

        // Assert
        expect(result, isNotNull);

        // Parse JSON to verify structure
        final jsonData = jsonDecode(result!) as Map<String, dynamic>;
        expect(jsonData['title'], equals('Test Task'));
        expect(jsonData['status'], equals('IN PROGRESS'));
        expect(jsonData['estimatedDuration'], equals('01:00'));
        expect(jsonData['timeSpent'], equals('00:45'));

        // Check action items
        expect(jsonData['actionItems'], isList);
        expect(jsonData['actionItems'].length, equals(1));
        expect(
            jsonData['actionItems'][0]['title'], equals('Test Checklist Item'));
        expect(jsonData['actionItems'][0]['completed'], isTrue);

        // Check log entries
        expect(jsonData['logEntries'], isList);
        expect(jsonData['logEntries'].length, equals(1));
        expect(jsonData['logEntries'][0]['text'], equals('Test Journal Entry'));
        expect(jsonData['logEntries'][0]['loggedDuration'], equals('00:30'));
      });
    });
  });
}
