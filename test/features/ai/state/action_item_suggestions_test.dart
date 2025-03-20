// ignore_for_file: inference_failure_on_function_invocation

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/ollama_repository.dart';
import 'package:lotti/features/ai/state/action_item_suggestions.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ollama/ollama.dart';

class MockAiInputRepository extends Mock implements AiInputRepository {}

class MockOllamaRepository extends Mock implements OllamaRepository {}

class MockLoggingService extends Mock implements LoggingService {}

class MockJournalDb extends Mock implements JournalDb {}

class Listener<T> extends Mock {
  void call(T? previous, T next);
}

void main() {
  late ProviderContainer container;
  late MockAiInputRepository mockAiInputRepository;
  late MockOllamaRepository mockOllamaRepository;
  late MockLoggingService mockLoggingService;
  late MockJournalDb mockJournalDb;
  late Listener<String> listener;

  const taskId = 'test-task-id';
  final creationDate = DateTime(2023);

  setUpAll(() {
    registerFallbackValue(
      const AiResponseData(
        model: 'test-model',
        temperature: 0.5,
        systemMessage: 'test-system-message',
        prompt: 'test-prompt',
        thoughts: 'test-thoughts',
        response: 'test-response',
        type: 'ActionItemSuggestions',
      ),
    );
    registerFallbackValue(DateTime.now());
  });

  setUp(() {
    mockAiInputRepository = MockAiInputRepository();
    mockOllamaRepository = MockOllamaRepository();
    mockLoggingService = MockLoggingService();
    mockJournalDb = MockJournalDb();
    listener = Listener<String>();

    // Register the MockLoggingService with GetIt
    getIt
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<JournalDb>(mockJournalDb);

    // Setup mock behavior to avoid errors
    when(
      () => mockLoggingService.captureEvent(
        any(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);

    when(
      () => mockLoggingService.captureException(
        any(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ).thenReturn(null);

    // Mock JournalDb.getConfigFlag to return false for useCloudInferenceFlag
    when(() => mockJournalDb.getConfigFlag(useCloudInferenceFlag))
        .thenAnswer((_) async => false);

    container = ProviderContainer(
      overrides: [
        aiInputRepositoryProvider.overrideWithValue(mockAiInputRepository),
        ollamaRepositoryProvider.overrideWithValue(mockOllamaRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    // Unregister the mocks from GetIt to clean up
    getIt
      ..unregister<LoggingService>()
      ..unregister<JournalDb>();
  });

  group('ActionItemSuggestionsController', () {
    test(
        'build calls getActionItemSuggestion and returns empty string initially',
        () async {
      // Arrange
      final mockTask = JournalEntity.task(
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
          statusHistory: [],
          dateFrom: creationDate,
          dateTo: creationDate,
        ),
      );

      final mockAiInput = AiInputTaskObject(
        title: 'Test Task',
        status: 'OPEN',
        creationDate: creationDate,
        actionItems: [],
        logEntries: [],
        estimatedDuration: '00:00',
        timeSpent: '00:00',
      );

      // Return a task when getEntity is called
      when(() => mockAiInputRepository.getEntity(taskId))
          .thenAnswer((_) async => mockTask);

      // Return AI input when generate is called
      when(() => mockAiInputRepository.generate(taskId))
          .thenAnswer((_) async => mockAiInput);

      // Set up mockOllamaRepository to return a stream of chunks
      final mockStream = Stream.fromIterable([
        CompletionChunk(
          text: 'Thinking about suggestions</think>',
          model: 'deepseek-r1:14b',
          createdAt: DateTime.now(),
        ),
        CompletionChunk(
          text: '''
```json
[
  {
    "title": "Create documentation",
    "completed": false
  },
  {
    "title": "Schedule review meeting",
    "completed": false
  }
]
```''',
          model: 'deepseek-r1:14b',
          createdAt: DateTime.now(),
        ),
      ]);

      when(
        () => mockOllamaRepository.generate(
          any(),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          system: any(named: 'system'),
          images: any(named: 'images'),
        ),
      ).thenAnswer((_) => mockStream);

      // Mock the createAiResponseEntry method to complete successfully
      when(
        () => mockAiInputRepository.createAiResponseEntry(
          data: any(named: 'data'),
          start: any(named: 'start'),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async {});

      // Act
      container.listen(
        actionItemSuggestionsControllerProvider(id: taskId),
        (previous, next) => listener(previous, next),
        fireImmediately: true,
      );

      // Allow the async operations to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Assert
      verify(() => mockAiInputRepository.getEntity(taskId)).called(1);
      verify(() => mockAiInputRepository.generate(taskId)).called(1);
      verify(
        () => mockOllamaRepository.generate(
          any(),
          model: 'deepseek-r1:14b',
          temperature: 0.6,
        ),
      ).called(1);

      final finalState =
          container.read(actionItemSuggestionsControllerProvider(id: taskId));
      expect(
        finalState,
        'Thinking about suggestions</think>```json\n[\n  {\n    "title": "Create documentation",\n    "completed": false\n  },\n  {\n    "title": "Schedule review meeting",\n    "completed": false\n  }\n]\n```',
      );

      verify(
        () => mockAiInputRepository.createAiResponseEntry(
          data: any(named: 'data'),
          start: any(named: 'start'),
          linkedId: taskId,
          categoryId: any(named: 'categoryId'),
        ),
      ).called(1);
    });

    test('getActionItemSuggestion returns early when entity is not a Task',
        () async {
      // Arrange
      final mockJournalEntry = JournalEntity.journalEntry(
        meta: Metadata(
          id: taskId,
          dateFrom: creationDate,
          dateTo: creationDate,
          createdAt: creationDate,
          updatedAt: creationDate,
        ),
      );

      // Return a non-Task entity when getEntity is called
      when(() => mockAiInputRepository.getEntity(taskId))
          .thenAnswer((_) async => mockJournalEntry);

      // Act
      container.listen(
        actionItemSuggestionsControllerProvider(id: taskId),
        (previous, next) => listener(previous, next),
        fireImmediately: true,
      );

      // Allow the async operations to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Assert
      verify(() => mockAiInputRepository.getEntity(taskId)).called(1);
      verifyNever(() => mockAiInputRepository.generate(taskId));
      verifyNever(
        () => mockOllamaRepository.generate(
          any(),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
        ),
      );

      // State should remain an empty string
      final finalState =
          container.read(actionItemSuggestionsControllerProvider(id: taskId));
      expect(finalState, '');
    });

    test('correctly parses JSON response with action items', () async {
      // Arrange
      final mockTask = JournalEntity.task(
        meta: Metadata(
          id: taskId,
          dateFrom: creationDate,
          dateTo: creationDate,
          createdAt: creationDate,
          updatedAt: creationDate,
        ),
        data: TaskData(
          title: 'Test Task',
          status: TaskStatus.inProgress(
            id: 'status-123',
            createdAt: creationDate,
            utcOffset: 0,
          ),
          statusHistory: [],
          dateFrom: creationDate,
          dateTo: creationDate,
        ),
      );

      final mockAiInput = AiInputTaskObject(
        title: 'Test Task',
        status: 'IN PROGRESS',
        creationDate: creationDate,
        actionItems: [
          const AiActionItem(title: 'Existing Item', completed: true),
        ],
        logEntries: [
          AiInputLogEntryObject(
            creationTimestamp: creationDate,
            loggedDuration: '01:30',
            text:
                'Worked on task implementation. Need to write tests and update documentation.',
          ),
        ],
        estimatedDuration: '02:00',
        timeSpent: '01:30',
      );

      // Return a task when getEntity is called
      when(() => mockAiInputRepository.getEntity(taskId))
          .thenAnswer((_) async => mockTask);

      // Return AI input when generate is called
      when(() => mockAiInputRepository.generate(taskId))
          .thenAnswer((_) async => mockAiInput);

      // Create a response with JSON action items
      const thoughts = 'I see several potential action items in the logs.';
      const jsonResponse = '''
```json
[
  {
    "title": "Write tests",
    "completed": false
  },
  {
    "title": "Update documentation",
    "completed": false
  }
]
```''';

      // Set up mockOllamaRepository to return a stream of chunks
      final mockStream = Stream.fromIterable([
        CompletionChunk(
          text: thoughts,
          model: 'deepseek-r1:14b',
          createdAt: DateTime.now(),
        ),
        CompletionChunk(
          text: '</think>',
          model: 'deepseek-r1:14b',
          createdAt: DateTime.now(),
        ),
        CompletionChunk(
          text: jsonResponse,
          model: 'deepseek-r1:14b',
          createdAt: DateTime.now(),
        ),
      ]);

      when(
        () => mockOllamaRepository.generate(
          any(),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          system: any(named: 'system'),
          images: any(named: 'images'),
        ),
      ).thenAnswer((_) => mockStream);

      // Set up a capture for the AiResponseData
      AiResponseData? capturedData;
      when(
        () => mockAiInputRepository.createAiResponseEntry(
          data: any(named: 'data'),
          start: any(named: 'start'),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((invocation) {
        capturedData =
            invocation.namedArguments[const Symbol('data')] as AiResponseData;
        return Future<void>.value();
      });

      // Act
      container.listen(
        actionItemSuggestionsControllerProvider(id: taskId),
        (previous, next) => listener(previous, next),
        fireImmediately: true,
      );

      // Allow the async operations to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Assert - verify createAiResponseEntry was called
      verify(
        () => mockAiInputRepository.createAiResponseEntry(
          data: any(named: 'data'),
          start: any(named: 'start'),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      ).called(1);

      // Check the captured data
      expect(capturedData, isNotNull);
      expect(capturedData?.suggestedActionItems, isNotNull);
      expect(capturedData?.suggestedActionItems, hasLength(2));
      expect(capturedData?.suggestedActionItems?[0].title, 'Write tests');
      expect(capturedData?.suggestedActionItems?[0].completed, false);
      expect(
        capturedData?.suggestedActionItems?[1].title,
        'Update documentation',
      );
      expect(capturedData?.suggestedActionItems?[1].completed, false);
    });

    test('properly formats the prompt with JSON task data', () async {
      // Arrange
      final mockTask = JournalEntity.task(
        meta: Metadata(
          id: taskId,
          dateFrom: creationDate,
          dateTo: creationDate,
          createdAt: creationDate,
          updatedAt: creationDate,
        ),
        data: TaskData(
          title: 'Test Task',
          status: TaskStatus.inProgress(
            id: 'status-123',
            createdAt: creationDate,
            utcOffset: 0,
          ),
          statusHistory: [],
          dateFrom: creationDate,
          dateTo: creationDate,
        ),
      );

      final mockAiInput = AiInputTaskObject(
        title: 'Test Task',
        status: 'IN PROGRESS',
        creationDate: creationDate,
        actionItems: [],
        logEntries: [],
        estimatedDuration: '00:00',
        timeSpent: '00:00',
      );

      // Calculate the expected JSON string
      const encoder = JsonEncoder.withIndent('    ');
      final expectedJsonString = encoder.convert(mockAiInput);

      // Return a task when getEntity is called
      when(() => mockAiInputRepository.getEntity(taskId))
          .thenAnswer((_) async => mockTask);

      // Return AI input when generate is called
      when(() => mockAiInputRepository.generate(taskId))
          .thenAnswer((_) async => mockAiInput);

      // Set up mockOllamaRepository to return a simple stream
      final mockStream = Stream.fromIterable([
        CompletionChunk(
          text: 'Thoughts</think>[]',
          model: 'deepseek-r1:14b',
          createdAt: DateTime.now(),
        ),
      ]);

      when(
        () => mockOllamaRepository.generate(
          any(),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          system: any(named: 'system'),
          images: any(named: 'images'),
        ),
      ).thenAnswer((_) => mockStream);

      // Mock the createAiResponseEntry method to complete successfully
      when(
        () => mockAiInputRepository.createAiResponseEntry(
          data: any(named: 'data'),
          start: any(named: 'start'),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async {});

      // Act
      container.read(actionItemSuggestionsControllerProvider(id: taskId));

      // Allow the async operations to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Assert - verify that the expected prompt was sent to the ollama repository
      final capturedPrompt = verify(
        () => mockOllamaRepository.generate(
          captureAny(),
          model: captureAny(named: 'model'),
          temperature: captureAny(named: 'temperature'),
        ),
      ).captured;

      // The first captured value should be the prompt
      final actualPrompt = capturedPrompt[0] as String;

      // Check if the prompt contains the expected JSON string
      expect(actualPrompt, contains(expectedJsonString));
      expect(actualPrompt, contains('Based on the provided task details'));
      expect(actualPrompt, contains('identify potential action items'));
    });

    test('handles invalid JSON response gracefully', () async {
      // Arrange
      final mockTask = JournalEntity.task(
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
          statusHistory: [],
          dateFrom: creationDate,
          dateTo: creationDate,
        ),
      );

      final mockAiInput = AiInputTaskObject(
        title: 'Test Task',
        status: 'OPEN',
        creationDate: creationDate,
        actionItems: [],
        logEntries: [],
        estimatedDuration: '00:00',
        timeSpent: '00:00',
      );

      // Return a task when getEntity is called
      when(() => mockAiInputRepository.getEntity(taskId))
          .thenAnswer((_) async => mockTask);

      // Return AI input when generate is called
      when(() => mockAiInputRepository.generate(taskId))
          .thenAnswer((_) async => mockAiInput);

      // Set up mockOllamaRepository to return an invalid JSON response
      final mockStream = Stream.fromIterable([
        CompletionChunk(
          text: 'Thoughts</think>No action items found.',
          model: 'deepseek-r1:14b',
          createdAt: DateTime.now(),
        ),
      ]);

      when(
        () => mockOllamaRepository.generate(
          any(),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
          system: any(named: 'system'),
          images: any(named: 'images'),
        ),
      ).thenAnswer((_) => mockStream);

      // Mock the createAiResponseEntry method to complete successfully
      when(
        () => mockAiInputRepository.createAiResponseEntry(
          data: any(named: 'data'),
          start: any(named: 'start'),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async {});

      // Act
      container.listen(
        actionItemSuggestionsControllerProvider(id: taskId),
        (previous, next) => listener(previous, next),
        fireImmediately: true,
      );

      // Allow the async operations to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Assert
      // Verify that createAiResponseEntry was called with empty suggestedActionItems
      final capturedData = verify(
        () => mockAiInputRepository.createAiResponseEntry(
          data: captureAny(named: 'data'),
          start: any(named: 'start'),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      ).captured.first as AiResponseData;

      // Should have empty suggestedActionItems since no valid JSON was found
      expect(capturedData.suggestedActionItems, isEmpty);
    });

    // Add a test to improve coverage: handling exceptions
    test('handles exceptions gracefully', () async {
      // Arrange
      when(() => mockAiInputRepository.getEntity(taskId))
          .thenThrow(Exception('Test exception'));

      // Act
      container.listen(
        actionItemSuggestionsControllerProvider(id: taskId),
        (previous, next) => listener(previous, next),
        fireImmediately: true,
      );

      // Allow the async operations to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Assert
      verify(
        () => mockLoggingService.captureException(
          any(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);

      // State should remain an empty string
      final finalState =
          container.read(actionItemSuggestionsControllerProvider(id: taskId));
      expect(finalState, '');
    });
  });
}
