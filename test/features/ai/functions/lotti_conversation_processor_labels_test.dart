// ignore_for_file: avoid_redundant_argument_values, cascade_invocations
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/functions/lotti_conversation_processor.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/services/label_assignment_event_service.dart';
import 'package:lotti/features/labels/services/label_assignment_rate_limiter.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../test_utils.dart';

class MockJournalRepository extends Mock implements JournalRepository {}

/// Mock ConversationRepository that extends the real class.
/// In Riverpod 3, Notifier classes can't be mocked with `Mock implements`
/// because they have internal state that's accessed during initialization.
class MockConversationRepository extends ConversationRepository {
  MockConversationRepository(this._mockManager);

  final MockConversationManager _mockManager;
  final List<String> deletedConversationIds = [];

  /// Delegate for sendMessage - set this in tests to control behavior
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
  void build() {
    // No-op for mock
  }

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

class MockLabelsRepository extends Mock implements LabelsRepository {}

class FakeInferenceRepo extends Fake implements InferenceRepositoryInterface {}

void main() {
  late MockJournalRepository mockJournalRepo;
  late MockConversationRepository mockConversationRepo;
  late MockConversationManager mockConversationManager;
  late MockJournalDb mockJournalDb;
  late ProviderContainer container;
  late MockLoggingService mockLoggingService;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockLabelsRepository mockLabelsRepo;
  late ChecklistRepository mockChecklistRepo;
  late LottiConversationProcessor processor;

  setUpAll(() {
    registerFallbackValue(const ChatCompletionMessage.user(
      content: ChatCompletionUserMessageContent.string('test'),
    ));
    registerFallbackValue(ConversationAction.complete);
    registerFallbackValue(AiConfigInferenceProvider(
      id: 'prov',
      name: 'Test',
      baseUrl: 'http://localhost',
      apiKey: '',
      createdAt: DateTime.now(),
      inferenceProviderType: InferenceProviderType.ollama,
    ));
    registerFallbackValue(FakeInferenceRepo());
  });

  setUp(() {
    mockJournalRepo = MockJournalRepository();
    // Create MockConversationManager first since MockConversationRepository needs it
    mockConversationManager = MockConversationManager();
    mockConversationRepo = MockConversationRepository(mockConversationManager);
    mockJournalDb = MockJournalDb();
    mockLoggingService = MockLoggingService();
    mockPersistenceLogic = MockPersistenceLogic();
    mockLabelsRepo = MockLabelsRepository();
    mockChecklistRepo = MockChecklistRepositoryBase();

    // Set up getIt
    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
      ..registerSingleton<LabelAssignmentRateLimiter>(
          LabelAssignmentRateLimiter())
      // Also register mock LabelsRepository for processor fallback
      ..registerSingleton<LabelsRepository>(mockLabelsRepo);
    // Event service needed by LabelAssignmentProcessor for UI notifications
    getIt.registerSingleton<LabelAssignmentEventService>(
      LabelAssignmentEventService(),
    );
    // Ensure no cross-test rate limiting state persists
    getIt<LabelAssignmentRateLimiter>().clearHistory();

    // Set up container with provider overrides
    container = ProviderContainer(
      overrides: [
        journalRepositoryProvider.overrideWithValue(mockJournalRepo),
        labelsRepositoryProvider.overrideWithValue(mockLabelsRepo),
        checklistRepositoryProvider.overrideWithValue(mockChecklistRepo),
        conversationRepositoryProvider.overrideWith(() => mockConversationRepo),
      ],
    );

    final ref = container.read(testRefProvider);
    processor = LottiConversationProcessor(ref: ref);
  });

  tearDown(() {
    container.dispose();
    getIt.reset();
  });

  Task makeTask() => Task(
        meta: Metadata(
          id: 't1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          categoryId: 'cat',
        ),
        data: TaskData(
          title: 'Task',
          status: TaskStatus.open(
            id: 's',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          statusHistory: const [],
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
      );

  ChatCompletionMessageToolCall makeCall(List<String> ids) =>
      ChatCompletionMessageToolCall(
        id: 'tool-assign',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'assign_task_labels',
          arguments: jsonEncode({'labelIds': ids}),
        ),
      );

  AiConfigModel makeModel() => AiConfigModel(
        id: 'm1',
        name: 'test',
        providerModelId: 'test',
        inferenceProviderId: 'prov',
        createdAt: DateTime.now(),
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
        supportsFunctionCalling: true,
        maxCompletionTokens: 1000,
      );

  AiConfigInferenceProvider makeProvider() => AiConfigInferenceProvider(
        id: 'prov',
        name: 'Test',
        baseUrl: 'http://localhost',
        apiKey: '',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.ollama,
      );

  AiConfigPrompt makePrompt() => AiConfigPrompt(
        id: 'p1',
        name: 'Checklist Updates',
        systemMessage: 'sys',
        userMessage: 'user',
        defaultModelId: 'm1',
        modelIds: const ['m1'],
        createdAt: DateTime.now(),
        useReasoning: false,
        requiredInputData: const [],
        aiResponseType: AiResponseType.checklistUpdates,
      );

  test(
      'conversation processes assign_task_labels and returns structured response',
      () async {
    final task = makeTask();

    // DB lookups: two valid labels, one invalid
    when(() => mockJournalDb.getLabelDefinitionById('A'))
        .thenAnswer((_) async => LabelDefinition(
              id: 'A',
              name: 'A',
              color: '#000',
              description: null,
              sortOrder: null,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              vectorClock: null,
              private: false,
            ));
    when(() => mockJournalDb.getLabelDefinitionById('B'))
        .thenAnswer((_) async => LabelDefinition(
              id: 'B',
              name: 'B',
              color: '#000',
              description: null,
              sortOrder: null,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              vectorClock: null,
              private: false,
            ));
    when(() => mockJournalDb.getLabelDefinitionById('X'))
        .thenAnswer((_) async => null);

    // Conversation wiring - MockConversationRepository provides createConversation and getConversation
    when(() => mockConversationManager.messages).thenReturn([]);
    when(() => mockConversationManager.addToolResponse(
          toolCallId: any(named: 'toolCallId'),
          response: any(named: 'response'),
        )).thenAnswer((_) {});

    // sendMessage triggers strategy processing of our tool call
    mockConversationRepo.sendMessageDelegate = ({
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
          toolCalls: [
            makeCall(['A', 'B', 'X'])
          ],
          manager: mockConversationManager,
        );
      }
    };

    // Stub addLabels to avoid null futures and ensure success
    when(() => mockLabelsRepo.addLabels(
          journalEntityId: any(named: 'journalEntityId'),
          addedLabelIds: any(named: 'addedLabelIds'),
        )).thenAnswer((_) async => true);

    final result = await processor.processPromptWithConversation(
      prompt: 'user',
      entity: task,
      task: task,
      model: makeModel(),
      provider: makeProvider(),
      promptConfig: makePrompt(),
      systemMessage: 'sys',
      tools: const [],
      inferenceRepo: FakeInferenceRepo(),
    );

    expect(result.hadErrors, isFalse);
    // Verify repository was called and capture addedLabelIds
    final captured = verify(() => mockLabelsRepo.addLabels(
          journalEntityId: task.id,
          addedLabelIds: captureAny(named: 'addedLabelIds'),
        )).captured;
    expect(captured, isNotEmpty);
    final ids = (captured.first as List).cast<String>();
    expect(ids, containsAll(['A', 'B']));
    // Verify a tool response was sent
    verify(() => mockConversationManager.addToolResponse(
          toolCallId: any(named: 'toolCallId'),
          response: any(named: 'response'),
        )).called(greaterThanOrEqualTo(1));
  });

  test(
      'conversation selects top 3 by confidence and omits low when labels array provided',
      () async {
    final task = makeTask();

    // Define label IDs used in the mixed confidence payload
    const vh1 = 'very-high-1';
    const h1 = 'high-1';
    const h2 = 'high-2';
    const m1 = 'medium-1';
    const low1 = 'low-1';

    Future<LabelDefinition> def(String id) async => LabelDefinition(
          id: id,
          name: id,
          color: '#000',
          description: null,
          sortOrder: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          vectorClock: null,
          private: false,
        );

    // All proposed labels exist and are not deleted (global)
    when(() => mockJournalDb.getLabelDefinitionById(vh1))
        .thenAnswer((_) => def(vh1));
    when(() => mockJournalDb.getLabelDefinitionById(h1))
        .thenAnswer((_) => def(h1));
    when(() => mockJournalDb.getLabelDefinitionById(h2))
        .thenAnswer((_) => def(h2));
    when(() => mockJournalDb.getLabelDefinitionById(m1))
        .thenAnswer((_) => def(m1));
    when(() => mockJournalDb.getLabelDefinitionById(low1))
        .thenAnswer((_) => def(low1));

    // Wire conversation - MockConversationRepository provides createConversation and getConversation
    when(() => mockConversationManager.messages).thenReturn([]);

    // Capture tool response
    String? toolResponse;
    when(() => mockConversationManager.addToolResponse(
          toolCallId: any(named: 'toolCallId'),
          response: captureAny(named: 'response'),
        )).thenAnswer((invocation) {
      toolResponse = invocation.namedArguments[#response] as String;
      return;
    });

    // sendMessage triggers strategy with the new preferred labels array
    mockConversationRepo.sendMessageDelegate = ({
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
          toolCalls: [
            ChatCompletionMessageToolCall(
              id: 'call-mixed',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'assign_task_labels',
                arguments: jsonEncode({
                  'labels': [
                    {'id': h1, 'confidence': 'high'},
                    {'id': low1, 'confidence': 'low'},
                    {'id': vh1, 'confidence': 'very_high'},
                    {'id': m1, 'confidence': 'medium'},
                    {'id': h2, 'confidence': 'high'},
                  ]
                }),
              ),
            ),
          ],
          manager: mockConversationManager,
        );
      }
    };

    // Repo call should persist selected labels
    when(() => mockLabelsRepo.addLabels(
          journalEntityId: any(named: 'journalEntityId'),
          addedLabelIds: any(named: 'addedLabelIds'),
        )).thenAnswer((_) async => true);

    await processor.processPromptWithConversation(
      prompt: 'user',
      entity: task,
      task: task,
      model: makeModel(),
      provider: makeProvider(),
      promptConfig: makePrompt(),
      systemMessage: 'sys',
      tools: const [],
      inferenceRepo: FakeInferenceRepo(),
    );

    // Verify persistence received the top-3 by confidence in order: vh1, h1, h2
    final captured = verify(() => mockLabelsRepo.addLabels(
          journalEntityId: task.id,
          addedLabelIds: captureAny(named: 'addedLabelIds'),
        )).captured;
    expect(captured, isNotEmpty);
    final ids = (captured.first as List).cast<String>();
    expect(ids, equals([vh1, h1, h2]));

    // Verify tool response is present
    expect(toolResponse, isNotNull);
    final decoded = jsonDecode(toolResponse!) as Map<String, dynamic>;
    expect(decoded['function'], 'assign_task_labels');
    final result = Map<String, dynamic>.from(decoded['result'] as Map);
    expect((result['assigned'] as List).cast<String>(), equals([vh1, h1, h2]));
  });

  test('suppression no-op when all requested labels are suppressed', () async {
    // Task with suppression set for X and Y
    final task = makeTask().copyWith(
      data: makeTask().data.copyWith(
        aiSuppressedLabelIds: {'X', 'Y'},
      ),
    );

    // Both labels exist (global); should be filtered by caller due to suppression
    when(() => mockJournalDb.getLabelDefinitionById('X')).thenAnswer(
      (_) async => LabelDefinition(
        id: 'X',
        name: 'X',
        color: '#000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: false,
      ),
    );
    when(() => mockJournalDb.getLabelDefinitionById('Y')).thenAnswer(
      (_) async => LabelDefinition(
        id: 'Y',
        name: 'Y',
        color: '#000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: false,
      ),
    );

    // Conversation wiring - MockConversationRepository provides createConversation and getConversation
    when(() => mockConversationManager.messages).thenReturn([]);

    String? toolResponse;
    when(() => mockConversationManager.addToolResponse(
          toolCallId: any(named: 'toolCallId'),
          response: any(named: 'response'),
        )).thenAnswer((inv) {
      toolResponse = inv.namedArguments[#response] as String?;
    });

    mockConversationRepo.sendMessageDelegate = ({
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
          toolCalls: [
            makeCall(['X', 'Y'])
          ],
          manager: mockConversationManager,
        );
      }
    };

    // No labels should be persisted (short-circuit)
    await processor.processPromptWithConversation(
      prompt: 'user',
      entity: task,
      task: task,
      model: makeModel(),
      provider: makeProvider(),
      promptConfig: makePrompt(),
      systemMessage: 'sys',
      tools: const [],
      inferenceRepo: FakeInferenceRepo(),
    );

    verifyNever(() => mockLabelsRepo.addLabels(
          journalEntityId: any(named: 'journalEntityId'),
          addedLabelIds: any(named: 'addedLabelIds'),
        ));
    expect(toolResponse, isNotNull);
    final decoded = jsonDecode(toolResponse!) as Map<String, dynamic>;
    expect(decoded['function'], 'assign_task_labels');
    final result = Map<String, dynamic>.from(decoded['result'] as Map);
    expect((result['assigned'] as List).cast<String>(), isEmpty);
    final skipped = (result['skipped'] as List).cast<Map<String, dynamic>>();
    // Both X and Y should be skipped for reason 'suppressed'
    final reasons = {for (final m in skipped) m['id'] as String: m['reason']};
    expect(reasons['X'], 'suppressed');
    expect(reasons['Y'], 'suppressed');
  });

  test('handles retry with corrected label IDs in conversation', () async {
    final task = makeTask();

    // First attempt: mix of valid and invalid
    when(() => mockJournalDb.getLabelDefinitionById('valid-1'))
        .thenAnswer((_) async => LabelDefinition(
              id: 'valid-1',
              name: 'Valid 1',
              color: '#000',
              description: null,
              sortOrder: null,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              vectorClock: null,
              private: false,
            ));
    when(() => mockJournalDb.getLabelDefinitionById('valid-2'))
        .thenAnswer((_) async => LabelDefinition(
              id: 'valid-2',
              name: 'Valid 2',
              color: '#000',
              description: null,
              sortOrder: null,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              vectorClock: null,
              private: false,
            ));
    when(() => mockJournalDb.getLabelDefinitionById('typo-id'))
        .thenAnswer((_) async => null);
    when(() => mockJournalDb.getLabelDefinitionById('deleted-id'))
        .thenAnswer((_) async => LabelDefinition(
              id: 'deleted-id',
              name: 'Deleted',
              color: '#000',
              description: null,
              sortOrder: null,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              vectorClock: null,
              private: false,
              deletedAt: DateTime.now(),
            ));

    // Second attempt: all valid
    when(() => mockJournalDb.getLabelDefinitionById('valid-3'))
        .thenAnswer((_) async => LabelDefinition(
              id: 'valid-3',
              name: 'Valid 3',
              color: '#000',
              description: null,
              sortOrder: null,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              vectorClock: null,
              private: false,
            ));
    when(() => mockJournalDb.getLabelDefinitionById('valid-4'))
        .thenAnswer((_) async => LabelDefinition(
              id: 'valid-4',
              name: 'Valid 4',
              color: '#000',
              description: null,
              sortOrder: null,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              vectorClock: null,
              private: false,
            ));

    // Repository should succeed
    when(() => mockLabelsRepo.addLabels(
          journalEntityId: any(named: 'journalEntityId'),
          addedLabelIds: any(named: 'addedLabelIds'),
        )).thenAnswer((_) async => true);

    // First attempt conversation wiring - MockConversationRepository provides createConversation and getConversation
    when(() => mockConversationManager.messages).thenReturn([]);

    String? firstResponse;
    when(() => mockConversationManager.addToolResponse(
          toolCallId: any(named: 'toolCallId'),
          response: captureAny(named: 'response'),
        )).thenAnswer((invocation) {
      firstResponse = invocation.namedArguments[#response] as String;
      return;
    });

    mockConversationRepo.sendMessageDelegate = ({
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
          toolCalls: [
            ChatCompletionMessageToolCall(
              id: 'call-1',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'assign_task_labels',
                arguments: jsonEncode({
                  // With Phase 2 cap (≤3), ensure the deleted label is within the first three
                  'labelIds': ['valid-1', 'typo-id', 'deleted-id', 'valid-2'],
                }),
              ),
            ),
          ],
          manager: mockConversationManager,
        );
      }
    };

    await processor.processPromptWithConversation(
      prompt: 'user',
      entity: task,
      task: task,
      model: makeModel(),
      provider: makeProvider(),
      promptConfig: makePrompt(),
      systemMessage: 'sys',
      tools: const [],
      inferenceRepo: FakeInferenceRepo(),
    );

    final firstResult = jsonDecode(firstResponse!) as Map<String, dynamic>;
    final firstFunction = firstResult['function'] as String;
    final firstResMap = Map<String, dynamic>.from(firstResult['result'] as Map);
    final firstAssigned = (firstResMap['assigned'] as List).cast<String>();
    final firstInvalid = (firstResMap['invalid'] as List).cast<String>();
    expect(firstFunction, 'assign_task_labels');
    // With Phase 2 cap (≤3) and selection order, only 'valid-1' is assigned.
    expect(firstAssigned, equals(['valid-1']));
    expect(firstInvalid, containsAll(['typo-id', 'deleted-id']));

    // Clear rate limiter before retry to allow second assignment
    getIt<LabelAssignmentRateLimiter>().clearHistory();

    // Second attempt with corrected IDs - MockConversationRepository provides createConversation and getConversation

    String? secondResponse;
    when(() => mockConversationManager.addToolResponse(
          toolCallId: any(named: 'toolCallId'),
          response: captureAny(named: 'response'),
        )).thenAnswer((invocation) {
      secondResponse = invocation.namedArguments[#response] as String;
      return;
    });

    mockConversationRepo.sendMessageDelegate = ({
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
          toolCalls: [
            ChatCompletionMessageToolCall(
              id: 'call-2',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'assign_task_labels',
                arguments: jsonEncode({
                  'labelIds': ['valid-3', 'valid-4'],
                }),
              ),
            ),
          ],
          manager: mockConversationManager,
        );
      }
    };

    await processor.processPromptWithConversation(
      prompt: 'user',
      entity: task,
      task: task,
      model: makeModel(),
      provider: makeProvider(),
      promptConfig: makePrompt(),
      systemMessage: 'sys',
      tools: const [],
      inferenceRepo: FakeInferenceRepo(),
    );

    final secondResult = jsonDecode(secondResponse!) as Map<String, dynamic>;
    final secondResMap =
        Map<String, dynamic>.from(secondResult['result'] as Map);
    final secondAssigned = (secondResMap['assigned'] as List).cast<String>();
    final secondInvalid = (secondResMap['invalid'] as List).cast<String>();
    expect(secondAssigned, equals(['valid-3', 'valid-4']));
    expect(secondInvalid, isEmpty);
  });

  test('handles conversation interruption and recovery', () async {
    final task = makeTask();

    when(() => mockJournalDb.getLabelDefinitionById('label-1'))
        .thenAnswer((_) async => LabelDefinition(
              id: 'label-1',
              name: 'Label 1',
              color: '#000',
              description: null,
              sortOrder: null,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              vectorClock: null,
              private: false,
            ));
    when(() => mockJournalDb.getLabelDefinitionById('label-2'))
        .thenAnswer((_) async => LabelDefinition(
              id: 'label-2',
              name: 'Label 2',
              color: '#000',
              description: null,
              sortOrder: null,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              vectorClock: null,
              private: false,
            ));

    // Simulate repository failure during persistence
    when(() => mockLabelsRepo.addLabels(
          journalEntityId: any(named: 'journalEntityId'),
          addedLabelIds: any(named: 'addedLabelIds'),
        )).thenThrow(Exception('Network error'));

    // MockConversationRepository provides createConversation and getConversation
    when(() => mockConversationManager.messages).thenReturn([]);

    String? errorResponse;
    when(() => mockConversationManager.addToolResponse(
          toolCallId: any(named: 'toolCallId'),
          response: captureAny(named: 'response'),
        )).thenAnswer((invocation) {
      errorResponse = invocation.namedArguments[#response] as String;
      return;
    });

    mockConversationRepo.sendMessageDelegate = ({
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
          toolCalls: [
            ChatCompletionMessageToolCall(
              id: 'call-err',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'assign_task_labels',
                arguments: jsonEncode({
                  'labelIds': ['label-1', 'label-2'],
                }),
              ),
            ),
          ],
          manager: mockConversationManager,
        );
      }
    };

    await processor.processPromptWithConversation(
      prompt: 'user',
      entity: task,
      task: task,
      model: makeModel(),
      provider: makeProvider(),
      promptConfig: makePrompt(),
      systemMessage: 'sys',
      tools: const [],
      inferenceRepo: FakeInferenceRepo(),
    );

    expect(errorResponse, isNotNull);
    // Should be a structured JSON error payload containing the exception text
    final decoded = jsonDecode(errorResponse!) as Map<String, dynamic>;
    expect(decoded['function'], 'assign_task_labels');
    expect(decoded['error'].toString(), contains('Network error'));
  });
}

// Minimal concrete mock for ChecklistRepository
class MockChecklistRepositoryBase extends Mock implements ChecklistRepository {}
