// A scripted ConversationRepository for the eval harness (ADR 0029).
//
// Generalises the private `_ConversationHarness` used in
// test/features/daily_os_next/agents/workflow/day_agent_workflow_test.dart so
// Level 1 scripted runs can drive the REAL agent workflows with a fixed model
// response (canned tool calls + a fixed InferenceUsage) instead of a live model.
// In Level 2 this is swapped for the real ConversationRepository wired to a
// resolved provider.

import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:openai_dart/openai_dart.dart';

import 'eval_endpoint_identity.dart';
import 'eval_models.dart';
import 'eval_provenance.dart';
import 'observing_conversation_repository.dart';

/// A [ConversationRepository] whose responses are scripted ahead of time.
class ScriptedConversationRepository extends ConversationRepository
    implements EvalConversationObserver {
  final Map<String, ConversationManager> _managers =
      <String, ConversationManager>{};

  /// Tool calls returned on every `sendMessage` unless
  /// [toolCallsByInvocation] has an entry for that turn.
  List<ChatCompletionMessageToolCall> toolCalls = const [];

  /// Per-turn tool calls (index 0 = first `sendMessage`, etc.).
  List<List<ChatCompletionMessageToolCall>> toolCallsByInvocation = const [];

  /// Assistant text that ends the conversation, if any.
  String? finalResponse;

  /// Usage returned on every `sendMessage` unless [usageByInvocation] applies.
  InferenceUsage? usage;

  /// Per-turn usage.
  List<InferenceUsage?> usageByInvocation = const [];

  /// If set, every `sendMessage` throws this (to exercise error paths).
  Exception? errorToThrow;

  int createdConversationCount = 0;
  int deletedConversationCount = 0;
  @override
  int sendMessageCount = 0;
  @override
  String? lastSystemMessage;
  @override
  String? lastUserMessage;
  @override
  String? lastModel;
  @override
  AiConfigInferenceProvider? lastProvider;
  double? lastTemperature;
  @override
  List<ChatCompletionTool> lastTools = const [];
  final List<ModelInvocationRecord> _modelInvocations =
      <ModelInvocationRecord>[];

  @override
  List<ModelInvocationRecord> get modelInvocations =>
      List.unmodifiable(_modelInvocations);

  @override
  List<ProviderRequestRecord> get providerRequests =>
      const <ProviderRequestRecord>[];

  @override
  String createConversation({String? systemMessage, int maxTurns = 20}) {
    createdConversationCount++;
    lastSystemMessage = systemMessage;
    final id = 'conversation-$createdConversationCount';
    _managers[id] = ConversationManager(conversationId: id, maxTurns: maxTurns)
      ..initialize(systemMessage: systemMessage);
    return id;
  }

  @override
  ConversationManager? getConversation(String conversationId) =>
      _managers[conversationId];

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
    final thrown = errorToThrow;
    if (thrown != null) throw thrown;

    lastUserMessage = message;
    lastModel = model;
    lastProvider = provider;
    lastTemperature = temperature;
    lastTools = tools ?? const [];
    final invocationIndex = sendMessageCount;
    sendMessageCount++;
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

    final manager = _managers[conversationId]!..addUserMessage(message);
    final selected = invocationIndex < toolCallsByInvocation.length
        ? toolCallsByInvocation[invocationIndex]
        : toolCalls;
    if (selected.isNotEmpty) {
      manager.addAssistantMessage(toolCalls: selected);
      await strategy!.processToolCalls(toolCalls: selected, manager: manager);
    }
    if (finalResponse != null) {
      manager.addAssistantMessage(content: finalResponse);
    }
    if (invocationIndex < usageByInvocation.length) {
      return usageByInvocation[invocationIndex];
    }
    return usage;
  }

  @override
  void deleteConversation(String conversationId) {
    deletedConversationCount++;
    _managers.remove(conversationId)?.dispose();
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
