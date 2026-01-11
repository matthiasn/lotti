import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/functions/lotti_conversation_processor.dart';
import 'package:lotti/features/ai/functions/task_functions.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';
import 'package:lotti/features/ai/services/auto_checklist_service.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../test_utils.dart';

// Mocks
class MockJournalRepository extends Mock implements JournalRepository {}

class MockChecklistRepository extends Mock implements ChecklistRepository {}

class MockAutoChecklistService extends Mock implements AutoChecklistService {}

class MockOllamaInferenceRepository extends Mock
    implements OllamaInferenceRepository {}

/// Mock ConversationRepository that extends the real class.
class MockConversationRepository extends ConversationRepository {
  MockConversationRepository(this._mockManager);

  final MockConversationManager _mockManager;
  final List<String> deletedConversationIds = [];

  Future<void> Function({
    required String conversationId,
    required String message,
    required String model,
    required AiConfigInferenceProvider provider,
    required InferenceRepositoryInterface inferenceRepo,
    List<ChatCompletionTool>? tools,
    double temperature,
    ConversationStrategy? strategy,
  })? sendMessageDelegate;

  @override
  void build() {}

  @override
  String createConversation({
    String? systemMessage,
    int maxTurns = 20,
  }) {
    return 'test-conv';
  }

  @override
  ConversationManager? getConversation(String conversationId) {
    return _mockManager;
  }

  @override
  void deleteConversation(String conversationId) {
    deletedConversationIds.add(conversationId);
  }

  @override
  Future<void> sendMessage({
    required String conversationId,
    required String message,
    required String model,
    required AiConfigInferenceProvider provider,
    required InferenceRepositoryInterface inferenceRepo,
    List<ChatCompletionTool>? tools,
    double temperature = 0.7,
    ConversationStrategy? strategy,
  }) async {
    if (sendMessageDelegate != null) {
      await sendMessageDelegate!(
        conversationId: conversationId,
        message: message,
        model: model,
        provider: provider,
        inferenceRepo: inferenceRepo,
        tools: tools,
        temperature: temperature,
        strategy: strategy,
      );
    }
  }
}

class MockConversationManager extends Mock implements ConversationManager {}

class MockJournalDb extends Mock implements JournalDb {}

class MockLoggingService extends Mock implements LoggingService {}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

// Test data factory - uses fixed dates per test/README.md policy
class TestDataFactory {
  // Fixed date for deterministic tests
  static final _fixedDate = DateTime(2024, 1, 15);

  static Task createTask({
    String? id,
    String? title,
    Duration? estimate,
    DateTime? due,
    List<String>? checklistIds,
  }) {
    final taskId = id ?? 'test-task-id';
    return Task(
      meta: Metadata(
        id: taskId,
        createdAt: _fixedDate,
        updatedAt: _fixedDate,
        dateFrom: _fixedDate,
        dateTo: _fixedDate,
        categoryId: 'test-category',
      ),
      data: TaskData(
        title: title ?? 'Test Task',
        estimate: estimate,
        due: due,
        checklistIds: checklistIds ?? [],
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: _fixedDate,
          utcOffset: 0,
        ),
        statusHistory: const [],
        dateFrom: _fixedDate,
        dateTo: _fixedDate,
      ),
    );
  }

  static AiConfigModel createModel({
    String? name,
    bool supportsFunctionCalling = true,
  }) {
    return AiConfigModel(
      id: 'test-model',
      name: name ?? 'gpt-oss:20b',
      providerModelId: 'gpt-oss:20b',
      inferenceProviderId: 'ollama',
      createdAt: DateTime.now(),
      inputModalities: const [Modality.text],
      outputModalities: const [Modality.text],
      isReasoningModel: false,
      supportsFunctionCalling: supportsFunctionCalling,
      maxCompletionTokens: 1000,
    );
  }

  static AiConfigPrompt createPromptConfig() {
    return AiConfigPrompt(
      id: 'test-prompt',
      name: 'Test Prompt',
      systemMessage: 'Test system message',
      userMessage: 'Test user message',
      defaultModelId: 'test-model',
      modelIds: const ['test-model'],
      createdAt: DateTime.now(),
      useReasoning: false,
      requiredInputData: const [],
      aiResponseType: AiResponseType.checklistUpdates,
    );
  }

  static AiConfigInferenceProvider createProvider() {
    return AiConfigInferenceProvider(
      id: 'test-provider',
      name: 'Test Provider',
      baseUrl: 'http://localhost:11434',
      apiKey: '',
      createdAt: DateTime.now(),
      inferenceProviderType: InferenceProviderType.ollama,
    );
  }
}

// Test helper: set up the sendMessage delegate to invoke the strategy
void stubSendMessageToInvokeStrategy({
  required MockConversationRepository repo,
  required ConversationManager manager,
  required List<ChatCompletionMessageToolCall> toolCalls,
}) {
  repo.sendMessageDelegate = ({
    required String conversationId,
    required String message,
    required String model,
    required AiConfigInferenceProvider provider,
    required InferenceRepositoryInterface inferenceRepo,
    List<ChatCompletionTool>? tools,
    double temperature = 0.7,
    ConversationStrategy? strategy,
  }) async {
    if (strategy != null) {
      await strategy.processToolCalls(
        toolCalls: toolCalls,
        manager: manager,
      );
    }
  };
}

void main() {
  late MockJournalRepository mockJournalRepo;
  late MockChecklistRepository mockChecklistRepo;
  late MockAutoChecklistService mockAutoChecklistService;
  late MockConversationRepository mockConversationRepo;
  late MockConversationManager mockConversationManager;
  late MockJournalDb mockJournalDb;
  late ProviderContainer container;
  late MockLoggingService mockLoggingService;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockOllamaInferenceRepository mockOllamaRepo;
  late LottiConversationProcessor processor;

  // Capture tool responses for verification
  final capturedToolResponses = <String, String>{};

  setUpAll(() {
    registerFallbackValue(DateTime.now());
    registerFallbackValue(AiConfigInferenceProvider(
      id: 'ollama',
      baseUrl: 'http://localhost:11434',
      apiKey: '',
      name: 'Ollama',
      createdAt: DateTime.now(),
      inferenceProviderType: InferenceProviderType.ollama,
    ));
    registerFallbackValue(TestDataFactory.createTask());
    registerFallbackValue(ConversationAction.complete);
    registerFallbackValue(<ChatCompletionMessageToolCall>[]);
    registerFallbackValue(const ChatCompletionMessage.user(
      content: ChatCompletionUserMessageContent.string('test'),
    ));
    registerFallbackValue(MockOllamaInferenceRepository());
  });

  setUp(() {
    capturedToolResponses.clear();

    mockJournalRepo = MockJournalRepository();
    mockChecklistRepo = MockChecklistRepository();
    mockAutoChecklistService = MockAutoChecklistService();
    mockConversationManager = MockConversationManager();
    mockConversationRepo = MockConversationRepository(mockConversationManager);
    mockJournalDb = MockJournalDb();
    mockLoggingService = MockLoggingService();
    mockPersistenceLogic = MockPersistenceLogic();
    mockOllamaRepo = MockOllamaInferenceRepository();

    // Set up getIt
    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic);

    // Create ProviderContainer with overrides
    container = ProviderContainer(
      overrides: [
        journalRepositoryProvider.overrideWithValue(mockJournalRepo),
        checklistRepositoryProvider.overrideWithValue(mockChecklistRepo),
        conversationRepositoryProvider.overrideWith(
          () => mockConversationRepo,
        ),
      ],
    );

    // Get a real Ref from the container
    final ref = container.read(testRefProvider);
    processor = LottiConversationProcessor(ref: ref);
  });

  tearDown(() {
    container.dispose();
    getIt.reset();
  });

  group('update_task_estimate', () {
    test('should update task estimate when currently null', () async {
      // Arrange
      final task = TestDataFactory.createTask();
      final model = TestDataFactory.createModel();
      final promptConfig = TestDataFactory.createPromptConfig();
      const prompt = 'This will take about 2 hours';

      when(() => mockConversationManager.messages).thenReturn([]);

      const toolCall = ChatCompletionMessageToolCall(
        id: 'tool-1',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'update_task_estimate',
          arguments:
              '{"minutes": 120, "reason": "User said 2 hours", "confidence": "high"}',
        ),
      );

      final streamController = StreamController<ConversationEvent>();
      addTearDown(() {
        unawaited(streamController.close());
      });
      when(() => mockConversationManager.events)
          .thenAnswer((_) => streamController.stream);

      when(() => mockConversationManager.addToolResponse(
            toolCallId: any(named: 'toolCallId'),
            response: any(named: 'response'),
          )).thenAnswer((invocation) {
        final toolCallId = invocation.namedArguments[#toolCallId] as String;
        final response = invocation.namedArguments[#response] as String;
        capturedToolResponses[toolCallId] = response;
      });

      stubSendMessageToInvokeStrategy(
        repo: mockConversationRepo,
        manager: mockConversationManager,
        toolCalls: const [toolCall],
      );

      // Mock journal repo update
      when(() => mockJournalRepo.updateJournalEntity(any()))
          .thenAnswer((_) async => true);

      when(() => mockJournalDb.journalEntityById(task.meta.id))
          .thenAnswer((_) async => task);

      // Act
      await processor.processPromptWithConversation(
        prompt: prompt,
        entity: task,
        task: task,
        model: model,
        provider: TestDataFactory.createProvider(),
        promptConfig: promptConfig,
        systemMessage: checklistUpdatesPrompt.systemMessage,
        tools: [],
        inferenceRepo: mockOllamaRepo,
        autoChecklistService: mockAutoChecklistService,
      );

      // Assert - capture and verify in one call
      final captured =
          verify(() => mockJournalRepo.updateJournalEntity(captureAny()))
              .captured;
      expect(captured, hasLength(1));
      final updatedTask = captured.first as Task;
      expect(updatedTask.data.estimate, equals(const Duration(minutes: 120)));

      // Verify tool response
      expect(capturedToolResponses['tool-1'],
          contains('Task estimate updated to 120 minutes'));
    });

    test('should skip update when estimate already exists', () async {
      // Arrange
      final task = TestDataFactory.createTask(
        estimate: const Duration(minutes: 60),
      );
      final model = TestDataFactory.createModel();
      final promptConfig = TestDataFactory.createPromptConfig();
      const prompt = 'This will take about 2 hours';

      when(() => mockConversationManager.messages).thenReturn([]);

      const toolCall = ChatCompletionMessageToolCall(
        id: 'tool-1',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'update_task_estimate',
          arguments:
              '{"minutes": 120, "reason": "User said 2 hours", "confidence": "high"}',
        ),
      );

      final streamController = StreamController<ConversationEvent>();
      addTearDown(() {
        unawaited(streamController.close());
      });
      when(() => mockConversationManager.events)
          .thenAnswer((_) => streamController.stream);

      when(() => mockConversationManager.addToolResponse(
            toolCallId: any(named: 'toolCallId'),
            response: any(named: 'response'),
          )).thenAnswer((invocation) {
        final toolCallId = invocation.namedArguments[#toolCallId] as String;
        final response = invocation.namedArguments[#response] as String;
        capturedToolResponses[toolCallId] = response;
      });

      stubSendMessageToInvokeStrategy(
        repo: mockConversationRepo,
        manager: mockConversationManager,
        toolCalls: const [toolCall],
      );

      when(() => mockJournalDb.journalEntityById(task.meta.id))
          .thenAnswer((_) async => task);

      // Act
      await processor.processPromptWithConversation(
        prompt: prompt,
        entity: task,
        task: task,
        model: model,
        provider: TestDataFactory.createProvider(),
        promptConfig: promptConfig,
        systemMessage: checklistUpdatesPrompt.systemMessage,
        tools: [],
        inferenceRepo: mockOllamaRepo,
        autoChecklistService: mockAutoChecklistService,
      );

      // Assert - should NOT call updateJournalEntity
      verifyNever(() => mockJournalRepo.updateJournalEntity(any()));

      // Verify tool response indicates skip
      expect(capturedToolResponses['tool-1'],
          contains('Estimate already set to 60 minutes'));
      expect(capturedToolResponses['tool-1'], contains('Skipped'));
    });

    test('should reject invalid minutes (negative)', () async {
      // Arrange
      final task = TestDataFactory.createTask();
      final model = TestDataFactory.createModel();
      final promptConfig = TestDataFactory.createPromptConfig();
      const prompt = 'This will take negative time';

      when(() => mockConversationManager.messages).thenReturn([]);

      const toolCall = ChatCompletionMessageToolCall(
        id: 'tool-1',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'update_task_estimate',
          arguments:
              '{"minutes": -10, "reason": "Invalid", "confidence": "low"}',
        ),
      );

      final streamController = StreamController<ConversationEvent>();
      addTearDown(() {
        unawaited(streamController.close());
      });
      when(() => mockConversationManager.events)
          .thenAnswer((_) => streamController.stream);

      when(() => mockConversationManager.addToolResponse(
            toolCallId: any(named: 'toolCallId'),
            response: any(named: 'response'),
          )).thenAnswer((invocation) {
        final toolCallId = invocation.namedArguments[#toolCallId] as String;
        final response = invocation.namedArguments[#response] as String;
        capturedToolResponses[toolCallId] = response;
      });

      stubSendMessageToInvokeStrategy(
        repo: mockConversationRepo,
        manager: mockConversationManager,
        toolCalls: const [toolCall],
      );

      when(() => mockJournalDb.journalEntityById(task.meta.id))
          .thenAnswer((_) async => task);

      // Act
      await processor.processPromptWithConversation(
        prompt: prompt,
        entity: task,
        task: task,
        model: model,
        provider: TestDataFactory.createProvider(),
        promptConfig: promptConfig,
        systemMessage: checklistUpdatesPrompt.systemMessage,
        tools: [],
        inferenceRepo: mockOllamaRepo,
        autoChecklistService: mockAutoChecklistService,
      );

      // Assert - should NOT call updateJournalEntity
      verifyNever(() => mockJournalRepo.updateJournalEntity(any()));

      // Verify tool response indicates error
      expect(capturedToolResponses['tool-1'], contains('Invalid estimate'));
      expect(capturedToolResponses['tool-1'],
          contains('minutes must be a positive integer'));
    });

    test('should update task estimate when currently zero (treat as not set)',
        () async {
      // Arrange - task with zero duration (should be treated as "not set")
      final task = TestDataFactory.createTask(
        estimate: Duration.zero,
      );
      final model = TestDataFactory.createModel();
      final promptConfig = TestDataFactory.createPromptConfig();
      const prompt = 'This will take about 1 hour';

      when(() => mockConversationManager.messages).thenReturn([]);

      const toolCall = ChatCompletionMessageToolCall(
        id: 'tool-1',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'update_task_estimate',
          arguments:
              '{"minutes": 60, "reason": "User said 1 hour", "confidence": "high"}',
        ),
      );

      final streamController = StreamController<ConversationEvent>();
      addTearDown(() {
        unawaited(streamController.close());
      });
      when(() => mockConversationManager.events)
          .thenAnswer((_) => streamController.stream);

      when(() => mockConversationManager.addToolResponse(
            toolCallId: any(named: 'toolCallId'),
            response: any(named: 'response'),
          )).thenAnswer((invocation) {
        final toolCallId = invocation.namedArguments[#toolCallId] as String;
        final response = invocation.namedArguments[#response] as String;
        capturedToolResponses[toolCallId] = response;
      });

      stubSendMessageToInvokeStrategy(
        repo: mockConversationRepo,
        manager: mockConversationManager,
        toolCalls: const [toolCall],
      );

      // Mock journal repo update
      when(() => mockJournalRepo.updateJournalEntity(any()))
          .thenAnswer((_) async => true);

      when(() => mockJournalDb.journalEntityById(task.meta.id))
          .thenAnswer((_) async => task);

      // Act
      await processor.processPromptWithConversation(
        prompt: prompt,
        entity: task,
        task: task,
        model: model,
        provider: TestDataFactory.createProvider(),
        promptConfig: promptConfig,
        systemMessage: checklistUpdatesPrompt.systemMessage,
        tools: [],
        inferenceRepo: mockOllamaRepo,
        autoChecklistService: mockAutoChecklistService,
      );

      // Assert - should update because zero is treated as "not set"
      final captured =
          verify(() => mockJournalRepo.updateJournalEntity(captureAny()))
              .captured;
      expect(captured, hasLength(1));
      final updatedTask = captured.first as Task;
      expect(updatedTask.data.estimate, equals(const Duration(minutes: 60)));

      // Verify tool response
      expect(capturedToolResponses['tool-1'],
          contains('Task estimate updated to 60 minutes'));
    });

    test('should reject zero minutes', () async {
      // Arrange
      final task = TestDataFactory.createTask();
      final model = TestDataFactory.createModel();
      final promptConfig = TestDataFactory.createPromptConfig();
      const prompt = 'This will take zero time';

      when(() => mockConversationManager.messages).thenReturn([]);

      const toolCall = ChatCompletionMessageToolCall(
        id: 'tool-1',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'update_task_estimate',
          arguments:
              '{"minutes": 0, "reason": "Zero time", "confidence": "low"}',
        ),
      );

      final streamController = StreamController<ConversationEvent>();
      addTearDown(() {
        unawaited(streamController.close());
      });
      when(() => mockConversationManager.events)
          .thenAnswer((_) => streamController.stream);

      when(() => mockConversationManager.addToolResponse(
            toolCallId: any(named: 'toolCallId'),
            response: any(named: 'response'),
          )).thenAnswer((invocation) {
        final toolCallId = invocation.namedArguments[#toolCallId] as String;
        final response = invocation.namedArguments[#response] as String;
        capturedToolResponses[toolCallId] = response;
      });

      stubSendMessageToInvokeStrategy(
        repo: mockConversationRepo,
        manager: mockConversationManager,
        toolCalls: const [toolCall],
      );

      when(() => mockJournalDb.journalEntityById(task.meta.id))
          .thenAnswer((_) async => task);

      // Act
      await processor.processPromptWithConversation(
        prompt: prompt,
        entity: task,
        task: task,
        model: model,
        provider: TestDataFactory.createProvider(),
        promptConfig: promptConfig,
        systemMessage: checklistUpdatesPrompt.systemMessage,
        tools: [],
        inferenceRepo: mockOllamaRepo,
        autoChecklistService: mockAutoChecklistService,
      );

      // Assert - should NOT call updateJournalEntity
      verifyNever(() => mockJournalRepo.updateJournalEntity(any()));

      // Verify tool response indicates error
      expect(capturedToolResponses['tool-1'], contains('Invalid estimate'));
    });
  });

  group('update_task_due_date', () {
    test('should update task due date when currently null', () async {
      // Arrange
      final task = TestDataFactory.createTask();
      final model = TestDataFactory.createModel();
      final promptConfig = TestDataFactory.createPromptConfig();
      const prompt = 'This is due by Friday';

      when(() => mockConversationManager.messages).thenReturn([]);

      const toolCall = ChatCompletionMessageToolCall(
        id: 'tool-1',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'update_task_due_date',
          arguments:
              '{"dueDate": "2024-01-19", "reason": "User said Friday", "confidence": "high"}',
        ),
      );

      final streamController = StreamController<ConversationEvent>();
      addTearDown(() {
        unawaited(streamController.close());
      });
      when(() => mockConversationManager.events)
          .thenAnswer((_) => streamController.stream);

      when(() => mockConversationManager.addToolResponse(
            toolCallId: any(named: 'toolCallId'),
            response: any(named: 'response'),
          )).thenAnswer((invocation) {
        final toolCallId = invocation.namedArguments[#toolCallId] as String;
        final response = invocation.namedArguments[#response] as String;
        capturedToolResponses[toolCallId] = response;
      });

      stubSendMessageToInvokeStrategy(
        repo: mockConversationRepo,
        manager: mockConversationManager,
        toolCalls: const [toolCall],
      );

      when(() => mockJournalRepo.updateJournalEntity(any()))
          .thenAnswer((_) async => true);

      when(() => mockJournalDb.journalEntityById(task.meta.id))
          .thenAnswer((_) async => task);

      // Act
      await processor.processPromptWithConversation(
        prompt: prompt,
        entity: task,
        task: task,
        model: model,
        provider: TestDataFactory.createProvider(),
        promptConfig: promptConfig,
        systemMessage: checklistUpdatesPrompt.systemMessage,
        tools: [],
        inferenceRepo: mockOllamaRepo,
        autoChecklistService: mockAutoChecklistService,
      );

      // Assert - capture and verify in one call
      final captured =
          verify(() => mockJournalRepo.updateJournalEntity(captureAny()))
              .captured;
      expect(captured, hasLength(1));
      final updatedTask = captured.first as Task;
      expect(updatedTask.data.due, equals(DateTime(2024, 1, 19)));

      // Verify tool response
      expect(capturedToolResponses['tool-1'],
          contains('Task due date updated to 2024-01-19'));
    });

    test('should skip update when due date already exists', () async {
      // Arrange
      final existingDueDate = DateTime(2024, 1, 20);
      final task = TestDataFactory.createTask(due: existingDueDate);
      final model = TestDataFactory.createModel();
      final promptConfig = TestDataFactory.createPromptConfig();
      const prompt = 'This is due by Friday';

      when(() => mockConversationManager.messages).thenReturn([]);

      const toolCall = ChatCompletionMessageToolCall(
        id: 'tool-1',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'update_task_due_date',
          arguments:
              '{"dueDate": "2024-01-19", "reason": "User said Friday", "confidence": "high"}',
        ),
      );

      final streamController = StreamController<ConversationEvent>();
      addTearDown(() {
        unawaited(streamController.close());
      });
      when(() => mockConversationManager.events)
          .thenAnswer((_) => streamController.stream);

      when(() => mockConversationManager.addToolResponse(
            toolCallId: any(named: 'toolCallId'),
            response: any(named: 'response'),
          )).thenAnswer((invocation) {
        final toolCallId = invocation.namedArguments[#toolCallId] as String;
        final response = invocation.namedArguments[#response] as String;
        capturedToolResponses[toolCallId] = response;
      });

      stubSendMessageToInvokeStrategy(
        repo: mockConversationRepo,
        manager: mockConversationManager,
        toolCalls: const [toolCall],
      );

      when(() => mockJournalDb.journalEntityById(task.meta.id))
          .thenAnswer((_) async => task);

      // Act
      await processor.processPromptWithConversation(
        prompt: prompt,
        entity: task,
        task: task,
        model: model,
        provider: TestDataFactory.createProvider(),
        promptConfig: promptConfig,
        systemMessage: checklistUpdatesPrompt.systemMessage,
        tools: [],
        inferenceRepo: mockOllamaRepo,
        autoChecklistService: mockAutoChecklistService,
      );

      // Assert - should NOT call updateJournalEntity
      verifyNever(() => mockJournalRepo.updateJournalEntity(any()));

      // Verify tool response indicates skip
      expect(capturedToolResponses['tool-1'],
          contains('Due date already set to 2024-01-20'));
      expect(capturedToolResponses['tool-1'], contains('Skipped'));
    });

    test('should reject invalid date format', () async {
      // Arrange
      final task = TestDataFactory.createTask();
      final model = TestDataFactory.createModel();
      final promptConfig = TestDataFactory.createPromptConfig();
      const prompt = 'This is due sometime';

      when(() => mockConversationManager.messages).thenReturn([]);

      const toolCall = ChatCompletionMessageToolCall(
        id: 'tool-1',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'update_task_due_date',
          arguments:
              '{"dueDate": "not-a-date", "reason": "Invalid format", "confidence": "low"}',
        ),
      );

      final streamController = StreamController<ConversationEvent>();
      addTearDown(() {
        unawaited(streamController.close());
      });
      when(() => mockConversationManager.events)
          .thenAnswer((_) => streamController.stream);

      when(() => mockConversationManager.addToolResponse(
            toolCallId: any(named: 'toolCallId'),
            response: any(named: 'response'),
          )).thenAnswer((invocation) {
        final toolCallId = invocation.namedArguments[#toolCallId] as String;
        final response = invocation.namedArguments[#response] as String;
        capturedToolResponses[toolCallId] = response;
      });

      stubSendMessageToInvokeStrategy(
        repo: mockConversationRepo,
        manager: mockConversationManager,
        toolCalls: const [toolCall],
      );

      when(() => mockJournalDb.journalEntityById(task.meta.id))
          .thenAnswer((_) async => task);

      // Act
      await processor.processPromptWithConversation(
        prompt: prompt,
        entity: task,
        task: task,
        model: model,
        provider: TestDataFactory.createProvider(),
        promptConfig: promptConfig,
        systemMessage: checklistUpdatesPrompt.systemMessage,
        tools: [],
        inferenceRepo: mockOllamaRepo,
        autoChecklistService: mockAutoChecklistService,
      );

      // Assert - should NOT call updateJournalEntity
      verifyNever(() => mockJournalRepo.updateJournalEntity(any()));

      // Verify tool response indicates error
      expect(
          capturedToolResponses['tool-1'], contains('Invalid due date format'));
      expect(capturedToolResponses['tool-1'], contains('ISO 8601'));
    });

    test('should reject empty date string', () async {
      // Arrange
      final task = TestDataFactory.createTask();
      final model = TestDataFactory.createModel();
      final promptConfig = TestDataFactory.createPromptConfig();
      const prompt = 'This is due sometime';

      when(() => mockConversationManager.messages).thenReturn([]);

      const toolCall = ChatCompletionMessageToolCall(
        id: 'tool-1',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'update_task_due_date',
          arguments:
              '{"dueDate": "", "reason": "Empty date", "confidence": "low"}',
        ),
      );

      final streamController = StreamController<ConversationEvent>();
      addTearDown(() {
        unawaited(streamController.close());
      });
      when(() => mockConversationManager.events)
          .thenAnswer((_) => streamController.stream);

      when(() => mockConversationManager.addToolResponse(
            toolCallId: any(named: 'toolCallId'),
            response: any(named: 'response'),
          )).thenAnswer((invocation) {
        final toolCallId = invocation.namedArguments[#toolCallId] as String;
        final response = invocation.namedArguments[#response] as String;
        capturedToolResponses[toolCallId] = response;
      });

      stubSendMessageToInvokeStrategy(
        repo: mockConversationRepo,
        manager: mockConversationManager,
        toolCalls: const [toolCall],
      );

      when(() => mockJournalDb.journalEntityById(task.meta.id))
          .thenAnswer((_) async => task);

      // Act
      await processor.processPromptWithConversation(
        prompt: prompt,
        entity: task,
        task: task,
        model: model,
        provider: TestDataFactory.createProvider(),
        promptConfig: promptConfig,
        systemMessage: checklistUpdatesPrompt.systemMessage,
        tools: [],
        inferenceRepo: mockOllamaRepo,
        autoChecklistService: mockAutoChecklistService,
      );

      // Assert - should NOT call updateJournalEntity
      verifyNever(() => mockJournalRepo.updateJournalEntity(any()));

      // Verify tool response indicates error
      expect(capturedToolResponses['tool-1'], contains('Invalid due date'));
      expect(
          capturedToolResponses['tool-1'], contains('date string is required'));
    });
  });

  group('TaskFunctions.getTools', () {
    test('should include update_task_estimate function', () {
      final tools = TaskFunctions.getTools();
      final estimateTool = tools.firstWhere(
        (t) => t.function.name == TaskFunctions.updateTaskEstimate,
        orElse: () => throw Exception('update_task_estimate not found'),
      );

      expect(estimateTool.function.name, equals('update_task_estimate'));
      expect(estimateTool.function.description, contains('time estimate'));
      expect(estimateTool.function.parameters, isNotNull);
      expect(
          estimateTool.function.parameters!['properties'], contains('minutes'));
      expect(
          estimateTool.function.parameters!['properties'], contains('reason'));
      expect(estimateTool.function.parameters!['properties'],
          contains('confidence'));
    });

    test('should include update_task_due_date function', () {
      final tools = TaskFunctions.getTools();
      final dueDateTool = tools.firstWhere(
        (t) => t.function.name == TaskFunctions.updateTaskDueDate,
        orElse: () => throw Exception('update_task_due_date not found'),
      );

      expect(dueDateTool.function.name, equals('update_task_due_date'));
      expect(dueDateTool.function.description, contains('due date'));
      expect(dueDateTool.function.description, contains('Current date:'));
      expect(dueDateTool.function.parameters, isNotNull);
      expect(
          dueDateTool.function.parameters!['properties'], contains('dueDate'));
      expect(
          dueDateTool.function.parameters!['properties'], contains('reason'));
      expect(dueDateTool.function.parameters!['properties'],
          contains('confidence'));
    });

    test('should inject current date into due date function description', () {
      final tools = TaskFunctions.getTools();
      final dueDateTool = tools.firstWhere(
        (t) => t.function.name == TaskFunctions.updateTaskDueDate,
      );

      final description = dueDateTool.function.description!;
      // Should contain a date in YYYY-MM-DD format
      expect(description, matches(RegExp(r'Current date: \d{4}-\d{2}-\d{2}')));
    });
  });
}
