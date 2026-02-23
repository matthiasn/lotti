import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/workflow/template_evolution_workflow.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../mocks/mocks.dart';
import '../test_utils.dart';

/// Test mock for ConversationRepository that controls the conversation flow.
class _TestConversationRepository extends ConversationRepository {
  _TestConversationRepository({this.assistantResponse});

  final String? assistantResponse;
  final List<String> deletedIds = [];

  @override
  void build() {}

  @override
  String createConversation({
    String? systemMessage,
    int maxTurns = 20,
  }) {
    return 'test-conv-id';
  }

  @override
  ConversationManager? getConversation(String conversationId) {
    if (assistantResponse == null) return null;

    final manager = ConversationManager(
      conversationId: conversationId,
      maxTurns: 1,
    )
      ..initialize()
      ..addAssistantMessage(content: assistantResponse);

    return manager;
  }

  @override
  void deleteConversation(String conversationId) {
    deletedIds.add(conversationId);
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
    // No-op: the assistant response is pre-loaded in getConversation.
  }
}

AiConfigInferenceProvider _testProvider({String apiKey = 'test-key'}) {
  return AiConfig.inferenceProvider(
    id: 'provider-1',
    baseUrl: 'https://generativelanguage.googleapis.com',
    name: 'Gemini',
    inferenceProviderType: InferenceProviderType.gemini,
    apiKey: apiKey,
    createdAt: DateTime(2024),
  ) as AiConfigInferenceProvider;
}

AiConfigModel _testModel() {
  return AiConfig.model(
    id: 'model-1',
    name: 'Test Model',
    providerModelId: 'models/gemini-3.1-pro-preview',
    inferenceProviderId: 'provider-1',
    createdAt: DateTime(2024),
    inputModalities: const [Modality.text],
    outputModalities: const [Modality.text],
    isReasoningModel: false,
  ) as AiConfigModel;
}

void main() {
  late MockAiConfigRepository mockAiConfig;
  late MockCloudInferenceRepository mockCloudInference;

  setUpAll(() {
    registerFallbackValue(AiConfigType.model);
  });

  setUp(() {
    mockAiConfig = MockAiConfigRepository();
    mockCloudInference = MockCloudInferenceRepository();
  });

  void stubProviderResolution({String apiKey = 'test-key'}) {
    when(() => mockAiConfig.getConfigsByType(AiConfigType.model))
        .thenAnswer((_) async => [_testModel()]);
    when(() => mockAiConfig.getConfigById('provider-1'))
        .thenAnswer((_) async => _testProvider(apiKey: apiKey));
  }

  group('EvolutionFeedback', () {
    test('isEmpty returns true when all fields are blank', () {
      const feedback = EvolutionFeedback();
      expect(feedback.isEmpty, isTrue);
    });

    test('isEmpty returns false when any field has content', () {
      const feedback = EvolutionFeedback(enjoyed: 'great reports');
      expect(feedback.isEmpty, isFalse);
    });

    test('isEmpty trims whitespace', () {
      const feedback = EvolutionFeedback(enjoyed: '   ');
      expect(feedback.isEmpty, isTrue);
    });
  });

  group('proposeEvolution', () {
    test('returns proposal when provider resolves and LLM responds', () async {
      final convRepo = _TestConversationRepository(
        assistantResponse: 'You are an improved agent.',
      );
      stubProviderResolution();

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: convRepo,
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
      );

      final version = makeTestTemplateVersion();
      final proposal = await workflow.proposeEvolution(
        template: makeTestTemplate(),
        currentVersion: version,
        metrics: makeTestMetrics(),
        feedback: const EvolutionFeedback(
          enjoyed: 'Clear reports',
          didntWork: 'Too verbose',
          specificChanges: 'Be more concise',
        ),
      );

      expect(proposal, isNotNull);
      expect(proposal!.proposedDirectives, 'You are an improved agent.');
      expect(proposal.originalDirectives, version.directives);
      expect(convRepo.deletedIds, contains('test-conv-id'));
    });

    test('strips markdown fences from LLM response', () async {
      final convRepo = _TestConversationRepository(
        assistantResponse: '```\nYou are a better agent.\n```',
      );
      stubProviderResolution();

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: convRepo,
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
      );

      final proposal = await workflow.proposeEvolution(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(),
        metrics: makeTestMetrics(),
        feedback: const EvolutionFeedback(enjoyed: 'good'),
      );

      expect(proposal, isNotNull);
      expect(proposal!.proposedDirectives, 'You are a better agent.');
    });

    test('returns null when model is not configured', () async {
      final convRepo = _TestConversationRepository();

      when(() => mockAiConfig.getConfigsByType(AiConfigType.model))
          .thenAnswer((_) async => []);

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: convRepo,
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
      );

      final proposal = await workflow.proposeEvolution(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(),
        metrics: makeTestMetrics(),
        feedback: const EvolutionFeedback(enjoyed: 'good'),
      );

      expect(proposal, isNull);
    });

    test('returns null when provider has no API key', () async {
      final convRepo = _TestConversationRepository();
      stubProviderResolution(apiKey: '');

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: convRepo,
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
      );

      final proposal = await workflow.proposeEvolution(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(),
        metrics: makeTestMetrics(),
        feedback: const EvolutionFeedback(enjoyed: 'good'),
      );

      expect(proposal, isNull);
    });

    test('cleans up conversation even when response is null', () async {
      final convRepo = _TestConversationRepository();
      stubProviderResolution();

      final workflow = TemplateEvolutionWorkflow(
        conversationRepository: convRepo,
        aiConfigRepository: mockAiConfig,
        cloudInferenceRepository: mockCloudInference,
      );

      final proposal = await workflow.proposeEvolution(
        template: makeTestTemplate(),
        currentVersion: makeTestTemplateVersion(),
        metrics: makeTestMetrics(),
        feedback: const EvolutionFeedback(enjoyed: 'good'),
      );

      expect(proposal, isNull);
      expect(convRepo.deletedIds, contains('test-conv-id'));
    });
  });

  group('stripMarkdownFences', () {
    test('strips triple backtick fences', () {
      expect(
        TemplateEvolutionWorkflow.stripMarkdownFences('```\nHello\n```'),
        'Hello',
      );
    });

    test('strips fences with language tag', () {
      expect(
        TemplateEvolutionWorkflow.stripMarkdownFences(
          '```text\nHello world\n```',
        ),
        'Hello world',
      );
    });

    test('leaves unfenced text unchanged', () {
      expect(
        TemplateEvolutionWorkflow.stripMarkdownFences('Just plain text'),
        'Just plain text',
      );
    });
  });
}
