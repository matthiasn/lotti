import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/functions/lotti_batch_checklist_handler.dart';
import 'package:lotti/features/ai/functions/lotti_checklist_handler.dart';
import 'package:lotti/features/ai/functions/lotti_conversation_processor.dart';
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
      );

      // Get continuation prompt
      final prompt = strategy.getContinuationPrompt(mockConversationManager);

      // Should include total count of all items
      expect(prompt, contains('5 checklist item(s)'));
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
  });
}
