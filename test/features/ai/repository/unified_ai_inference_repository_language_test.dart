import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/functions/task_functions.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class MockAiInputRepository extends Mock implements AiInputRepository {}

class MockCloudInferenceRepository extends Mock
    implements CloudInferenceRepository {}

class MockJournalRepository extends Mock implements JournalRepository {}

class MockChecklistRepository extends Mock implements ChecklistRepository {}

class MockLoggingService extends Mock implements LoggingService {}

class MockJournalDb extends Mock implements JournalDb {}

class MockLabelsRepository extends Mock implements LabelsRepository {}

class MockRef extends Mock implements Ref {}

class FakeAiConfigPrompt extends Fake implements AiConfigPrompt {}

class FakeAiConfigModel extends Fake implements AiConfigModel {}

class FakeAiConfigInferenceProvider extends Fake
    implements AiConfigInferenceProvider {}

class FakeMetadata extends Fake implements Metadata {}

class FakeTaskData extends Fake implements TaskData {}

void main() {
  late UnifiedAiInferenceRepository repository;
  late MockRef mockRef;
  late MockAiConfigRepository mockAiConfigRepo;
  late MockAiInputRepository mockAiInputRepo;
  late MockCloudInferenceRepository mockCloudInferenceRepo;
  late MockJournalRepository mockJournalRepo;
  late MockChecklistRepository mockChecklistRepo;
  late MockLoggingService mockLoggingService;
  late MockJournalDb mockJournalDb;
  late MockLabelsRepository mockLabelsRepo;

  setUpAll(() {
    registerFallbackValue(FakeAiConfigPrompt());
    registerFallbackValue(FakeAiConfigModel());
    registerFallbackValue(FakeAiConfigInferenceProvider());
    registerFallbackValue(FakeMetadata());
    registerFallbackValue(FakeTaskData());
    registerFallbackValue(fallbackJournalEntity);
    registerFallbackValue(InferenceStatus.idle);
  });

  setUp(() {
    mockRef = MockRef();
    mockAiConfigRepo = MockAiConfigRepository();
    mockAiInputRepo = MockAiInputRepository();
    mockCloudInferenceRepo = MockCloudInferenceRepository();
    mockJournalRepo = MockJournalRepository();
    mockChecklistRepo = MockChecklistRepository();
    mockLoggingService = MockLoggingService();
    mockJournalDb = MockJournalDb();
    mockLabelsRepo = MockLabelsRepository();

    when(() => mockRef.read(aiConfigRepositoryProvider))
        .thenReturn(mockAiConfigRepo);
    when(() => mockRef.read(aiInputRepositoryProvider))
        .thenReturn(mockAiInputRepo);
    when(() => mockRef.read(cloudInferenceRepositoryProvider))
        .thenReturn(mockCloudInferenceRepo);
    when(() => mockRef.read(journalRepositoryProvider))
        .thenReturn(mockJournalRepo);
    when(() => mockRef.read(checklistRepositoryProvider))
        .thenReturn(mockChecklistRepo);
    when(() => mockRef.read(labelsRepositoryProvider))
        .thenReturn(mockLabelsRepo);

    getIt
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<JournalDb>(mockJournalDb);

    repository = UnifiedAiInferenceRepository(mockRef);
  });

  tearDown(() {
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    if (getIt.isRegistered<JournalDb>()) {
      getIt.unregister<JournalDb>();
    }
  });

  Metadata createMetadata() {
    return Metadata(
      id: 'test-id',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      dateFrom: DateTime.now(),
      dateTo: DateTime.now(),
    );
  }

  AiConfigPrompt createPrompt({
    required String id,
    required String name,
    required List<InputDataType> requiredInputData,
    AiResponseType aiResponseType = AiResponseType.taskSummary,
  }) {
    return AiConfigPrompt(
      id: id,
      name: name,
      description: 'Test prompt',
      systemMessage: 'You are a helpful assistant',
      userMessage: 'Create a task summary',
      requiredInputData: requiredInputData,
      defaultModelId: 'model-1',
      modelIds: ['model-1'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      aiResponseType: aiResponseType,
      useReasoning: false,
    );
  }

  AiConfigModel createModel({
    required String id,
    required String inferenceProviderId,
    required String providerModelId,
    bool supportsFunctionCalling = true,
  }) {
    return AiConfigModel(
      id: id,
      name: 'Test Model',
      inferenceProviderId: inferenceProviderId,
      providerModelId: providerModelId,
      description: 'Test model',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      maxCompletionTokens: 4096,
      supportsFunctionCalling: supportsFunctionCalling,
      inputModalities: [Modality.text],
      outputModalities: [Modality.text],
      isReasoningModel: false,
    );
  }

  AiConfigInferenceProvider createProvider({
    required String id,
    required InferenceProviderType inferenceProviderType,
  }) {
    return AiConfigInferenceProvider(
      id: id,
      name: 'Test Provider',
      description: 'Test provider',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      inferenceProviderType: inferenceProviderType,
      baseUrl: 'https://api.openai.com',
      apiKey: 'test-key',
    );
  }

  group('Language detection and setting', () {
    test('task summaries do not include function tools', () async {
      final taskEntity = Task(
        meta: createMetadata(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
      );

      final promptConfig = createPrompt(
        id: 'prompt-1',
        name: 'Task Summary',
        requiredInputData: [InputDataType.task],
      );

      final model = createModel(
        id: 'model-1',
        inferenceProviderId: 'provider-1',
        providerModelId: 'gpt-4',
      );

      final provider = createProvider(
        id: 'provider-1',
        inferenceProviderType: InferenceProviderType.openAi,
      );

      when(() => mockAiInputRepo.getEntity('test-id'))
          .thenAnswer((_) async => taskEntity);
      when(() => mockAiConfigRepo.getConfigById('model-1'))
          .thenAnswer((_) async => model);
      when(() => mockAiConfigRepo.getConfigById('provider-1'))
          .thenAnswer((_) async => provider);
      when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'))
          .thenAnswer((_) async => '{"title": "Test Task"}');

      // Setup mock to capture the tools argument
      final capturedTools = <List<ChatCompletionTool>?>[];
      when(() => mockCloudInferenceRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
            provider: any(named: 'provider'),
            tools: captureAny(named: 'tools'),
          )).thenAnswer((invocation) {
        capturedTools.add(invocation.namedArguments[const Symbol('tools')]
            as List<ChatCompletionTool>?);
        return Stream.fromIterable([
          const CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              ChatCompletionStreamResponseChoice(
                delta:
                    ChatCompletionStreamResponseDelta(content: 'Test response'),
                finishReason: ChatCompletionFinishReason.stop,
                index: 0,
              ),
            ],
            created: 0,
            model: 'test-model',
          ),
        ]);
      });

      await repository.runInference(
        entityId: 'test-id',
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify that task summaries don't include any tools
      expect(capturedTools, hasLength(1));
      expect(capturedTools.first, isNull);
    });

    test('checklist updates include task language and checklist tools',
        () async {
      final taskEntity = Task(
        meta: createMetadata(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
      );

      final promptConfig = createPrompt(
        id: 'prompt-1',
        name: 'Checklist Updates',
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.checklistUpdates,
      );

      final model = createModel(
        id: 'model-1',
        inferenceProviderId: 'provider-1',
        providerModelId: 'gpt-4',
      );

      final provider = createProvider(
        id: 'provider-1',
        inferenceProviderType: InferenceProviderType.openAi,
      );

      when(() => mockAiInputRepo.getEntity('test-id'))
          .thenAnswer((_) async => taskEntity);
      when(() => mockAiConfigRepo.getConfigById('model-1'))
          .thenAnswer((_) async => model);
      when(() => mockAiConfigRepo.getConfigById('provider-1'))
          .thenAnswer((_) async => provider);
      when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'))
          .thenAnswer((_) async => '{"title": "Test Task"}');

      // Setup mock to capture the tools argument
      final capturedTools = <List<ChatCompletionTool>>[];
      when(() => mockCloudInferenceRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
            provider: any(named: 'provider'),
            tools: captureAny(named: 'tools'),
          )).thenAnswer((invocation) {
        capturedTools.add(invocation.namedArguments[const Symbol('tools')]
            as List<ChatCompletionTool>);
        return Stream.fromIterable([
          const CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(content: ''),
                finishReason: ChatCompletionFinishReason.stop,
                index: 0,
              ),
            ],
            created: 0,
            model: 'test-model',
          ),
        ]);
      });

      await repository.runInference(
        entityId: 'test-id',
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify tools include both checklist and task functions
      expect(capturedTools, hasLength(1));
      final tools = capturedTools.first;
      final toolNames = tools.map((t) => t.function.name).toList();

      expect(toolNames, contains(TaskFunctions.setTaskLanguage));
      expect(toolNames, contains('suggest_checklist_completion'));
      expect(toolNames, contains('add_multiple_checklist_items'));
    });

    test('handles set_task_language function call in checklist updates',
        () async {
      final taskEntity = Task(
        meta: createMetadata(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
      );

      final promptConfig = createPrompt(
        id: 'prompt-1',
        name: 'Checklist Updates',
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.checklistUpdates,
      );

      final model = createModel(
        id: 'model-1',
        inferenceProviderId: 'provider-1',
        providerModelId: 'gpt-4',
      );

      final provider = createProvider(
        id: 'provider-1',
        inferenceProviderType: InferenceProviderType.openAi,
      );

      when(() => mockAiInputRepo.getEntity('test-id'))
          .thenAnswer((_) async => taskEntity);
      when(() => mockAiConfigRepo.getConfigById('model-1'))
          .thenAnswer((_) async => model);
      when(() => mockAiConfigRepo.getConfigById('provider-1'))
          .thenAnswer((_) async => provider);
      when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'))
          .thenAnswer((_) async => '{"title": "Test Task"}');
      when(() => mockJournalRepo.updateJournalEntity(any()))
          .thenAnswer((_) async => true);
      when(() => mockJournalRepo.getJournalEntityById('test-id'))
          .thenAnswer((_) async => taskEntity);

      // Mock response with function call
      when(() => mockCloudInferenceRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
            provider: any(named: 'provider'),
            tools: any(named: 'tools'),
          )).thenAnswer((_) => Stream.fromIterable([
            const CreateChatCompletionStreamResponse(
              id: 'response-1',
              choices: [
                ChatCompletionStreamResponseChoice(
                  delta: ChatCompletionStreamResponseDelta(
                    toolCalls: [
                      ChatCompletionStreamMessageToolCallChunk(
                        index: 0,
                        id: 'call_1',
                        type: ChatCompletionStreamMessageToolCallChunkType
                            .function,
                        function: ChatCompletionStreamMessageFunctionCall(
                          name: TaskFunctions.setTaskLanguage,
                          arguments:
                              '''{"languageCode": "de", "confidence": "high", "reason": "All audio transcripts are in German"}''',
                        ),
                      ),
                    ],
                  ),
                  index: 0,
                ),
              ],
              created: 0,
              model: 'test-model',
            ),
            const CreateChatCompletionStreamResponse(
              id: 'response-1',
              choices: [
                ChatCompletionStreamResponseChoice(
                  delta: ChatCompletionStreamResponseDelta(
                      content: ''), // No text content for checklist updates
                  finishReason: ChatCompletionFinishReason.stop,
                  index: 0,
                ),
              ],
              created: 0,
              model: 'test-model',
            ),
          ]));

      await repository.runInference(
        entityId: 'test-id',
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify task was updated with language
      final captured = verify(() => mockJournalRepo.updateJournalEntity(
            captureAny(),
          )).captured;

      // Find the Task entity with language update
      final taskUpdates = captured.whereType<Task>();
      expect(taskUpdates, isNotEmpty);

      final updatedTask = taskUpdates.firstWhere(
        (task) => task.data.languageCode == 'de',
        orElse: () => throw Exception('No task with German language found'),
      );

      expect(updatedTask.data.languageCode, equals('de'));
    });

    test('does not override existing language preference', () async {
      final taskEntity = Task(
        meta: createMetadata(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          languageCode: 'fr', // Already has French set
        ),
      );

      final promptConfig = createPrompt(
        id: 'prompt-1',
        name: 'Checklist Updates',
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.checklistUpdates,
      );

      final model = createModel(
        id: 'model-1',
        inferenceProviderId: 'provider-1',
        providerModelId: 'gpt-4',
      );

      final provider = createProvider(
        id: 'provider-1',
        inferenceProviderType: InferenceProviderType.openAi,
      );

      when(() => mockAiInputRepo.getEntity('test-id'))
          .thenAnswer((_) async => taskEntity);
      when(() => mockAiConfigRepo.getConfigById('model-1'))
          .thenAnswer((_) async => model);
      when(() => mockAiConfigRepo.getConfigById('provider-1'))
          .thenAnswer((_) async => provider);
      when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'))
          .thenAnswer(
              (_) async => '{"title": "Test Task", "languageCode": "fr"}');
      when(() => mockJournalRepo.getJournalEntityById('test-id'))
          .thenAnswer((_) async => taskEntity);

      // Mock response with function call trying to change language
      when(() => mockCloudInferenceRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
            provider: any(named: 'provider'),
            tools: any(named: 'tools'),
          )).thenAnswer((_) => Stream.fromIterable([
            const CreateChatCompletionStreamResponse(
              id: 'response-1',
              choices: [
                ChatCompletionStreamResponseChoice(
                  delta: ChatCompletionStreamResponseDelta(
                    toolCalls: [
                      ChatCompletionStreamMessageToolCallChunk(
                        index: 0,
                        id: 'call_1',
                        type: ChatCompletionStreamMessageToolCallChunkType
                            .function,
                        function: ChatCompletionStreamMessageFunctionCall(
                          name: TaskFunctions.setTaskLanguage,
                          arguments:
                              '''{"languageCode": "de", "confidence": "high", "reason": "Detected German"}''',
                        ),
                      ),
                    ],
                  ),
                  index: 0,
                ),
              ],
              created: 0,
              model: 'test-model',
            ),
          ]));

      await repository.runInference(
        entityId: 'test-id',
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify task was NOT updated
      verifyNever(() => mockJournalRepo.updateJournalEntity(any()));
    });

    test('includes language preference in system message for task summaries',
        () async {
      final taskEntity = Task(
        meta: createMetadata(),
        data: TaskData(
          status: TaskStatus.open(
            id: 'status-1',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          languageCode: 'es', // Spanish preference
        ),
      );

      final promptConfig = createPrompt(
        id: 'prompt-1',
        name: 'Task Summary',
        requiredInputData: [InputDataType.task],
      );

      final model = createModel(
        id: 'model-1',
        inferenceProviderId: 'provider-1',
        providerModelId: 'gpt-4',
      );

      final provider = createProvider(
        id: 'provider-1',
        inferenceProviderType: InferenceProviderType.openAi,
      );

      when(() => mockAiInputRepo.getEntity('test-id'))
          .thenAnswer((_) async => taskEntity);
      when(() => mockAiConfigRepo.getConfigById('model-1'))
          .thenAnswer((_) async => model);
      when(() => mockAiConfigRepo.getConfigById('provider-1'))
          .thenAnswer((_) async => provider);
      when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'test-id'))
          .thenAnswer((_) async => '{"title": "Test Task"}');

      // Capture system message
      String? capturedSystemMessage;
      when(() => mockCloudInferenceRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: captureAny(named: 'systemMessage'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
            provider: any(named: 'provider'),
            tools: any(named: 'tools'),
          )).thenAnswer((invocation) {
        capturedSystemMessage =
            invocation.namedArguments[const Symbol('systemMessage')] as String;
        return Stream.fromIterable([
          const CreateChatCompletionStreamResponse(
            id: 'response-1',
            choices: [
              ChatCompletionStreamResponseChoice(
                delta: ChatCompletionStreamResponseDelta(content: 'Test'),
                finishReason: ChatCompletionFinishReason.stop,
                index: 0,
              ),
            ],
            created: 0,
            model: 'test-model',
          ),
        ]);
      });

      await repository.runInference(
        entityId: 'test-id',
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Verify system message includes language preference
      expect(capturedSystemMessage, contains('Spanish (es)'));
      expect(capturedSystemMessage,
          contains('Generate the entire summary in this language'));
    });
  });
}
