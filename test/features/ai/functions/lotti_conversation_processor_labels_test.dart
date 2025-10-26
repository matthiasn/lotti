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
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/services/label_assignment_event_service.dart';
import 'package:lotti/features/labels/services/label_assignment_rate_limiter.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

class MockJournalRepository extends Mock implements JournalRepository {}

class MockConversationRepository extends Mock
    implements ConversationRepository {}

class MockConversationManager extends Mock implements ConversationManager {}

class MockJournalDb extends Mock implements JournalDb {}

class MockRef extends Mock implements Ref {}

class MockLoggingService extends Mock implements LoggingService {}

class MockPersistenceLogic extends Mock implements PersistenceLogic {}

class MockLabelsRepository extends Mock implements LabelsRepository {}

class FakeInferenceRepo extends Fake implements InferenceRepositoryInterface {}

void main() {
  late MockJournalRepository mockJournalRepo;
  late MockConversationRepository mockConversationRepo;
  late MockConversationManager mockConversationManager;
  late MockJournalDb mockJournalDb;
  late MockRef mockRef;
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
    mockConversationRepo = MockConversationRepository();
    mockConversationManager = MockConversationManager();
    mockJournalDb = MockJournalDb();
    mockRef = MockRef();
    mockLoggingService = MockLoggingService();
    mockPersistenceLogic = MockPersistenceLogic();
    mockLabelsRepo = MockLabelsRepository();

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

    // Set up ref
    when(() => mockRef.read(journalRepositoryProvider))
        .thenReturn(mockJournalRepo);
    when(() => mockRef.read(labelsRepositoryProvider))
        .thenReturn(mockLabelsRepo);
    mockChecklistRepo = MockChecklistRepositoryBase();
    when(() => mockRef.read(checklistRepositoryProvider))
        .thenReturn(mockChecklistRepo);
    when(() => mockRef.read(conversationRepositoryProvider.notifier))
        .thenReturn(mockConversationRepo);

    processor = LottiConversationProcessor(ref: mockRef);
  });

  tearDown(getIt.reset);

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
    // Explicitly control only the shadow flag here
    when(() => mockJournalDb.getConfigFlag(aiLabelAssignmentShadowFlag))
        .thenAnswer((_) async => false);

    // Conversation wiring
    const conversationId = 'conv';
    when(() => mockConversationRepo.createConversation(
          systemMessage: any(named: 'systemMessage'),
          maxTurns: any(named: 'maxTurns'),
        )).thenReturn(conversationId);
    when(() => mockConversationRepo.getConversation(conversationId))
        .thenReturn(mockConversationManager);
    when(() => mockConversationManager.messages).thenReturn([]);
    when(() => mockConversationManager.addToolResponse(
          toolCallId: any(named: 'toolCallId'),
          response: any(named: 'response'),
        )).thenAnswer((_) {});

    // sendMessage triggers strategy processing of our tool call
    when(() => mockConversationRepo.sendMessage(
          conversationId: conversationId,
          message: any(named: 'message'),
          model: any(named: 'model'),
          provider: any(named: 'provider'),
          inferenceRepo: any(named: 'inferenceRepo'),
          tools: any(named: 'tools'),
          temperature: any(named: 'temperature'),
          strategy: any(named: 'strategy'),
        )).thenAnswer((invocation) async {
      final strategy =
          invocation.namedArguments[#strategy] as ConversationStrategy?;
      if (strategy != null) {
        await strategy.processToolCalls(
          toolCalls: [
            makeCall(['A', 'B', 'X'])
          ],
          manager: mockConversationManager,
        );
      }
    });

    when(() => mockConversationRepo.deleteConversation(conversationId))
        .thenAnswer((_) {});

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

  test('shadow mode does not persist but returns response', () async {
    final task = makeTask();

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
    when(() => mockJournalDb.getConfigFlag('ai_label_assignment_shadow'))
        .thenAnswer((_) async => true);

    const conversationId = 'conv2';
    when(() => mockConversationRepo.createConversation(
          systemMessage: any(named: 'systemMessage'),
          maxTurns: any(named: 'maxTurns'),
        )).thenReturn(conversationId);
    when(() => mockConversationRepo.getConversation(conversationId))
        .thenReturn(mockConversationManager);
    when(() => mockConversationManager.messages).thenReturn([]);
    when(() => mockConversationManager.addToolResponse(
          toolCallId: any(named: 'toolCallId'),
          response: any(named: 'response'),
        )).thenAnswer((_) {});

    when(() => mockConversationRepo.sendMessage(
          conversationId: conversationId,
          message: any(named: 'message'),
          model: any(named: 'model'),
          provider: any(named: 'provider'),
          inferenceRepo: any(named: 'inferenceRepo'),
          tools: any(named: 'tools'),
          temperature: any(named: 'temperature'),
          strategy: any(named: 'strategy'),
        )).thenAnswer((invocation) async {
      final strategy =
          invocation.namedArguments[#strategy] as ConversationStrategy?;
      if (strategy != null) {
        await strategy.processToolCalls(
          toolCalls: [
            makeCall(['A', 'B'])
          ],
          manager: mockConversationManager,
        );
      }
    });
    when(() => mockConversationRepo.deleteConversation(conversationId))
        .thenAnswer((_) {});

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
    verify(() => mockConversationManager.addToolResponse(
          toolCallId: any(named: 'toolCallId'),
          response: any(named: 'response'),
        )).called(greaterThanOrEqualTo(1));
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

    // First attempt conversation wiring
    const conversationId1 = 'conv-retry-1';
    when(() => mockConversationRepo.createConversation(
          systemMessage: any(named: 'systemMessage'),
          maxTurns: any(named: 'maxTurns'),
        )).thenReturn(conversationId1);
    when(() => mockConversationRepo.getConversation(conversationId1))
        .thenReturn(mockConversationManager);
    when(() => mockConversationManager.messages).thenReturn([]);

    String? firstResponse;
    when(() => mockConversationManager.addToolResponse(
          toolCallId: any(named: 'toolCallId'),
          response: captureAny(named: 'response'),
        )).thenAnswer((invocation) {
      firstResponse = invocation.namedArguments[#response] as String;
      return;
    });

    when(() => mockConversationRepo.sendMessage(
          conversationId: conversationId1,
          message: any(named: 'message'),
          model: any(named: 'model'),
          provider: any(named: 'provider'),
          inferenceRepo: any(named: 'inferenceRepo'),
          tools: any(named: 'tools'),
          temperature: any(named: 'temperature'),
          strategy: any(named: 'strategy'),
        )).thenAnswer((invocation) async {
      final strategy =
          invocation.namedArguments[#strategy] as ConversationStrategy?;
      if (strategy != null) {
        await strategy.processToolCalls(
          toolCalls: [
            ChatCompletionMessageToolCall(
              id: 'call-1',
              type: ChatCompletionMessageToolCallType.function,
              function: ChatCompletionMessageFunctionCall(
                name: 'assign_task_labels',
                arguments: jsonEncode({
                  'labelIds': ['valid-1', 'typo-id', 'valid-2', 'deleted-id'],
                }),
              ),
            ),
          ],
          manager: mockConversationManager,
        );
      }
    });
    when(() => mockConversationRepo.deleteConversation(conversationId1))
        .thenAnswer((_) {});

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
    expect(firstAssigned, containsAll(['valid-1', 'valid-2']));
    expect(firstInvalid, containsAll(['typo-id', 'deleted-id']));

    // Clear rate limiter before retry to allow second assignment
    getIt<LabelAssignmentRateLimiter>().clearHistory();

    // Second attempt with corrected IDs
    const conversationId2 = 'conv-retry-2';
    when(() => mockConversationRepo.createConversation(
          systemMessage: any(named: 'systemMessage'),
          maxTurns: any(named: 'maxTurns'),
        )).thenReturn(conversationId2);
    when(() => mockConversationRepo.getConversation(conversationId2))
        .thenReturn(mockConversationManager);

    String? secondResponse;
    when(() => mockConversationManager.addToolResponse(
          toolCallId: any(named: 'toolCallId'),
          response: captureAny(named: 'response'),
        )).thenAnswer((invocation) {
      secondResponse = invocation.namedArguments[#response] as String;
      return;
    });

    when(() => mockConversationRepo.sendMessage(
          conversationId: conversationId2,
          message: any(named: 'message'),
          model: any(named: 'model'),
          provider: any(named: 'provider'),
          inferenceRepo: any(named: 'inferenceRepo'),
          tools: any(named: 'tools'),
          temperature: any(named: 'temperature'),
          strategy: any(named: 'strategy'),
        )).thenAnswer((invocation) async {
      final strategy =
          invocation.namedArguments[#strategy] as ConversationStrategy?;
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
    });
    when(() => mockConversationRepo.deleteConversation(conversationId2))
        .thenAnswer((_) {});

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

    const conversationId = 'conv-error';
    when(() => mockConversationRepo.createConversation(
          systemMessage: any(named: 'systemMessage'),
          maxTurns: any(named: 'maxTurns'),
        )).thenReturn(conversationId);
    when(() => mockConversationRepo.getConversation(conversationId))
        .thenReturn(mockConversationManager);
    when(() => mockConversationManager.messages).thenReturn([]);

    String? errorResponse;
    when(() => mockConversationManager.addToolResponse(
          toolCallId: any(named: 'toolCallId'),
          response: captureAny(named: 'response'),
        )).thenAnswer((invocation) {
      errorResponse = invocation.namedArguments[#response] as String;
      return;
    });

    when(() => mockConversationRepo.sendMessage(
          conversationId: conversationId,
          message: any(named: 'message'),
          model: any(named: 'model'),
          provider: any(named: 'provider'),
          inferenceRepo: any(named: 'inferenceRepo'),
          tools: any(named: 'tools'),
          temperature: any(named: 'temperature'),
          strategy: any(named: 'strategy'),
        )).thenAnswer((invocation) async {
      final strategy =
          invocation.namedArguments[#strategy] as ConversationStrategy?;
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
    });
    when(() => mockConversationRepo.deleteConversation(conversationId))
        .thenAnswer((_) {});

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
