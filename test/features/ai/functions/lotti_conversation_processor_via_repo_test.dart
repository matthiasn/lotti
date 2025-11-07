import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/functions/lotti_conversation_processor.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/repository/checklist_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:uuid/uuid.dart';

class MockRef extends Mock implements Ref {}

class MockChecklistRepository extends Mock implements ChecklistRepository {}

class MockJournalRepository extends Mock implements JournalRepository {}

class MockJournalDb extends Mock implements JournalDb {}

class MockInferenceRepo extends Mock implements InferenceRepositoryInterface {}

class MockConversationRepository extends Mock
    implements ConversationRepository {}

class MockConversationManager extends Mock implements ConversationManager {}

const _uuid = Uuid();

class TestDataFactory {
  static Task createTask({
    String? id,
    String? title,
    String? languageCode,
    List<String>? checklistIds,
  }) {
    final taskId = id ?? _uuid.v4();
    return Task(
      meta: Metadata(
        id: taskId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
        categoryId: 'test-category',
      ),
      data: TaskData(
        title: title ?? 'Test Task',
        languageCode: languageCode,
        checklistIds: checklistIds ?? [],
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: DateTime.now(),
          utcOffset: 0,
        ),
        statusHistory: const [],
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
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
      providerModelId: name ?? 'gpt-oss:20b',
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
}

AiConfigInferenceProvider provider() => AiConfigInferenceProvider(
      id: 'ollama',
      name: 'Ollama',
      inferenceProviderType: InferenceProviderType.ollama,
      baseUrl: 'http://localhost:11434',
      apiKey: '',
      createdAt: DateTime(2024),
    );

void main() {
  late ProviderContainer container;
  late MockConversationRepository mockConversationRepo;
  late MockConversationManager mockConversationManager;
  late MockRef mockRef;
  late MockChecklistRepository mockChecklistRepo;
  late MockJournalRepository mockJournalRepo;
  late MockJournalDb mockJournalDb;
  late MockInferenceRepo mockInferenceRepo;
  late LottiConversationProcessor processor;

  setUpAll(() {
    registerFallbackValue(const ChatCompletionMessage.user(
      content: ChatCompletionUserMessageContent.string('u'),
    ));
    registerFallbackValue(<ChatCompletionMessage>[]);
    registerFallbackValue(<ChatCompletionTool>[]);
    registerFallbackValue(AiConfigInferenceProvider(
      id: 'ollama',
      name: 'Ollama',
      inferenceProviderType: InferenceProviderType.ollama,
      baseUrl: 'http://localhost:11434',
      apiKey: '',
      createdAt: DateTime(2024),
    ));
    // Fallbacks for mocktail any<T>() usage
    registerFallbackValue(TestDataFactory.createTask());
    registerFallbackValue(MockInferenceRepo());
  });

  // Helper: stub sendMessage to directly invoke the provided strategy
  void stubSendMessageToInvokeStrategy({
    required ConversationRepository repo,
    required ConversationManager manager,
    required List<ChatCompletionMessageToolCall> toolCalls,
  }) {
    when(() => repo.sendMessage(
          conversationId: any(named: 'conversationId'),
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
          toolCalls: toolCalls,
          manager: manager,
        );
      }
    });

    // Looser matcher in case optional named args differ
    when(() => repo.sendMessage(
          conversationId: any(named: 'conversationId'),
          message: any(named: 'message'),
          model: any(named: 'model'),
          provider: any(named: 'provider'),
          inferenceRepo: any(named: 'inferenceRepo'),
        )).thenAnswer((invocation) async {
      final strategy =
          invocation.namedArguments[#strategy] as ConversationStrategy?;
      if (strategy != null) {
        await strategy.processToolCalls(
          toolCalls: toolCalls,
          manager: manager,
        );
      }
    });
  }

  setUp(() {
    container = ProviderContainer();
    mockConversationRepo = MockConversationRepository();
    mockConversationManager = MockConversationManager();
    mockRef = MockRef();
    mockChecklistRepo = MockChecklistRepository();
    mockJournalRepo = MockJournalRepository();
    mockJournalDb = MockJournalDb();
    mockInferenceRepo = MockInferenceRepo();

    // getIt setup
    getIt
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<LoggingService>(LoggingService())
      ..registerSingleton<LoggingDb>(LoggingDb(inMemoryDatabase: true));

    // Ref wiring: use mock ConversationRepository
    when(() => mockRef.read(conversationRepositoryProvider.notifier))
        .thenReturn(mockConversationRepo);
    when(() => mockRef.read(checklistRepositoryProvider))
        .thenReturn(mockChecklistRepo);
    when(() => mockRef.read(journalRepositoryProvider))
        .thenReturn(mockJournalRepo);

    processor = LottiConversationProcessor(ref: mockRef);

    // Conversation wiring
    when(() => mockConversationRepo.createConversation(
          systemMessage: any(named: 'systemMessage'),
          maxTurns: any(named: 'maxTurns'),
        )).thenReturn('test-conv');
    when(() => mockConversationRepo.getConversation(any()))
        .thenReturn(mockConversationManager);
    when(() => mockConversationRepo.deleteConversation(any())).thenReturn(null);
    when(() => mockConversationManager.messages).thenReturn([]);
    when(() => mockConversationManager.events)
        .thenAnswer((_) => StreamController<ConversationEvent>().stream);
    when(() => mockConversationManager.addToolResponse(
          toolCallId: any(named: 'toolCallId'),
          response: any(named: 'response'),
        )).thenReturn(null);
  });

  tearDown(() {
    getIt.reset();
    container.dispose();
  });

  group('LottiConversationProcessor via ConversationRepository', () {
    test('non-GPT-OSS model: batch tool call creates multiple items', () async {
      final task = TestDataFactory.createTask();
      final promptConfig = TestDataFactory.createPromptConfig();
      final model = TestDataFactory.createModel(name: 'llama3.2:3b');

      // Stub sendMessage to invoke strategy with batch tool call
      const batchToolCall = ChatCompletionMessageToolCall(
        id: 'tool-0',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'add_multiple_checklist_items',
          arguments: '{"items": [{"title": "milk"}, {"title": "eggs"}] }',
        ),
      );
      stubSendMessageToInvokeStrategy(
        repo: mockConversationRepo,
        manager: mockConversationManager,
        toolCalls: const [batchToolCall],
      );

      // Checklist creation: no existing checklist -> auto create
      when(() => mockChecklistRepo.createChecklist(
            taskId: any(named: 'taskId'),
            items: any(named: 'items'),
            title: any(named: 'title'),
          )).thenAnswer((invocation) async {
        final items = (invocation.namedArguments[#items] as List)
            .cast<ChecklistItemData>();
        final checklist = Checklist(
          meta: Metadata(
            id: 'ck',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            categoryId: 'test-category',
          ),
          data: ChecklistData(
            title: 'TODOs',
            linkedChecklistItems:
                List.generate(items.length, (i) => 'id${i + 1}'),
            linkedTasks: const [],
          ),
        );
        final created = <({String id, String title, bool isChecked})>[];
        for (var i = 0; i < items.length; i++) {
          created.add((
            id: 'id${i + 1}',
            title: items[i].title,
            isChecked: items[i].isChecked
          ));
        }
        return (checklist: checklist, createdItems: created);
      });
      var callsTaskLookup1 = 0;
      when(() => mockJournalDb.journalEntityById(task.meta.id))
          .thenAnswer((_) async {
        callsTaskLookup1++;
        // Allow multiple reads before creation; switch after creation path
        if (callsTaskLookup1 > 2) {
          return TestDataFactory.createTask(
            id: task.meta.id,
            checklistIds: const ['ck'],
          );
        }
        return task;
      });
      when(() => mockJournalDb.journalEntityById('ck'))
          .thenAnswer((_) async => Checklist(
                meta: Metadata(
                  id: 'ck',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  dateFrom: DateTime.now(),
                  dateTo: DateTime.now(),
                  categoryId: 'test-category',
                ),
                data: const ChecklistData(
                  title: 'TODOs',
                  linkedChecklistItems: [],
                  linkedTasks: [],
                ),
              ));

      when(() => mockChecklistRepo.addItemToChecklist(
            checklistId: any(named: 'checklistId'),
            title: any(named: 'title'),
            isChecked: any(named: 'isChecked'),
            categoryId: any(named: 'categoryId'),
          )).thenAnswer((_) async => null);

      // Auto create checklist with two items
      when(() => mockJournalDb.journalEntityById('ck'))
          .thenAnswer((_) async => Checklist(
                meta: Metadata(
                  id: 'ck',
                  createdAt: DateTime(2024),
                  updatedAt: DateTime(2024),
                  dateFrom: DateTime(2024),
                  dateTo: DateTime(2024),
                  categoryId: 'test-category',
                ),
                data: const ChecklistData(
                  title: 'TODOs',
                  linkedChecklistItems: [],
                  linkedTasks: [],
                ),
              ));

      // Instead of autoChecklistService, the handlers construct via repo; we only need DB/Repo mocks

      final result = await processor.processPromptWithConversation(
        prompt: 'Add milk and eggs',
        entity: task,
        task: task,
        model: model,
        provider: provider(),
        promptConfig: promptConfig,
        systemMessage: checklistUpdatesPrompt.systemMessage,
        tools: const [],
        inferenceRepo: mockInferenceRepo,
      );

      expect(result.totalCreated, 2);
      expect(result.items, containsAll(['milk', 'eggs']));
    });

    test('single item creation via batch tool call', () async {
      final task = TestDataFactory.createTask();
      final promptConfig = TestDataFactory.createPromptConfig();
      final model = TestDataFactory.createModel();

      const singleToolCall = ChatCompletionMessageToolCall(
        id: 'tool-1',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'add_multiple_checklist_items',
          arguments: '{"items": [{"title": "buy milk"}]}',
        ),
      );
      stubSendMessageToInvokeStrategy(
        repo: mockConversationRepo,
        manager: mockConversationManager,
        toolCalls: const [singleToolCall],
      );

      // No existing checklist -> auto create
      var callsTaskLookup2 = 0;
      when(() => mockJournalDb.journalEntityById(task.meta.id))
          .thenAnswer((_) async {
        callsTaskLookup2++;
        if (callsTaskLookup2 > 2) {
          return TestDataFactory.createTask(
            id: task.meta.id,
            checklistIds: const ['new-ck'],
          );
        }
        return task;
      });
      when(() => mockChecklistRepo.createChecklist(
            taskId: any(named: 'taskId'),
            items: any(named: 'items'),
            title: any(named: 'title'),
          )).thenAnswer((invocation) async {
        final items = (invocation.namedArguments[#items] as List)
            .cast<ChecklistItemData>();
        final checklist = Checklist(
          meta: Metadata(
            id: 'new-ck',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            dateFrom: DateTime.now(),
            dateTo: DateTime.now(),
            categoryId: 'test-category',
          ),
          data: const ChecklistData(
            title: 'TODOs',
            linkedChecklistItems: ['id1'],
            linkedTasks: [],
          ),
        );
        final created = <({String id, String title, bool isChecked})>[
          if (items.isNotEmpty)
            (
              id: 'id1',
              title: items.first.title,
              isChecked: items.first.isChecked
            ),
        ];
        return (checklist: checklist, createdItems: created);
      });
      when(() => mockJournalDb.journalEntityById('new-ck'))
          .thenAnswer((_) async => Checklist(
                meta: Metadata(
                  id: 'new-ck',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  dateFrom: DateTime.now(),
                  dateTo: DateTime.now(),
                  categoryId: 'test-category',
                ),
                data: const ChecklistData(
                  title: 'TODOs',
                  linkedChecklistItems: [],
                  linkedTasks: [],
                ),
              ));

      final result = await processor.processPromptWithConversation(
        prompt: 'Add buy milk',
        entity: task,
        task: task,
        model: model,
        provider: provider(),
        promptConfig: promptConfig,
        systemMessage: checklistUpdatesPrompt.systemMessage,
        tools: const [],
        inferenceRepo: mockInferenceRepo,
      );

      expect(result.totalCreated, 1);
      expect(result.items, contains('buy milk'));
    });

    test('batch creation creates three items', () async {
      final task = TestDataFactory.createTask();
      final promptConfig = TestDataFactory.createPromptConfig();
      final model = TestDataFactory.createModel();

      const batch3 = ChatCompletionMessageToolCall(
        id: 'tool-2',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'add_multiple_checklist_items',
          arguments:
              '{"items": [{"title": "cheese"}, {"title": "tomatoes"}, {"title": "pepperoni"}]}',
        ),
      );
      stubSendMessageToInvokeStrategy(
        repo: mockConversationRepo,
        manager: mockConversationManager,
        toolCalls: const [batch3],
      );

      var callsTaskLookup3 = 0;
      when(() => mockJournalDb.journalEntityById(task.meta.id))
          .thenAnswer((_) async {
        callsTaskLookup3++;
        if (callsTaskLookup3 > 2) {
          return TestDataFactory.createTask(
            id: task.meta.id,
            checklistIds: const ['ck-batch'],
          );
        }
        return task;
      });
      when(() => mockChecklistRepo.createChecklist(
            taskId: any(named: 'taskId'),
            items: any(named: 'items'),
            title: any(named: 'title'),
          )).thenAnswer((invocation) async {
        final items = (invocation.namedArguments[#items] as List)
            .cast<ChecklistItemData>();
        final checklist = Checklist(
          meta: Metadata(
            id: 'ck-batch',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            dateFrom: DateTime(2024),
            dateTo: DateTime(2024),
            categoryId: 'test-category',
          ),
          data: const ChecklistData(
            title: 'TODOs',
            linkedChecklistItems: ['id1', 'id2', 'id3'],
            linkedTasks: [],
          ),
        );
        final created = <({String id, String title, bool isChecked})>[
          (id: 'id1', title: items[0].title, isChecked: items[0].isChecked),
          (id: 'id2', title: items[1].title, isChecked: items[1].isChecked),
          (id: 'id3', title: items[2].title, isChecked: items[2].isChecked),
        ];
        return (checklist: checklist, createdItems: created);
      });
      when(() => mockJournalDb.journalEntityById('ck-batch'))
          .thenAnswer((_) async => Checklist(
                meta: Metadata(
                  id: 'ck-batch',
                  createdAt: DateTime(2024),
                  updatedAt: DateTime(2024),
                  dateFrom: DateTime(2024),
                  dateTo: DateTime(2024),
                  categoryId: 'test-category',
                ),
                data: const ChecklistData(
                  title: 'TODOs',
                  linkedChecklistItems: [],
                  linkedTasks: [],
                ),
              ));

      final result = await processor.processPromptWithConversation(
        prompt: 'Add pizza',
        entity: task,
        task: task,
        model: model,
        provider: provider(),
        promptConfig: promptConfig,
        systemMessage: checklistUpdatesPrompt.systemMessage,
        tools: const [],
        inferenceRepo: mockInferenceRepo,
      );

      expect(result.totalCreated, 3);
      expect(result.items, containsAll(['cheese', 'tomatoes', 'pepperoni']));
    });

    test('GPT-OSS model: batch tool call creates multiple items', () async {
      final task = TestDataFactory.createTask();
      final promptConfig = TestDataFactory.createPromptConfig();
      final model = TestDataFactory.createModel(name: 'gpt-oss:20b');

      const gptossBatch = ChatCompletionMessageToolCall(
        id: 'tool-3',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'add_multiple_checklist_items',
          arguments:
              '{"items": [{"title": "apples"}, {"title": "bananas"}, {"title": "cereal"}]}',
        ),
      );
      stubSendMessageToInvokeStrategy(
        repo: mockConversationRepo,
        manager: mockConversationManager,
        toolCalls: const [gptossBatch],
      );

      var callsTaskLookup4 = 0;
      when(() => mockJournalDb.journalEntityById(task.meta.id))
          .thenAnswer((_) async {
        callsTaskLookup4++;
        // After language + checklist creation
        if (callsTaskLookup4 > 2) {
          return TestDataFactory.createTask(
            id: task.meta.id,
            languageCode: 'es',
            checklistIds: const ['ck-new'],
          );
        }
        return task;
      });
      when(() => mockChecklistRepo.createChecklist(
            taskId: any(named: 'taskId'),
            items: any(named: 'items'),
            title: any(named: 'title'),
          )).thenAnswer((invocation) async {
        final items = (invocation.namedArguments[#items] as List)
            .cast<ChecklistItemData>();
        final checklist = Checklist(
          meta: Metadata(
            id: 'ck',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            dateFrom: DateTime(2024),
            dateTo: DateTime(2024),
            categoryId: 'test-category',
          ),
          data: const ChecklistData(
            title: 'TODOs',
            linkedChecklistItems: ['id1', 'id2', 'id3'],
            linkedTasks: [],
          ),
        );
        final created = <({String id, String title, bool isChecked})>[
          (id: 'id1', title: items[0].title, isChecked: items[0].isChecked),
          (id: 'id2', title: items[1].title, isChecked: items[1].isChecked),
          (id: 'id3', title: items[2].title, isChecked: items[2].isChecked),
        ];
        return (checklist: checklist, createdItems: created);
      });
      when(() => mockJournalDb.journalEntityById('ck'))
          .thenAnswer((_) async => Checklist(
                meta: Metadata(
                  id: 'ck',
                  createdAt: DateTime(2024),
                  updatedAt: DateTime(2024),
                  dateFrom: DateTime(2024),
                  dateTo: DateTime(2024),
                  categoryId: 'test-category',
                ),
                data: const ChecklistData(
                  title: 'TODOs',
                  linkedChecklistItems: [],
                  linkedTasks: [],
                ),
              ));

      final result = await processor.processPromptWithConversation(
        prompt: 'Add shopping',
        entity: task,
        task: task,
        model: model,
        provider: provider(),
        promptConfig: promptConfig,
        systemMessage: checklistUpdatesPrompt.systemMessage,
        tools: const [],
        inferenceRepo: mockInferenceRepo,
      );

      expect(result.totalCreated, 3);
      expect(result.items, containsAll(['apples', 'bananas', 'cereal']));
    });

    test('language detection before checklist creation', () async {
      final task = TestDataFactory.createTask();
      final promptConfig = TestDataFactory.createPromptConfig();
      final model = TestDataFactory.createModel();

      // Stub sendMessage to invoke language detection then batch create
      const langCall = ChatCompletionMessageToolCall(
        id: 'tool-10',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'set_task_language',
          arguments:
              '{"languageCode": "es", "confidence": "high", "reason": "Spanish detected"}',
        ),
      );
      const createCall = ChatCompletionMessageToolCall(
        id: 'tool-11',
        type: ChatCompletionMessageToolCallType.function,
        function: ChatCompletionMessageFunctionCall(
          name: 'add_multiple_checklist_items',
          arguments: '{"items": [{"title": "comprar leche"}]}',
        ),
      );
      stubSendMessageToInvokeStrategy(
        repo: mockConversationRepo,
        manager: mockConversationManager,
        toolCalls: const [langCall, createCall],
      );

      // Journal repo update for language
      when(() => mockJournalRepo.updateJournalEntity(any<Task>()))
          .thenAnswer((_) async => true);

      // DB state: first returns task w/o checklist but later with checklist + language set
      var callsTaskLookupLang = 0;
      when(() => mockJournalDb.journalEntityById(task.meta.id))
          .thenAnswer((_) async {
        callsTaskLookupLang++;
        if (callsTaskLookupLang > 2) {
          return TestDataFactory.createTask(
            id: task.meta.id,
            languageCode: 'es',
            checklistIds: const ['ck-new'],
          );
        }
        return task;
      });
      when(() => mockChecklistRepo.createChecklist(
            taskId: any(named: 'taskId'),
            items: any(named: 'items'),
            title: any(named: 'title'),
          )).thenAnswer((invocation) async {
        final items = (invocation.namedArguments[#items] as List)
            .cast<ChecklistItemData>();
        final checklist = Checklist(
          meta: Metadata(
            id: 'ck-new',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            dateFrom: DateTime(2024),
            dateTo: DateTime(2024),
            categoryId: 'test-category',
          ),
          data: const ChecklistData(
            title: 'TODOs',
            linkedChecklistItems: ['id1'],
            linkedTasks: [],
          ),
        );
        final created = <({String id, String title, bool isChecked})>[
          if (items.isNotEmpty)
            (
              id: 'id1',
              title: items.first.title,
              isChecked: items.first.isChecked
            ),
        ];
        return (checklist: checklist, createdItems: created);
      });
      when(() => mockJournalDb.journalEntityById('ck-new'))
          .thenAnswer((_) async => Checklist(
                meta: Metadata(
                  id: 'ck-new',
                  createdAt: DateTime(2024),
                  updatedAt: DateTime(2024),
                  dateFrom: DateTime(2024),
                  dateTo: DateTime(2024),
                  categoryId: 'test-category',
                ),
                data: const ChecklistData(
                  title: 'TODOs',
                  linkedChecklistItems: [],
                  linkedTasks: [],
                ),
              ));

      final result = await processor.processPromptWithConversation(
        prompt: 'Añadir comprar leche a mi lista',
        entity: task,
        task: task,
        model: model,
        provider: provider(),
        promptConfig: promptConfig,
        systemMessage: checklistUpdatesPrompt.systemMessage,
        tools: const [],
        inferenceRepo: mockInferenceRepo,
      );

      expect(result.totalCreated, 1);
      expect(result.items, contains('comprar leche'));
    });
  });
}
