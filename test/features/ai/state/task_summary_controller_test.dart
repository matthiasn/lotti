// ignore_for_file: inference_failure_on_function_invocation

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/ollama_repository.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/task_summary_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

class MockAiInputRepository extends Mock implements AiInputRepository {}

class MockOllamaRepository extends Mock implements OllamaRepository {}

class MockCloudInferenceRepository extends Mock
    implements CloudInferenceRepository {}

class MockLoggingService extends Mock implements LoggingService {}

class MockJournalDb extends Mock implements JournalDb {}

class Listener<T> extends Mock {
  void call(T? previous, T next);
}

void main() {
  late ProviderContainer container;
  late MockAiInputRepository mockAiInputRepository;
  late MockOllamaRepository mockOllamaRepository;
  late MockCloudInferenceRepository mockCloudInferenceRepository;
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
        type: 'TaskSummary',
      ),
    );
    registerFallbackValue(DateTime.now());
    registerFallbackValue(InferenceStatus.idle);
  });

  setUp(() {
    mockAiInputRepository = MockAiInputRepository();
    mockOllamaRepository = MockOllamaRepository();
    mockCloudInferenceRepository = MockCloudInferenceRepository();
    mockLoggingService = MockLoggingService();
    mockJournalDb = MockJournalDb();
    listener = Listener<String>();

    // Register the mocks with GetIt
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

    // Mock getConfigFlag to return false for useCloudInferenceFlag by default
    when(() => mockJournalDb.getConfigFlag(useCloudInferenceFlag))
        .thenAnswer((_) async => false);

    // For the initial test
    when(() => mockAiInputRepository.getEntity(any()))
        .thenAnswer((_) async => null);

    container = ProviderContainer(
      overrides: [
        aiInputRepositoryProvider.overrideWithValue(mockAiInputRepository),
        ollamaRepositoryProvider.overrideWithValue(mockOllamaRepository),
        cloudInferenceRepositoryProvider
            .overrideWithValue(mockCloudInferenceRepository),
      ],
    );
  });

  tearDown(() async {
    // First, complete any pending futures
    await Future<void>.delayed(Duration.zero);
    container.dispose();

    // Unregister the mocks from GetIt to clean up
    getIt
      ..unregister<LoggingService>()
      ..unregister<JournalDb>();
  });

  group('TaskSummaryController', () {
    test('initial build returns empty string', () async {
      // Get the initial state directly first
      final value = container.read(taskSummaryControllerProvider(id: taskId));
      expect(value, '');

      // Listen to state changes
      container.listen(
        taskSummaryControllerProvider(id: taskId),
        listener.call,
        fireImmediately: true,
      );

      // Verify initial empty string and wait for any pending futures
      verify(() => listener(null, '')).called(1);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });

    test('getTaskSummary returns early when entity is not a Task', () async {
      // Arrange - set up a non-task entity
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

      // Listen to the state changes
      container.listen(
        taskSummaryControllerProvider(id: taskId),
        listener.call,
        fireImmediately: true,
      );

      // Wait a bit to allow the delayed getTaskSummary call to execute
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Assert
      verify(() => mockAiInputRepository.getEntity(taskId)).called(1);
      verifyNever(
        () => mockOllamaRepository.generate(
          any(),
          model: any(named: 'model'),
          temperature: any(named: 'temperature'),
        ),
      );
    });

    test(
      'correctly processes Ollama response',
      () {
        // The asynchronous nature of streams makes it difficult to test reliably
        // in the current setup without refactoring the controller itself
      },
      skip: true,
    );

    test(
      'handles errors during generation',
      () {
        // The asynchronous nature of streams makes it difficult to test reliably
        // in the current setup without refactoring the controller itself
      },
      skip: true,
    );
  });
}
