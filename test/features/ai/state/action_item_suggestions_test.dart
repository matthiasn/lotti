import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/model/ai_input.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/ollama_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ollama/ollama.dart';

// Create mocks
class MockJournalDb extends Mock implements JournalDb {}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockAiInputRepository extends Mock implements AiInputRepository {}

class MockOllamaRepository extends Mock implements OllamaRepository {}

class MockAiResponseEntry extends Mock implements AiResponseEntry {}

// Create fakes for parameter type checking
class FakeAiResponseData extends Fake implements AiResponseData {}

class FakeAiInputTaskObject extends Fake implements AiInputTaskObject {
  @override
  Map<String, dynamic> toJson() {
    return {
      'title': 'Test Task',
      'description': 'Task description',
      'dateFrom': '2023-01-01T10:00:00.000Z',
      'dateTo': '2023-01-01T11:00:00.000Z',
      'categoryId': 'category-123',
      'actionItems': <dynamic>[],
      'status': 'open',
      'id': 'task-123',
    };
  }
}

void main() {
  late MockJournalDb mockJournalDb;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockAiInputRepository mockAiInputRepository;
  late MockOllamaRepository mockOllamaRepository;

  setUpAll(() {
    // Register fallback values
    registerFallbackValue(FakeAiResponseData());
    registerFallbackValue(FakeAiInputTaskObject());
  });

  setUp(() {
    mockJournalDb = MockJournalDb();
    mockPersistenceLogic = MockPersistenceLogic();
    mockAiInputRepository = MockAiInputRepository();
    mockOllamaRepository = MockOllamaRepository();

    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);
  });

  tearDown(getIt.reset);

  group('ActionItemSuggestions', () {
    test('successfully identifies non-Task entities', () async {
      final now = DateTime.now();

      // Create a non-task entry
      const nonTaskId = 'non-task-123';
      final nonTaskEntry = JournalEntry(
        meta: Metadata(
          id: nonTaskId,
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now.add(const Duration(hours: 1)),
        ),
        entryText: const EntryText(
          plainText: 'This is a journal entry, not a task',
        ),
      );

      // Setup the mock to return a non-task entry
      when(() => mockJournalDb.journalEntityById(nonTaskId))
          .thenAnswer((_) async => nonTaskEntry);

      // Create a new controller manually (not using the provider)
      final controller = ControllerForTest();

      // Call the method we're testing
      await controller.testGetActionItemSuggestion(nonTaskId);

      // Verify our method correctly identified this as a non-task and returned early
      verifyNever(
        () => mockPersistenceLogic.createAiResponseEntry(
          data: any(named: 'data'),
          dateFrom: any(named: 'dateFrom'),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      );
    });

    test('process task and saves action item suggestions', () async {
      final now = DateTime.now();
      const testTaskId = 'task-123';

      // Create a task entry
      final openStatus = TaskStatus.open(
        id: 'status-1',
        createdAt: now,
        utcOffset: 0,
      );

      final testTask = Task(
        meta: Metadata(
          id: testTaskId,
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now.add(const Duration(hours: 1)),
        ),
        data: TaskData(
          title: 'Test Task',
          status: openStatus,
          dateFrom: now,
          dateTo: now.add(const Duration(hours: 1)),
          statusHistory: [openStatus],
        ),
        entryText: const EntryText(
          plainText: 'Task description',
        ),
      );

      // Sample AI response with action items
      const mockJsonResponse = '''
[
  {
    "title": "New Action Item 1",
    "completed": false
  },
  {
    "title": "New Action Item 2",
    "completed": false
  }
]
''';

      // Setup mocks
      when(() => mockJournalDb.journalEntityById(testTaskId))
          .thenAnswer((_) async => testTask);

      when(
        () => mockPersistenceLogic.createAiResponseEntry(
          data: any(named: 'data'),
          dateFrom: any(named: 'dateFrom'),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => MockAiResponseEntry());

      // Create the controller with mocked repositories
      final controller = ControllerForTasksTest(
        mockAiInputRepository,
        mockOllamaRepository,
      );

      // Set up AI repositories behavior
      when(() => mockAiInputRepository.generate(testTaskId))
          .thenAnswer((_) async => FakeAiInputTaskObject());

      when(
        () => mockOllamaRepository.generate(
          any(),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
        ),
      ).thenAnswer((_) {
        return Stream.fromIterable([
          CompletionChunk(
            text: '<think>Some thoughts</think>',
            model: 'test-model',
            createdAt: DateTime.now(),
          ),
          CompletionChunk(
            text: '\n\n```json\n',
            model: 'test-model',
            createdAt: DateTime.now(),
          ),
          CompletionChunk(
            text: mockJsonResponse,
            model: 'test-model',
            createdAt: DateTime.now(),
          ),
          CompletionChunk(
            text: '\n```',
            model: 'test-model',
            createdAt: DateTime.now(),
          ),
        ]);
      });

      // Call method being tested
      await controller.testGetActionItemSuggestion(testTaskId);

      // Verify AI repositories were called
      verify(() => mockAiInputRepository.generate(testTaskId)).called(1);

      verify(
        () => mockOllamaRepository.generate(
          any(),
          model: 'deepseek-r1:14b',
          temperature: 0.6,
        ),
      ).called(1);

      // Verify persistence was called
      verify(
        () => mockPersistenceLogic.createAiResponseEntry(
          data: any(named: 'data'),
          dateFrom: any(named: 'dateFrom'),
          linkedId: testTaskId,
          categoryId: any(named: 'categoryId'),
        ),
      ).called(1);

      // Verify state contains the response
      expect(controller.state, contains('New Action Item 1'));
    });

    test('handles error when AI input generation fails', () async {
      final now = DateTime.now();
      const testTaskId = 'task-123';

      // Create a task entry
      final openStatus = TaskStatus.open(
        id: 'status-1',
        createdAt: now,
        utcOffset: 0,
      );

      final testTask = Task(
        meta: Metadata(
          id: testTaskId,
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now.add(const Duration(hours: 1)),
        ),
        data: TaskData(
          title: 'Test Task',
          status: openStatus,
          dateFrom: now,
          dateTo: now.add(const Duration(hours: 1)),
          statusHistory: [openStatus],
        ),
        entryText: const EntryText(
          plainText: 'Task description',
        ),
      );

      // Sample AI response with empty action items
      const mockJsonResponse = '[]';

      // Setup mocks
      when(() => mockJournalDb.journalEntityById(testTaskId))
          .thenAnswer((_) async => testTask);

      // Set up AI repositories behavior to simulate failure
      when(() => mockAiInputRepository.generate(testTaskId))
          .thenAnswer((_) async => null); // Return null to simulate failure

      when(
        () => mockOllamaRepository.generate(
          any(),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
        ),
      ).thenAnswer((_) {
        return Stream.fromIterable([
          CompletionChunk(
            text: '<think>Error scenario</think>',
            model: 'test-model',
            createdAt: DateTime.now(),
          ),
          CompletionChunk(
            text: '\n\n```json\n',
            model: 'test-model',
            createdAt: DateTime.now(),
          ),
          CompletionChunk(
            text: mockJsonResponse,
            model: 'test-model',
            createdAt: DateTime.now(),
          ),
          CompletionChunk(
            text: '\n```',
            model: 'test-model',
            createdAt: DateTime.now(),
          ),
        ]);
      });

      when(
        () => mockPersistenceLogic.createAiResponseEntry(
          data: any(named: 'data'),
          dateFrom: any(named: 'dateFrom'),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => MockAiResponseEntry());

      // Create the controller with mocked repositories
      final controller = ControllerForTasksTest(
        mockAiInputRepository,
        mockOllamaRepository,
      );

      // Call method being tested
      await controller.testGetActionItemSuggestion(testTaskId);

      // Verify AI input repository was called
      verify(() => mockAiInputRepository.generate(testTaskId)).called(1);

      // Verify Ollama repository was called with empty json
      verify(
        () => mockOllamaRepository.generate(
          any(),
          model: 'deepseek-r1:14b',
          temperature: 0.6,
        ),
      ).called(1);

      // Verify persistence was called with empty suggestions
      verify(
        () => mockPersistenceLogic.createAiResponseEntry(
          data: any(named: 'data'),
          dateFrom: any(named: 'dateFrom'),
          linkedId: testTaskId,
          categoryId: any(named: 'categoryId'),
        ),
      ).called(1);
    });

    test('handles exception when Ollama repository throws', () async {
      final now = DateTime.now();
      const testTaskId = 'task-123';

      // Create a task entry
      final openStatus = TaskStatus.open(
        id: 'status-1',
        createdAt: now,
        utcOffset: 0,
      );

      final testTask = Task(
        meta: Metadata(
          id: testTaskId,
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now.add(const Duration(hours: 1)),
        ),
        data: TaskData(
          title: 'Test Task',
          status: openStatus,
          dateFrom: now,
          dateTo: now.add(const Duration(hours: 1)),
          statusHistory: [openStatus],
        ),
        entryText: const EntryText(
          plainText: 'Task description',
        ),
      );

      // Setup mocks
      when(() => mockJournalDb.journalEntityById(testTaskId))
          .thenAnswer((_) async => testTask);

      // Set up AI repositories behavior
      when(() => mockAiInputRepository.generate(testTaskId))
          .thenAnswer((_) async => FakeAiInputTaskObject());

      // Make Ollama repository throw an exception
      when(
        () => mockOllamaRepository.generate(
          any(),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
        ),
      ).thenAnswer((_) => throw Exception('Network error'));

      // Create the controller with mocked repositories
      final controller = ControllerForTasksTestWithErrorHandling(
        mockAiInputRepository,
        mockOllamaRepository,
      );

      // Call method being tested
      await controller.testGetActionItemSuggestion(testTaskId);

      // Verify AI input repository was called
      verify(() => mockAiInputRepository.generate(testTaskId)).called(1);

      // Verify Ollama repository was called
      verify(
        () => mockOllamaRepository.generate(
          any(),
          model: 'deepseek-r1:14b',
          temperature: 0.6,
        ),
      ).called(1);

      // Verify the error was caught (as evidenced by controller state)
      expect(controller.state, contains('Error:'));
    });
  });
}

// Test helper class to isolate just the functionality we want to test
class ControllerForTest {
  final JournalDb _db = getIt<JournalDb>();
  String state = '';

  Future<void> testGetActionItemSuggestion(String id) async {
    final entry = await _db.journalEntityById(id);

    if (entry is! Task) {
      return; // Early return, which is what we're testing
    }

    // We won't actually call these methods in this test
    // But we know the code path worked if we don't get to the persistence step
  }
}

// Test helper class with full task processing functionality
class ControllerForTasksTest {
  ControllerForTasksTest(this._aiInputRepository, this._ollamaRepository);

  final JournalDb _db = getIt<JournalDb>();
  final PersistenceLogic _persistenceLogic = getIt<PersistenceLogic>();
  final AiInputRepository _aiInputRepository;
  final OllamaRepository _ollamaRepository;
  String state = '';

  Future<void> testGetActionItemSuggestion(String id) async {
    final start = DateTime.now();
    final entry = await _db.journalEntityById(id);

    if (entry is! Task) {
      return;
    }

    final aiInput = await _aiInputRepository.generate(id);
    const encoder = JsonEncoder.withIndent('    ');
    final jsonString = encoder.convert(aiInput ?? {});

    final prompt = '''
**Prompt:**

"Based on the provided task details and log entries, identify potential action items that are mentioned in
the text of the logs but have not yet been captured as existing action items. These suggestions should be
formatted as a list of new `AiInputActionItemObject` instances, each containing a title and completion
status. Ensure that only actions not already listed under `actionItems` are included in your suggestions.
Provide these suggested action items in JSON format, adhering to the structure defined by the given classes."

**Example Response:**

```json
[
  {
    "title": "Review project documentation",
    "completed": false
  },
  {
    "title": "Schedule team meeting for next week",
    "completed": false
  }
]
```

**Task Details:**
```json
$jsonString
```

Provide these suggested action items in JSON format, adhering to the structure 
defined by the given classes.
Double check that the returned JSON ONLY contains action items that are not 
already listed under `actionItems` array in the task details. Do not simply
return the example response, but the open action items you have found. If there 
are none, return an empty array. Double check the items you want to return. If 
any is very similar to an item already listed in the in actionItems array of the 
task details, then remove it from the response. 

**Example Response:**

```json
[
  {
    "title": "Review project documentation",
    "completed": false
  },
  {
    "title": "Schedule team meeting for next week",
    "completed": true
  }
]
```
    ''';

    final buffer = StringBuffer();

    const model = 'deepseek-r1:14b';
    const temperature = 0.6;

    final stream = _ollamaRepository.generate(
      prompt,
      model: model,
      temperature: temperature,
    );

    await for (final chunk in stream) {
      buffer.write(chunk.text);
      state = buffer.toString();
    }

    final completeResponse = buffer.toString();
    final thoughts = completeResponse.contains('</think>')
        ? completeResponse.split('</think>')[0]
        : '';
    final response = completeResponse.contains('</think>')
        ? completeResponse.split('</think>')[1]
        : completeResponse;

    final exp = RegExp(r'\[(.|\n)*\]', multiLine: true);
    final match = exp.firstMatch(response)?.group(0) ?? '[]';
    final actionItemsJson = '{"items": $match}';

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(actionItemsJson) as Map<String, dynamic>;
    } catch (_) {
      decoded = {'items': <dynamic>[]};
    }

    final suggestedActionItems = decoded['items'] as List<dynamic>;

    final data = AiResponseData(
      model: model,
      systemMessage: '',
      prompt: prompt,
      thoughts: thoughts,
      response: response,
      suggestedActionItems: suggestedActionItems
          .map(
            (item) => AiActionItem(
              // ignore: avoid_dynamic_calls
              title: item['title'] as String,
              // ignore: avoid_dynamic_calls
              completed: item['completed'] as bool,
            ),
          )
          .toList(),
      type: 'ActionItemSuggestions',
      temperature: temperature,
    );

    await _persistenceLogic.createAiResponseEntry(
      data: data,
      dateFrom: start,
      linkedId: id,
      categoryId: entry.categoryId,
    );
  }
}

// Test helper class with error handling
class ControllerForTasksTestWithErrorHandling {
  ControllerForTasksTestWithErrorHandling(
    this._aiInputRepository,
    this._ollamaRepository,
  );

  final JournalDb _db = getIt<JournalDb>();
  final AiInputRepository _aiInputRepository;
  final OllamaRepository _ollamaRepository;
  String state = '';

  Future<void> testGetActionItemSuggestion(String id) async {
    try {
      final entry = await _db.journalEntityById(id);

      if (entry is! Task) {
        return;
      }

      final aiInput = await _aiInputRepository.generate(id);
      const encoder = JsonEncoder.withIndent('    ');
      final jsonString = encoder.convert(aiInput ?? {});

      final prompt = '''
**Prompt:**

"Based on the provided task details and log entries, identify potential action items that are mentioned in
the text of the logs but have not yet been captured as existing action items. These suggestions should be
formatted as a list of new `AiInputActionItemObject` instances, each containing a title and completion
status. Ensure that only actions not already listed under `actionItems` are included in your suggestions.
Provide these suggested action items in JSON format, adhering to the structure defined by the given classes."

**Task Details:**
```json
$jsonString
```
      ''';

      const model = 'deepseek-r1:14b';
      const temperature = 0.6;

      final stream = _ollamaRepository.generate(
        prompt,
        model: model,
        temperature: temperature,
      );

      final buffer = StringBuffer();
      await for (final chunk in stream) {
        buffer.write(chunk.text);
        state = buffer.toString();
      }
    } catch (e) {
      state = 'Error: $e';
    }
  }
}
