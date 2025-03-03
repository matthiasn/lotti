import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/repository/ollama_repository.dart';
import 'package:lotti/features/ai/state/ollama_task_summary.dart';
import 'package:lotti/features/ai/state/task_markdown_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ollama/ollama.dart';
import 'package:riverpod/riverpod.dart';

import '../../../mocks/mocks.dart';

// Add mock class for OllamaRepository
class MockOllamaRepository extends Mock implements OllamaRepository {}

void main() {
  late MockJournalDb mockDb;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockOllamaRepository mockOllamaRepository;
  late ProviderContainer container;

  setUp(() {
    mockDb = MockJournalDb();
    mockPersistenceLogic = MockPersistenceLogic();
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockOllamaRepository = MockOllamaRepository();

    // Register mocks with GetIt
    getIt
      ..registerSingleton<JournalDb>(mockDb)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);

    container = ProviderContainer(
      overrides: [
        ollamaRepositoryProvider.overrideWith((ref) => mockOllamaRepository),
      ],
    );

    registerFallbackValue(
      const AiResponseData(
        model: 'test-model',
        systemMessage: 'test-system-message',
        prompt: 'test-prompt',
        thoughts: 'test-thoughts',
        response: 'test-response',
      ),
    );
  });

  tearDown(() {
    container.dispose();
    getIt.reset();
  });

  test('summarizeEntry processes task and creates AI response', () async {
    const taskId = 'test-task-id';
    const categoryId = 'test-category-id';
    final now = DateTime.now();

    // Create a mock task
    final task = Task(
      meta: Metadata(
        id: taskId,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
        categoryId: categoryId,
      ),
      data: TaskData(
        title: 'Test Task',
        status: TaskStatus.inProgress(
          id: taskId,
          createdAt: DateTime.now(),
          utcOffset: 60,
          timezone: 'Europe/Berlin',
        ),
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
        statusHistory: [],
      ),
      entryText: const EntryText(
        markdown: 'Test task description',
        plainText: 'Test task description',
      ),
    );

    // Mock category
    final category = CategoryDefinition(
      id: categoryId,
      name: 'Test Category',
      createdAt: now,
      updatedAt: now,
      private: false,
      active: true,
      vectorClock: null,
    );

    // Setup mocks including OllamaRepository
    when(() => mockDb.journalEntityById(taskId)).thenAnswer((_) async => task);
    when(() => mockEntitiesCacheService.getCategoryById(categoryId))
        .thenReturn(category);
    when(() => mockDb.getLinkedEntities(taskId)).thenAnswer((_) async => []);
    when(
      () => mockOllamaRepository.generate(
        any(),
        model: any(named: 'model'),
        system: any(named: 'system'),
        temperature: 0.6,
      ),
    ).thenAnswer(
      (_) => Stream.fromIterable([
        CompletionChunk(
          text: '<think>Some thoughts</think>\nAI generated summary',
          model: 'deepseek-r1:8b',
          createdAt: DateTime.now(),
        ),
      ]),
    );
    when(
      () => mockPersistenceLogic.createAiResponseEntry(
        data: any(named: 'data'),
        dateFrom: any(named: 'dateFrom'),
        linkedId: taskId,
        categoryId: categoryId,
      ),
    ).thenAnswer((_) async => null);

    // Create and watch the provider
    final provider = container.read(
      aiTaskSummaryControllerProvider(
        id: taskId,
      ).notifier,
    );

    // Trigger summarization
    await provider.summarizeEntry();

    // Verify interactions
    verify(() => mockDb.journalEntityById(taskId)).called(3);
    verify(() => mockDb.getLinkedEntities(taskId)).called(1);
    verify(
      () => mockOllamaRepository.generate(
        any(),
        model: any(named: 'model'),
        system: any(named: 'system'),
        temperature: 0.6,
      ),
    ).called(2);
    verify(
      () => mockPersistenceLogic.createAiResponseEntry(
        data: any(named: 'data'),
        dateFrom: any(named: 'dateFrom'),
        linkedId: taskId,
        categoryId: categoryId,
      ),
    ).called(2);
  });

  test(
    'summarizeEntry handles null task gracefully',
    () async {
      const taskId = 'non-existent-task-id';

      // Setup mocks
      when(() => mockDb.journalEntityById(taskId))
          .thenAnswer((_) async => null);

      // Create and watch the provider
      final provider = container.read(
        aiTaskSummaryControllerProvider(
          id: taskId,
        ).notifier,
      );

      // Trigger summarization
      await provider.summarizeEntry();

      // Verify interactions
      verify(() => mockDb.journalEntityById(taskId)).called(3);
      verifyNever(
        () => mockOllamaRepository.generate(
          any(),
          model: any(named: 'model'),
          system: any(named: 'system'),
          temperature: 0.6,
        ),
      );
      verifyNever(
        () => mockPersistenceLogic.createAiResponseEntry(
          data: any(named: 'data'),
          dateFrom: any(named: 'dateFrom'),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      );
    },
  );

  test('getMarkdown handles all task statuses correctly', () {
    final now = DateTime.now();
    final task = Task(
      meta: Metadata(
        id: 'test-id',
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      ),
      data: TaskData(
        title: 'Test Task',
        status: TaskStatus.done(
          id: 'test-id',
          createdAt: now,
          utcOffset: 60,
          timezone: 'Europe/Berlin',
        ),
        dateFrom: now,
        dateTo: now,
        statusHistory: [],
      ),
      entryText: const EntryText(
        markdown: 'Test description',
        plainText: 'Test description',
      ),
    );

    // This should not throw a pattern matching error
    expect(task.getMarkdown, returnsNormally);
  });
}
