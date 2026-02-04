import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/features/daily_os/voice/day_plan_functions.dart';
import 'package:lotti/features/daily_os/voice/day_plan_voice_strategy.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

class MockUnifiedDailyOsDataController extends Mock
    implements UnifiedDailyOsDataController {}

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

class MockJournalDb extends Mock implements JournalDb {}

class MockFts5Db extends Mock implements Fts5Db {}

class MockConversationManager extends Mock implements ConversationManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockUnifiedDailyOsDataController mockController;
  late MockEntitiesCacheService mockCacheService;
  late MockJournalDb mockDb;
  late MockFts5Db mockFts5Db;
  late MockConversationManager mockManager;
  late CategoryResolver categoryResolver;
  late TaskSearcher taskSearcher;

  final testDate = DateTime(2026, 1, 15);

  final categoryDate = DateTime(2026);

  final workCategory = CategoryDefinition(
    id: 'cat-work',
    name: 'Work',
    color: '#FF0000',
    createdAt: categoryDate,
    updatedAt: categoryDate,
    vectorClock: null,
    private: false,
    active: true,
  );

  final exerciseCategory = CategoryDefinition(
    id: 'cat-exercise',
    name: 'Exercise',
    color: '#00FF00',
    createdAt: categoryDate,
    updatedAt: categoryDate,
    vectorClock: null,
    private: false,
    active: true,
  );

  PlannedBlock createTestBlock({
    required String id,
    required String categoryId,
    required int startHour,
    required int endHour,
    String? note,
  }) {
    return PlannedBlock(
      id: id,
      categoryId: categoryId,
      startTime: DateTime(2026, 1, 15, startHour),
      endTime: DateTime(2026, 1, 15, endHour),
      note: note,
    );
  }

  setUpAll(() {
    registerFallbackValue(
      PlannedBlock(
        id: 'fallback',
        categoryId: 'cat-1',
        startTime: testDate,
        endTime: testDate.add(const Duration(hours: 1)),
      ),
    );
    registerFallbackValue(
      const PinnedTaskRef(taskId: 'task-1', categoryId: 'cat-1'),
    );
  });

  setUp(() {
    mockController = MockUnifiedDailyOsDataController();
    mockCacheService = MockEntitiesCacheService();
    mockDb = MockJournalDb();
    mockFts5Db = MockFts5Db();
    mockManager = MockConversationManager();

    when(() => mockCacheService.sortedCategories).thenReturn([
      workCategory,
      exerciseCategory,
    ]);

    categoryResolver = CategoryResolver(mockCacheService);
    taskSearcher = TaskSearcher(mockDb, mockFts5Db);
  });

  group('DayPlanActionResult', () {
    test('toJsonString includes success field', () {
      const result = DayPlanActionResult(
        functionName: 'test_function',
        success: true,
        message: 'Test message',
      );

      final json = jsonDecode(result.toJsonString()) as Map<String, dynamic>;

      expect(json['success'], isTrue);
      expect(json['message'], 'Test message');
    });

    test('toJsonString includes error field when present', () {
      const result = DayPlanActionResult(
        functionName: 'test_function',
        success: false,
        error: 'Test error',
      );

      final json = jsonDecode(result.toJsonString()) as Map<String, dynamic>;

      expect(json['success'], isFalse);
      expect(json['error'], 'Test error');
    });

    test('toJsonString omits null fields', () {
      const result = DayPlanActionResult(
        functionName: 'test_function',
        success: true,
      );

      final json = jsonDecode(result.toJsonString()) as Map<String, dynamic>;

      expect(json.containsKey('message'), isFalse);
      expect(json.containsKey('error'), isFalse);
    });
  });

  group('DayPlanVoiceStrategy - processToolCalls', () {
    test('add_time_block with valid inputs calls controller', () async {
      when(() => mockController.addPlannedBlock(any()))
          .thenAnswer((_) async {});

      final strategy = DayPlanVoiceStrategy(
        date: testDate,
        dayPlanController: mockController,
        categoryResolver: categoryResolver,
        taskSearcher: taskSearcher,
        currentPlanData: null,
      );

      final toolCalls = [
        ChatCompletionMessageToolCall(
          id: 'call-1',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: DayPlanFunctions.addTimeBlock,
            arguments: jsonEncode({
              'categoryName': 'Work',
              'startTime': '09:00',
              'endTime': '11:00',
              'note': 'Morning focus',
            }),
          ),
        ),
      ];

      await strategy.processToolCalls(
        toolCalls: toolCalls,
        manager: mockManager,
      );

      expect(strategy.results.length, 1);
      expect(strategy.results.first.success, isTrue);
      expect(
          strategy.results.first.functionName, DayPlanFunctions.addTimeBlock);
      verify(() => mockController.addPlannedBlock(any())).called(1);
    });

    test('add_time_block fails when category not found', () async {
      final strategy = DayPlanVoiceStrategy(
        date: testDate,
        dayPlanController: mockController,
        categoryResolver: categoryResolver,
        taskSearcher: taskSearcher,
        currentPlanData: null,
      );

      final toolCalls = [
        ChatCompletionMessageToolCall(
          id: 'call-1',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: DayPlanFunctions.addTimeBlock,
            arguments: jsonEncode({
              'categoryName': 'Nonexistent',
              'startTime': '09:00',
              'endTime': '11:00',
            }),
          ),
        ),
      ];

      await strategy.processToolCalls(
        toolCalls: toolCalls,
        manager: mockManager,
      );

      expect(strategy.results.length, 1);
      expect(strategy.results.first.success, isFalse);
      expect(strategy.results.first.error, contains('Category not found'));
      verifyNever(() => mockController.addPlannedBlock(any()));
    });

    test('add_time_block fails when end time before start time', () async {
      final strategy = DayPlanVoiceStrategy(
        date: testDate,
        dayPlanController: mockController,
        categoryResolver: categoryResolver,
        taskSearcher: taskSearcher,
        currentPlanData: null,
      );

      final toolCalls = [
        ChatCompletionMessageToolCall(
          id: 'call-1',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: DayPlanFunctions.addTimeBlock,
            arguments: jsonEncode({
              'categoryName': 'Work',
              'startTime': '11:00',
              'endTime': '09:00',
            }),
          ),
        ),
      ];

      await strategy.processToolCalls(
        toolCalls: toolCalls,
        manager: mockManager,
      );

      expect(strategy.results.first.success, isFalse);
      expect(
        strategy.results.first.error,
        contains('End time must be after start time'),
      );
    });

    test('move_time_block preserves duration', () async {
      when(() => mockController.updatePlannedBlock(any()))
          .thenAnswer((_) async {});

      final existingBlock = createTestBlock(
        id: 'block-1',
        categoryId: 'cat-work',
        startHour: 9,
        endHour: 11, // 2-hour block
      );

      final strategy = DayPlanVoiceStrategy(
        date: testDate,
        dayPlanController: mockController,
        categoryResolver: categoryResolver,
        taskSearcher: taskSearcher,
        currentPlanData: DayPlanData(
          planDate: testDate,
          status: const DayPlanStatus.draft(),
          plannedBlocks: [existingBlock],
        ),
      );

      final toolCalls = [
        ChatCompletionMessageToolCall(
          id: 'call-1',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: DayPlanFunctions.moveTimeBlock,
            arguments: jsonEncode({
              'blockId': 'block-1',
              'newStartTime': '14:00',
            }),
          ),
        ),
      ];

      await strategy.processToolCalls(
        toolCalls: toolCalls,
        manager: mockManager,
      );

      expect(strategy.results.first.success, isTrue);

      final capturedBlock = verify(
        () => mockController.updatePlannedBlock(captureAny()),
      ).captured.first as PlannedBlock;

      // Duration should be preserved (2 hours)
      expect(capturedBlock.startTime.hour, 14);
      expect(capturedBlock.endTime.hour, 16);
    });

    test('resize_time_block changes end time', () async {
      when(() => mockController.updatePlannedBlock(any()))
          .thenAnswer((_) async {});

      final existingBlock = createTestBlock(
        id: 'block-1',
        categoryId: 'cat-work',
        startHour: 9,
        endHour: 11,
      );

      final strategy = DayPlanVoiceStrategy(
        date: testDate,
        dayPlanController: mockController,
        categoryResolver: categoryResolver,
        taskSearcher: taskSearcher,
        currentPlanData: DayPlanData(
          planDate: testDate,
          status: const DayPlanStatus.draft(),
          plannedBlocks: [existingBlock],
        ),
      );

      final toolCalls = [
        ChatCompletionMessageToolCall(
          id: 'call-1',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: DayPlanFunctions.resizeTimeBlock,
            arguments: jsonEncode({
              'blockId': 'block-1',
              'newEndTime': '10:00', // Shrink to 1 hour
            }),
          ),
        ),
      ];

      await strategy.processToolCalls(
        toolCalls: toolCalls,
        manager: mockManager,
      );

      expect(strategy.results.first.success, isTrue);

      final capturedBlock = verify(
        () => mockController.updatePlannedBlock(captureAny()),
      ).captured.first as PlannedBlock;

      expect(capturedBlock.startTime.hour, 9); // Unchanged
      expect(capturedBlock.endTime.hour, 10); // Changed
    });

    test('delete_time_block removes block', () async {
      when(() => mockController.removePlannedBlock(any()))
          .thenAnswer((_) async {});

      final existingBlock = createTestBlock(
        id: 'block-1',
        categoryId: 'cat-work',
        startHour: 9,
        endHour: 11,
      );

      final strategy = DayPlanVoiceStrategy(
        date: testDate,
        dayPlanController: mockController,
        categoryResolver: categoryResolver,
        taskSearcher: taskSearcher,
        currentPlanData: DayPlanData(
          planDate: testDate,
          status: const DayPlanStatus.draft(),
          plannedBlocks: [existingBlock],
        ),
      );

      final toolCalls = [
        ChatCompletionMessageToolCall(
          id: 'call-1',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: DayPlanFunctions.deleteTimeBlock,
            arguments: jsonEncode({'blockId': 'block-1'}),
          ),
        ),
      ];

      await strategy.processToolCalls(
        toolCalls: toolCalls,
        manager: mockManager,
      );

      expect(strategy.results.first.success, isTrue);
      verify(() => mockController.removePlannedBlock('block-1')).called(1);
    });

    test('updates snapshot between sequential tool calls', () async {
      when(() => mockController.removePlannedBlock(any()))
          .thenAnswer((_) async {});
      when(() => mockController.updatePlannedBlock(any()))
          .thenAnswer((_) async {});

      final existingBlock = createTestBlock(
        id: 'block-1',
        categoryId: 'cat-work',
        startHour: 9,
        endHour: 11,
      );

      final strategy = DayPlanVoiceStrategy(
        date: testDate,
        dayPlanController: mockController,
        categoryResolver: categoryResolver,
        taskSearcher: taskSearcher,
        currentPlanData: DayPlanData(
          planDate: testDate,
          status: const DayPlanStatus.draft(),
          plannedBlocks: [existingBlock],
        ),
      );

      final toolCalls = [
        ChatCompletionMessageToolCall(
          id: 'call-1',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: DayPlanFunctions.deleteTimeBlock,
            arguments: jsonEncode({'blockId': 'block-1'}),
          ),
        ),
        ChatCompletionMessageToolCall(
          id: 'call-2',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: DayPlanFunctions.resizeTimeBlock,
            arguments: jsonEncode({
              'blockId': 'block-1',
              'newEndTime': '10:00',
            }),
          ),
        ),
      ];

      await strategy.processToolCalls(
        toolCalls: toolCalls,
        manager: mockManager,
      );

      expect(strategy.results.length, 2);
      expect(strategy.results[0].success, isTrue);
      expect(strategy.results[1].success, isFalse);
      expect(strategy.results[1].error, contains('Block not found'));

      verify(() => mockController.removePlannedBlock('block-1')).called(1);
      verifyNever(() => mockController.updatePlannedBlock(any()));
    });

    test('unknown function returns error', () async {
      final strategy = DayPlanVoiceStrategy(
        date: testDate,
        dayPlanController: mockController,
        categoryResolver: categoryResolver,
        taskSearcher: taskSearcher,
        currentPlanData: null,
      );

      final toolCalls = [
        ChatCompletionMessageToolCall(
          id: 'call-1',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: 'unknown_function',
            arguments: jsonEncode({}),
          ),
        ),
      ];

      await strategy.processToolCalls(
        toolCalls: toolCalls,
        manager: mockManager,
      );

      expect(strategy.results.first.success, isFalse);
      expect(strategy.results.first.error, contains('Unknown function'));
    });

    test('multiple tool calls are processed sequentially', () async {
      when(() => mockController.addPlannedBlock(any()))
          .thenAnswer((_) async {});
      when(() => mockController.removePlannedBlock(any()))
          .thenAnswer((_) async {});

      final existingBlock = createTestBlock(
        id: 'block-1',
        categoryId: 'cat-work',
        startHour: 9,
        endHour: 11,
      );

      final strategy = DayPlanVoiceStrategy(
        date: testDate,
        dayPlanController: mockController,
        categoryResolver: categoryResolver,
        taskSearcher: taskSearcher,
        currentPlanData: DayPlanData(
          planDate: testDate,
          status: const DayPlanStatus.draft(),
          plannedBlocks: [existingBlock],
        ),
      );

      final toolCalls = [
        ChatCompletionMessageToolCall(
          id: 'call-1',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: DayPlanFunctions.addTimeBlock,
            arguments: jsonEncode({
              'categoryName': 'Exercise',
              'startTime': '07:00',
              'endTime': '08:00',
            }),
          ),
        ),
        ChatCompletionMessageToolCall(
          id: 'call-2',
          type: ChatCompletionMessageToolCallType.function,
          function: ChatCompletionMessageFunctionCall(
            name: DayPlanFunctions.deleteTimeBlock,
            arguments: jsonEncode({'blockId': 'block-1'}),
          ),
        ),
      ];

      await strategy.processToolCalls(
        toolCalls: toolCalls,
        manager: mockManager,
      );

      expect(strategy.results.length, 2);
      expect(strategy.results[0].success, isTrue);
      expect(strategy.results[1].success, isTrue);
    });
  });

  group('DayPlanVoiceStrategy - shouldContinue', () {
    test('returns false (single-turn for MVP)', () {
      final strategy = DayPlanVoiceStrategy(
        date: testDate,
        dayPlanController: mockController,
        categoryResolver: categoryResolver,
        taskSearcher: taskSearcher,
        currentPlanData: null,
      );

      expect(strategy.shouldContinue(mockManager), isFalse);
    });
  });

  group('DayPlanVoiceStrategy - getContinuationPrompt', () {
    test('returns null', () {
      final strategy = DayPlanVoiceStrategy(
        date: testDate,
        dayPlanController: mockController,
        categoryResolver: categoryResolver,
        taskSearcher: taskSearcher,
        currentPlanData: null,
      );

      expect(strategy.getContinuationPrompt(mockManager), isNull);
    });
  });
}
