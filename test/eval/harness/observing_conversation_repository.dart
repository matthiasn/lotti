// ConversationRepository wrapper for live eval runs.
//
// The workflow receives a real ConversationRepository so provider streaming,
// tool-call stitching, continuation prompts, and token accounting stay on the
// production path. This subclass only records the provider/model metadata that
// the eval trace needs for provenance and reliability checks.

import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:openai_dart/openai_dart.dart';

import 'eval_endpoint_identity.dart';
import 'eval_models.dart';
import 'eval_provenance.dart';

abstract interface class EvalConversationObserver {
  int get sendMessageCount;
  String? get lastSystemMessage;
  String? get lastUserMessage;
  List<ChatCompletionTool> get lastTools;
  String? get lastModel;
  AiConfigInferenceProvider? get lastProvider;
  List<ModelInvocationRecord> get modelInvocations;
  List<ProviderRequestRecord> get providerRequests;
  List<ProviderResponseRecord> get providerResponses;
}

class ObservingConversationRepository extends ConversationRepository
    implements EvalConversationObserver {
  @override
  int sendMessageCount = 0;

  @override
  String? lastSystemMessage;

  @override
  String? lastUserMessage;

  @override
  List<ChatCompletionTool> lastTools = const [];

  @override
  String? lastModel;

  @override
  AiConfigInferenceProvider? lastProvider;

  final List<ModelInvocationRecord> _modelInvocations =
      <ModelInvocationRecord>[];
  final List<ProviderRequestRecord> _providerRequests =
      <ProviderRequestRecord>[];
  final List<ProviderResponseRecord> _providerResponses =
      <ProviderResponseRecord>[];
  int? _activeInvocationIndex;

  @override
  List<ModelInvocationRecord> get modelInvocations =>
      List.unmodifiable(_modelInvocations);

  @override
  List<ProviderRequestRecord> get providerRequests =>
      List.unmodifiable(_providerRequests);

  @override
  List<ProviderResponseRecord> get providerResponses =>
      List.unmodifiable(_providerResponses);

  @override
  String createConversation({String? systemMessage, int maxTurns = 20}) {
    lastSystemMessage = systemMessage;
    return super.createConversation(
      systemMessage: systemMessage,
      maxTurns: maxTurns,
    );
  }

  @override
  Future<InferenceUsage?> sendMessage({
    required String conversationId,
    required String message,
    required String model,
    required AiConfigInferenceProvider provider,
    required InferenceRepositoryInterface inferenceRepo,
    List<ChatCompletionTool>? tools,
    ChatCompletionToolChoiceOption? toolChoice,
    double temperature = 0.7,
    ConversationStrategy? strategy,
  }) async {
    final invocationIndex = sendMessageCount;
    sendMessageCount++;
    lastUserMessage = message;
    lastTools = tools ?? const [];
    lastModel = model;
    lastProvider = provider;
    _modelInvocations.add(
      ModelInvocationRecord(
        invocationIndex: invocationIndex,
        providerModelId: model,
        providerId: provider.id,
        providerType: provider.inferenceProviderType.name,
        providerEndpointOrigin: evalProviderEndpointOrigin(provider.baseUrl),
        providerBaseUrlDigest: evalProviderBaseUrlDigest(provider.baseUrl),
        runtimePrompt: EvalProvenance.runtimePrompt(
          systemMessage: lastSystemMessage,
          userMessage: message,
          tools: tools ?? const [],
        ),
        toolNames: _toolNames(tools ?? const []),
        forcedToolName: _forcedToolName(toolChoice),
      ),
    );
    _activeInvocationIndex = invocationIndex;
    try {
      return await super.sendMessage(
        conversationId: conversationId,
        message: message,
        model: model,
        provider: provider,
        inferenceRepo: inferenceRepo,
        tools: tools,
        toolChoice: toolChoice,
        temperature: temperature,
        strategy: strategy,
      );
    } finally {
      _activeInvocationIndex = null;
    }
  }

  @override
  void observeProviderRequest(ConversationProviderRequest request) {
    _providerRequests.add(
      ProviderRequestRecord(
        invocationIndex: _activeInvocationIndex ?? -1,
        requestIndex: request.requestIndex,
        turnIndex: request.turnIndex,
        providerModelId: request.providerModelId,
        providerId: request.providerId,
        providerType: request.providerType,
        providerEndpointOrigin: _activeProviderEndpointOrigin(),
        providerBaseUrlDigest: _activeProviderBaseUrlDigest(),
        messageDigest: request.messageDigest,
        messageCount: request.messageCount,
        toolSchemaDigest: request.toolSchemaDigest,
        toolCount: request.toolCount,
        toolNames: request.toolNames,
        forcedToolName: request.forcedToolName,
        temperature: request.temperature,
        thoughtSignatureCount: request.thoughtSignatureCount,
      ),
    );
  }

  @override
  void observeProviderResponse(ConversationProviderResponse response) {
    _providerResponses.add(
      ProviderResponseRecord(
        invocationIndex: _activeInvocationIndex ?? -1,
        requestIndex: response.requestIndex,
        turnIndex: response.turnIndex,
        providerType: response.providerType,
        chunkCount: response.chunkCount,
        responseModelIds: _authoritativeResponseModelIds(
          response.responseModelIds,
        ),
        systemFingerprints: response.systemFingerprints,
        providerNames: response.providerNames,
        serviceTiers: response.serviceTiers,
        responseModelUnavailableReason: response.responseModelUnavailableReason,
      ),
    );
  }

  String? _activeProviderEndpointOrigin() {
    final provider = lastProvider;
    return provider == null
        ? null
        : evalProviderEndpointOrigin(provider.baseUrl);
  }

  String? _activeProviderBaseUrlDigest() {
    final provider = lastProvider;
    return provider == null
        ? null
        : evalProviderBaseUrlDigest(provider.baseUrl);
  }
}

List<String> _toolNames(List<ChatCompletionTool> tools) =>
    tools.map((tool) => tool.function.name).toList();

String? _forcedToolName(ChatCompletionToolChoiceOption? toolChoice) {
  return toolChoice?.map(
    mode: (_) => null,
    tool: (choice) => choice.value.function.name,
  );
}

List<String> _authoritativeResponseModelIds(List<String> responseModelIds) => [
  for (final modelId in responseModelIds)
    if (modelId.trim().toLowerCase() != 'keepalive') modelId,
];
