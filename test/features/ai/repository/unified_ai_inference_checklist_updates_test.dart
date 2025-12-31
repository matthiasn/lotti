import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/functions/checklist_completion_functions.dart';
import 'package:lotti/features/ai/functions/task_functions.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/ai_input_repository.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/services/auto_checklist_service.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../test_utils.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class MockAiInputRepository extends Mock implements AiInputRepository {}

class MockCloudInferenceRepository extends Mock
    implements CloudInferenceRepository {}

class MockJournalRepository extends Mock implements JournalRepository {}

class MockChecklistRepository extends Mock implements ChecklistRepository {}

class MockAutoChecklistService extends Mock implements AutoChecklistService {}

class MockLoggingService extends Mock implements LoggingService {}

class MockJournalDb extends Mock implements JournalDb {}

class MockLabelsRepository extends Mock implements LabelsRepository {}

class FakeAiResponseData extends Fake implements AiResponseData {}

class FakeMetadata extends Fake implements Metadata {
  @override
  String get id => 'task-1';

  @override
  DateTime get createdAt => DateTime.now();

  @override
  DateTime get updatedAt => DateTime.now();

  @override
  DateTime get dateFrom => DateTime.now();

  @override
  DateTime get dateTo => DateTime.now();
}

class FakeTaskData extends Fake implements TaskData {
  @override
  TaskStatus get status => TaskStatus.open(
        id: 'status-1',
        createdAt: DateTime.now(),
        utcOffset: 0,
      );

  @override
  DateTime get dateFrom => DateTime.now();

  @override
  DateTime get dateTo => DateTime.now();

  @override
  List<TaskStatus> get statusHistory => [status];

  @override
  String get title => 'Test Task';

  @override
  String? get languageCode => 'en';
}

void main() {
  late UnifiedAiInferenceRepository repository;
  late ProviderContainer container;
  late MockAiConfigRepository mockAiConfigRepo;
  late MockAiInputRepository mockAiInputRepo;
  late MockCloudInferenceRepository mockCloudRepo;
  late MockJournalRepository mockJournalRepo;
  late MockChecklistRepository mockChecklistRepo;
  late MockAutoChecklistService mockAutoChecklistService;
  late MockLoggingService mockLoggingService;
  late MockJournalDb mockJournalDb;
  late MockLabelsRepository mockLabelsRepo;

  setUpAll(() {
    registerFallbackValue(InferenceStatus.idle);
    registerFallbackValue(FakeMetadata());
    registerFallbackValue(FakeTaskData());
    registerFallbackValue(const EntryText(plainText: ''));
    registerFallbackValue(FakeAiResponseData());
  });

  setUp(() {
    mockAiConfigRepo = MockAiConfigRepository();
    mockAiInputRepo = MockAiInputRepository();
    mockCloudRepo = MockCloudInferenceRepository();
    mockJournalRepo = MockJournalRepository();
    mockChecklistRepo = MockChecklistRepository();
    mockAutoChecklistService = MockAutoChecklistService();
    mockLoggingService = MockLoggingService();
    mockJournalDb = MockJournalDb();
    mockLabelsRepo = MockLabelsRepository();

    reset(mockJournalDb);

    // Setup getIt
    getIt
      ..registerSingleton<LoggingService>(mockLoggingService)
      ..registerSingleton<JournalDb>(mockJournalDb);

    when(() => mockJournalDb.getConfigFlag(enableAiStreamingFlag))
        .thenAnswer((_) async => false);

    // Setup default mocks
    when(() => mockLoggingService.captureException(
          any<dynamic>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        )).thenReturn(null);

    container = ProviderContainer(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepo),
        aiInputRepositoryProvider.overrideWithValue(mockAiInputRepo),
        cloudInferenceRepositoryProvider.overrideWithValue(mockCloudRepo),
        journalRepositoryProvider.overrideWithValue(mockJournalRepo),
        checklistRepositoryProvider.overrideWithValue(mockChecklistRepo),
        labelsRepositoryProvider.overrideWithValue(mockLabelsRepo),
        journalDbProvider.overrideWithValue(mockJournalDb),
      ],
    );

    final ref = container.read(testRefProvider);
    repository = UnifiedAiInferenceRepository(ref)
      ..autoChecklistServiceForTesting = mockAutoChecklistService;
  });

  tearDown(() {
    container.dispose();
    getIt.reset();
  });

  group('UnifiedAiInferenceRepository - Checklist Updates', () {
    test('should include function tools for checklistUpdates response type',
        () async {
      // Arrange
      final task = Task(
        meta: FakeMetadata(),
        data: FakeTaskData(),
        entryText: const EntryText(plainText: 'Test task'),
      );

      final promptConfig = AiConfigPrompt(
        id: 'prompt-1',
        name: 'Checklist Updates',
        systemMessage: 'Process checklist updates',
        userMessage: 'Update checklists',
        defaultModelId: 'model-1',
        modelIds: ['model-1'],
        createdAt: DateTime.now(),
        useReasoning: false,
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.checklistUpdates,
      );

      final model = AiConfigModel(
        id: 'model-1',
        name: 'Test Model',
        providerModelId: 'gpt-4',
        inferenceProviderId: 'provider-1',
        createdAt: DateTime.now(),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
        supportsFunctionCalling: true,
      );

      final provider = AiConfigInferenceProvider(
        id: 'provider-1',
        baseUrl: 'https://api.example.com',
        apiKey: 'test-key',
        name: 'Test Provider',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.openAi,
      );

      // Setup mocks
      when(() => mockAiInputRepo.getEntity('task-1'))
          .thenAnswer((_) async => task);
      when(() => mockAiConfigRepo.getConfigById('model-1'))
          .thenAnswer((_) async => model);
      when(() => mockAiConfigRepo.getConfigById('provider-1'))
          .thenAnswer((_) async => provider);
      when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'task-1'))
          .thenAnswer((_) async => '{"task": "details"}');

      final streamController =
          StreamController<CreateChatCompletionStreamResponse>();

      // Capture the tools passed to generate method
      List<ChatCompletionTool>? capturedTools;
      when(() => mockCloudRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
            provider: any(named: 'provider'),
            tools: any(named: 'tools'),
          )).thenAnswer((invocation) {
        capturedTools =
            invocation.namedArguments[#tools] as List<ChatCompletionTool>?;
        return streamController.stream;
      });

      // Act
      final future = repository.runInference(
        entityId: 'task-1',
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Add test response
      streamController.add(
        CreateChatCompletionStreamResponse(
          id: 'test',
          created: DateTime.now().millisecondsSinceEpoch,
          model: 'gpt-4',
          choices: [],
        ),
      );
      await streamController.close();

      await future;

      // Assert
      expect(capturedTools, isNotNull);
      expect(capturedTools!.length, greaterThan(0));

      // Should include both checklist and task functions
      final functionNames =
          capturedTools!.map((tool) => tool.function.name).toSet();

      expect(functionNames,
          contains(ChecklistCompletionFunctions.suggestChecklistCompletion));
      // Single-item tool removed; only batch tool is exposed
      expect(functionNames,
          contains(ChecklistCompletionFunctions.addMultipleChecklistItems));
      expect(functionNames, contains(TaskFunctions.setTaskLanguage));

      // Label assignment tool is always enabled for checklistUpdates
      expect(functionNames, contains('assign_task_labels'));
    });

    test('should not create AI response entry for checklistUpdates type',
        () async {
      // Arrange
      final task = Task(
        meta: FakeMetadata(),
        data: FakeTaskData(),
        entryText: const EntryText(plainText: 'Test task'),
      );

      final promptConfig = AiConfigPrompt(
        id: 'prompt-1',
        name: 'Checklist Updates',
        systemMessage: 'Process checklist updates',
        userMessage: 'Update checklists',
        defaultModelId: 'model-1',
        modelIds: ['model-1'],
        createdAt: DateTime.now(),
        useReasoning: false,
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.checklistUpdates,
      );

      final model = AiConfigModel(
        id: 'model-1',
        name: 'Test Model',
        providerModelId: 'gpt-4',
        inferenceProviderId: 'provider-1',
        createdAt: DateTime.now(),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
        supportsFunctionCalling: true,
      );

      final provider = AiConfigInferenceProvider(
        id: 'provider-1',
        baseUrl: 'https://api.example.com',
        apiKey: 'test-key',
        name: 'Test Provider',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.openAi,
      );

      // Setup mocks
      when(() => mockAiInputRepo.getEntity('task-1'))
          .thenAnswer((_) async => task);
      when(() => mockAiConfigRepo.getConfigById('model-1'))
          .thenAnswer((_) async => model);
      when(() => mockAiConfigRepo.getConfigById('provider-1'))
          .thenAnswer((_) async => provider);
      when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'task-1'))
          .thenAnswer((_) async => '{"task": "details"}');

      final streamController =
          StreamController<CreateChatCompletionStreamResponse>();
      when(() => mockCloudRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
            provider: any(named: 'provider'),
            tools: any(named: 'tools'),
          )).thenAnswer((_) => streamController.stream);

      // Act
      final future = repository.runInference(
        entityId: 'task-1',
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Add test response
      streamController.add(
        CreateChatCompletionStreamResponse(
          id: 'test',
          created: DateTime.now().millisecondsSinceEpoch,
          model: 'gpt-4',
          choices: [
            const ChatCompletionStreamResponseChoice(
              index: 0,
              delta: ChatCompletionStreamResponseDelta(
                content: 'Test response',
              ),
            ),
          ],
        ),
      );

      await streamController.close();

      await future;

      // Assert - should NOT call createAiResponseEntry for checklistUpdates type
      verifyNever(() => mockAiInputRepo.createAiResponseEntry(
            data: any<AiResponseData>(named: 'data'),
            start: any<DateTime>(named: 'start'),
            linkedId: any<String?>(named: 'linkedId'),
            categoryId: any<String?>(named: 'categoryId'),
          ));
    });

    test('should exclude function tools for taskSummary response type',
        () async {
      // Arrange
      final task = Task(
        meta: FakeMetadata(),
        data: FakeTaskData(),
        entryText: const EntryText(plainText: 'Test task'),
      );

      final promptConfig = AiConfigPrompt(
        id: 'prompt-1',
        name: 'Task Summary',
        systemMessage: 'Generate task summary',
        userMessage: 'Summarize the task',
        defaultModelId: 'model-1',
        modelIds: ['model-1'],
        createdAt: DateTime.now(),
        useReasoning: true,
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.taskSummary,
      );

      final model = AiConfigModel(
        id: 'model-1',
        name: 'Test Model',
        providerModelId: 'gpt-4',
        inferenceProviderId: 'provider-1',
        createdAt: DateTime.now(),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
        supportsFunctionCalling: true,
      );

      final provider = AiConfigInferenceProvider(
        id: 'provider-1',
        baseUrl: 'https://api.example.com',
        apiKey: 'test-key',
        name: 'Test Provider',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.openAi,
      );

      // Setup mocks
      when(() => mockAiInputRepo.getEntity('task-1'))
          .thenAnswer((_) async => task);
      when(() => mockAiConfigRepo.getConfigById('model-1'))
          .thenAnswer((_) async => model);
      when(() => mockAiConfigRepo.getConfigById('provider-1'))
          .thenAnswer((_) async => provider);
      when(() => mockAiInputRepo.buildTaskDetailsJson(id: 'task-1'))
          .thenAnswer((_) async => '{"task": "details"}');

      final streamController =
          StreamController<CreateChatCompletionStreamResponse>();

      // Capture the tools passed to generate method
      List<ChatCompletionTool>? capturedTools;
      when(() => mockCloudRepo.generate(
            any(),
            model: any(named: 'model'),
            temperature: any(named: 'temperature'),
            baseUrl: any(named: 'baseUrl'),
            apiKey: any(named: 'apiKey'),
            systemMessage: any(named: 'systemMessage'),
            maxCompletionTokens: any(named: 'maxCompletionTokens'),
            provider: any(named: 'provider'),
            tools: any(named: 'tools'),
          )).thenAnswer((invocation) {
        capturedTools =
            invocation.namedArguments[#tools] as List<ChatCompletionTool>?;
        return streamController.stream;
      });

      // Act
      final future = repository.runInference(
        entityId: 'task-1',
        promptConfig: promptConfig,
        onProgress: (_) {},
        onStatusChange: (_) {},
      );

      // Add test response
      streamController.add(
        CreateChatCompletionStreamResponse(
          id: 'test',
          created: DateTime.now().millisecondsSinceEpoch,
          model: 'gpt-4',
          choices: [],
        ),
      );
      await streamController.close();

      await future;

      // Assert - should NOT include tools for task summary
      expect(capturedTools, isNull);
    });
  });
}
