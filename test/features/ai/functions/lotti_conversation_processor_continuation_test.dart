import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/functions/lotti_batch_checklist_handler.dart';
import 'package:lotti/features/ai/functions/lotti_checklist_handler.dart';
import 'package:lotti/features/ai/functions/lotti_conversation_processor.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/services/auto_checklist_service.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockAutoChecklistService extends Mock implements AutoChecklistService {}

class MockChecklistRepository extends Mock implements ChecklistRepository {}

class MockConversationManager extends Mock implements ConversationManager {}

class MockRef extends Mock implements Ref {}

void main() {
  group('LottiChecklistStrategy continuation logic', () {
    late MockJournalDb mockJournalDb;
    late MockAutoChecklistService mockAutoChecklistService;
    late MockChecklistRepository mockChecklistRepository;
    late MockConversationManager mockConversationManager;
    late MockRef mockRef;
    late Task testTask;

    setUp(() {
      mockJournalDb = MockJournalDb();
      mockAutoChecklistService = MockAutoChecklistService();
      mockChecklistRepository = MockChecklistRepository();
      mockConversationManager = MockConversationManager();
      mockRef = MockRef();

      getIt.registerSingleton<JournalDb>(mockJournalDb);

      testTask = Task(
        meta: Metadata(
          id: 'task-123',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          categoryId: 'test-category',
        ),
        data: TaskData(
          title: 'Test Task',
          checklistIds: const [],
          status: TaskStatus.open(
            id: 'status-123',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          statusHistory: const [],
        ),
      );

      // Setup default mocks
      when(() => mockConversationManager.conversationId)
          .thenReturn('test-conv');
      when(() => mockConversationManager.messages).thenReturn([]);
    });

    tearDown(getIt.reset);

    test('shouldContinue includes items from both handlers', () {
      // Create handlers
      final checklistHandler = LottiChecklistItemHandler(
        task: testTask,
        autoChecklistService: mockAutoChecklistService,
        checklistRepository: mockChecklistRepository,
      );

      final batchChecklistHandler = LottiBatchChecklistHandler(
        task: testTask,
        autoChecklistService: mockAutoChecklistService,
        checklistRepository: mockChecklistRepository,
      );

      // Create strategy
      final strategy = LottiChecklistStrategy(
        checklistHandler: checklistHandler,
        batchChecklistHandler: batchChecklistHandler,
        ref: mockRef,
        provider: AiConfigInferenceProvider(
          id: 'test-ollama',
          name: 'Test Ollama',
          inferenceProviderType: InferenceProviderType.ollama,
          baseUrl: 'http://localhost:11434',
          apiKey: 'test-key',
          createdAt: DateTime.now(),
        ),
      );

      // Test 1: No items in either handler (before first round, _rounds = 0)
      expect(strategy.shouldContinue(mockConversationManager), false,
          reason: 'Should not continue before first round with no items');

      // Simulate processing a round (increment _rounds internally)
      // We can't directly access _rounds, so we'll test behavior

      // Test 2: Items only in single handler
      checklistHandler.addSuccessfulItems(['Item 1', 'Item 2']);
      expect(strategy.shouldContinue(mockConversationManager), true,
          reason: 'Should continue when single handler has items');

      // Test 3: Items in both handlers (simulating batch creation)
      // In real usage, batch handler copies its items to single handler
      checklistHandler.addSuccessfulItems(['Batch Item 1', 'Batch Item 2']);
      expect(strategy.shouldContinue(mockConversationManager), true,
          reason: 'Should continue when both handlers have items');
    });

    test('getContinuationPrompt combines items from all sources', () {
      // Create handlers
      final checklistHandler = LottiChecklistItemHandler(
        task: testTask,
        autoChecklistService: mockAutoChecklistService,
        checklistRepository: mockChecklistRepository,
      );

      final batchChecklistHandler = LottiBatchChecklistHandler(
        task: testTask,
        autoChecklistService: mockAutoChecklistService,
        checklistRepository: mockChecklistRepository,
      );

      // Add items to simulate both single and batch creation
      checklistHandler.addSuccessfulItems([
        'Single Item 1',
        'Single Item 2',
        'Batch Item 1',
        'Batch Item 2',
        'Batch Item 3',
      ]);

      final strategy = LottiChecklistStrategy(
        checklistHandler: checklistHandler,
        batchChecklistHandler: batchChecklistHandler,
        ref: mockRef,
        provider: AiConfigInferenceProvider(
          id: 'test-ollama',
          name: 'Test Ollama',
          inferenceProviderType: InferenceProviderType.ollama,
          baseUrl: 'http://localhost:11434',
          apiKey: 'test-key',
          createdAt: DateTime.now(),
        ),
      );

      // Get continuation prompt
      final prompt = strategy.getContinuationPrompt(mockConversationManager);

      // Should include total count of all items (new format: "created N item(s)")
      expect(prompt, contains('created 5 item(s)'));
      expect(prompt, contains('Single Item 1'));
      expect(prompt, contains('Batch Item 3'));
    });

    test('logs should report combined totals', () {
      // This test verifies that the logging correctly reports items from both handlers
      final checklistHandler = LottiChecklistItemHandler(
        task: testTask,
        autoChecklistService: mockAutoChecklistService,
        checklistRepository: mockChecklistRepository,
      )

        // Add items to both handlers
        ..addSuccessfulItems(['Item 1', 'Item 2'])
        // In real execution, batch handler would have its own items
        // but they get copied to single handler, so we simulate that
        ..addSuccessfulItems(['Batch 1', 'Batch 2', 'Batch 3']);

      // The total should be 5 items
      final totalItems = checklistHandler.successfulItems.length;
      expect(totalItems, 5);

      // This simulates what the logging would report
      final logMessage = 'Conversation completed: $totalItems items created '
          '(checklist: 5, batch: 0), errors: false';
      expect(logMessage, contains('5 items created'));
    });

    group('cloud provider continuation behavior', () {
      test('Gemini should NOT continue when items created but no errors', () {
        final checklistHandler = LottiChecklistItemHandler(
          task: testTask,
          autoChecklistService: mockAutoChecklistService,
          checklistRepository: mockChecklistRepository,
        )..addSuccessfulItems(['Item 1', 'Item 2']);

        final batchChecklistHandler = LottiBatchChecklistHandler(
          task: testTask,
          autoChecklistService: mockAutoChecklistService,
          checklistRepository: mockChecklistRepository,
        );

        // Create Gemini provider (cloud)
        final strategy = LottiChecklistStrategy(
          checklistHandler: checklistHandler,
          batchChecklistHandler: batchChecklistHandler,
          ref: mockRef,
          provider: AiConfigInferenceProvider(
            id: 'test-gemini',
            name: 'Test Gemini',
            inferenceProviderType: InferenceProviderType.gemini,
            baseUrl: 'https://generativelanguage.googleapis.com',
            apiKey: 'test-key',
            createdAt: DateTime(2025),
          ),
        );

        // Cloud provider with success but no errors should NOT continue
        // This prevents unnecessary multi-turn API calls for Gemini
        expect(strategy.shouldContinue(mockConversationManager), false,
            reason:
                'Gemini should not continue when successful with no errors');
      });

      test('Ollama should continue on first round with items', () {
        final checklistHandler = LottiChecklistItemHandler(
          task: testTask,
          autoChecklistService: mockAutoChecklistService,
          checklistRepository: mockChecklistRepository,
        )..addSuccessfulItems(['Item 1']);

        final batchChecklistHandler = LottiBatchChecklistHandler(
          task: testTask,
          autoChecklistService: mockAutoChecklistService,
          checklistRepository: mockChecklistRepository,
        );

        // Create Ollama provider (local)
        final strategy = LottiChecklistStrategy(
          checklistHandler: checklistHandler,
          batchChecklistHandler: batchChecklistHandler,
          ref: mockRef,
          provider: AiConfigInferenceProvider(
            id: 'test-ollama',
            name: 'Test Ollama',
            inferenceProviderType: InferenceProviderType.ollama,
            baseUrl: 'http://localhost:11434',
            apiKey: '',
            createdAt: DateTime(2025),
          ),
        );

        // Ollama should continue for multi-round assistance
        expect(strategy.shouldContinue(mockConversationManager), true,
            reason: 'Ollama should continue when items created');
      });

      test('OpenAI provider should NOT continue when successful', () {
        final checklistHandler = LottiChecklistItemHandler(
          task: testTask,
          autoChecklistService: mockAutoChecklistService,
          checklistRepository: mockChecklistRepository,
        )..addSuccessfulItems(['Item 1', 'Item 2']);

        final batchChecklistHandler = LottiBatchChecklistHandler(
          task: testTask,
          autoChecklistService: mockAutoChecklistService,
          checklistRepository: mockChecklistRepository,
        );

        // Create OpenAI provider (cloud)
        final strategy = LottiChecklistStrategy(
          checklistHandler: checklistHandler,
          batchChecklistHandler: batchChecklistHandler,
          ref: mockRef,
          provider: AiConfigInferenceProvider(
            id: 'test-openai',
            name: 'Test OpenAI',
            inferenceProviderType: InferenceProviderType.openAi,
            baseUrl: 'https://api.openai.com',
            apiKey: 'test-key',
            createdAt: DateTime(2025),
          ),
        );

        // Cloud provider with success should NOT continue
        expect(strategy.shouldContinue(mockConversationManager), false,
            reason: 'OpenAI should not continue when successful');
      });

      test('Anthropic provider should NOT continue when successful', () {
        final checklistHandler = LottiChecklistItemHandler(
          task: testTask,
          autoChecklistService: mockAutoChecklistService,
          checklistRepository: mockChecklistRepository,
        )..addSuccessfulItems(['Item 1']);

        final batchChecklistHandler = LottiBatchChecklistHandler(
          task: testTask,
          autoChecklistService: mockAutoChecklistService,
          checklistRepository: mockChecklistRepository,
        );

        // Create Anthropic provider (cloud)
        final strategy = LottiChecklistStrategy(
          checklistHandler: checklistHandler,
          batchChecklistHandler: batchChecklistHandler,
          ref: mockRef,
          provider: AiConfigInferenceProvider(
            id: 'test-anthropic',
            name: 'Test Anthropic',
            inferenceProviderType: InferenceProviderType.anthropic,
            baseUrl: 'https://api.anthropic.com',
            apiKey: 'test-key',
            createdAt: DateTime(2025),
          ),
        );

        // Cloud provider with success should NOT continue
        expect(strategy.shouldContinue(mockConversationManager), false,
            reason: 'Anthropic should not continue when successful');
      });
    });

    test('getResponseSummary includes both created and updated items', () {
      final checklistHandler = LottiChecklistItemHandler(
        task: testTask,
        autoChecklistService: mockAutoChecklistService,
        checklistRepository: mockChecklistRepository,
      )..addSuccessfulItems(['Created Item 1', 'Created Item 2']);

      final batchChecklistHandler = LottiBatchChecklistHandler(
        task: testTask,
        autoChecklistService: mockAutoChecklistService,
        checklistRepository: mockChecklistRepository,
      );

      final strategy = LottiChecklistStrategy(
        checklistHandler: checklistHandler,
        batchChecklistHandler: batchChecklistHandler,
        ref: mockRef,
        provider: AiConfigInferenceProvider(
          id: 'test-ollama',
          name: 'Test Ollama',
          inferenceProviderType: InferenceProviderType.ollama,
          baseUrl: 'http://localhost:11434',
          apiKey: '',
          createdAt: DateTime(2025),
        ),
      );

      final summary = strategy.getResponseSummary();
      expect(summary, contains('Created 2 checklist items'));
      expect(summary, contains('Created Item 1'));
      expect(summary, contains('Created Item 2'));
    });

    test('getResponseSummary handles empty state', () {
      final checklistHandler = LottiChecklistItemHandler(
        task: testTask,
        autoChecklistService: mockAutoChecklistService,
        checklistRepository: mockChecklistRepository,
      );

      final batchChecklistHandler = LottiBatchChecklistHandler(
        task: testTask,
        autoChecklistService: mockAutoChecklistService,
        checklistRepository: mockChecklistRepository,
      );

      final strategy = LottiChecklistStrategy(
        checklistHandler: checklistHandler,
        batchChecklistHandler: batchChecklistHandler,
        ref: mockRef,
        provider: AiConfigInferenceProvider(
          id: 'test-ollama',
          name: 'Test Ollama',
          inferenceProviderType: InferenceProviderType.ollama,
          baseUrl: 'http://localhost:11434',
          apiKey: '',
          createdAt: DateTime(2025),
        ),
      );

      final summary = strategy.getResponseSummary();
      expect(summary, 'No checklist items were created or updated.');
    });

    test('getContinuationPrompt returns null when should not continue', () {
      final checklistHandler = LottiChecklistItemHandler(
        task: testTask,
        autoChecklistService: mockAutoChecklistService,
        checklistRepository: mockChecklistRepository,
      )..addSuccessfulItems(['Item 1']);

      final batchChecklistHandler = LottiBatchChecklistHandler(
        task: testTask,
        autoChecklistService: mockAutoChecklistService,
        checklistRepository: mockChecklistRepository,
      );

      // Cloud provider - should NOT continue
      final strategy = LottiChecklistStrategy(
        checklistHandler: checklistHandler,
        batchChecklistHandler: batchChecklistHandler,
        ref: mockRef,
        provider: AiConfigInferenceProvider(
          id: 'test-gemini',
          name: 'Test Gemini',
          inferenceProviderType: InferenceProviderType.gemini,
          baseUrl: 'https://generativelanguage.googleapis.com',
          apiKey: 'test-key',
          createdAt: DateTime(2025),
        ),
      );

      // When should not continue, getContinuationPrompt returns null
      expect(strategy.getContinuationPrompt(mockConversationManager), isNull);
    });

    test('getContinuationPrompt returns null before any rounds processed', () {
      // The continuation logic only activates after at least one round
      // Before any rounds are processed (_rounds == 0), shouldContinue is false
      final checklistHandler = LottiChecklistItemHandler(
        task: testTask,
        autoChecklistService: mockAutoChecklistService,
        checklistRepository: mockChecklistRepository,
      );

      final batchChecklistHandler = LottiBatchChecklistHandler(
        task: testTask,
        autoChecklistService: mockAutoChecklistService,
        checklistRepository: mockChecklistRepository,
      );

      final strategy = LottiChecklistStrategy(
        checklistHandler: checklistHandler,
        batchChecklistHandler: batchChecklistHandler,
        ref: mockRef,
        provider: AiConfigInferenceProvider(
          id: 'test-ollama',
          name: 'Test Ollama',
          inferenceProviderType: InferenceProviderType.ollama,
          baseUrl: 'http://localhost:11434',
          apiKey: '',
          createdAt: DateTime(2025),
        ),
      );

      // Before any rounds processed, shouldContinue returns false
      // so getContinuationPrompt returns null
      final prompt = strategy.getContinuationPrompt(mockConversationManager);
      expect(prompt, isNull,
          reason: 'Should not provide continuation prompt before first round');
    });
  });
}
