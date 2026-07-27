import 'dart:collection';
import 'dart:convert';

import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/conversation/conversation_repository.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:openai_dart/openai_dart.dart';

typedef ScriptedToolCallBuilder =
    List<ChatCompletionMessageToolCall> Function(String message);

/// Fake, in-process [ConversationRepository]: replays scripted tool calls
/// through the *real* strategy/tool dispatch, so production tool handlers,
/// parsers and guards all run without a network call.
///
/// Turns are a queue, not a single value, because one wake can send more than
/// one message: when the model fails to produce the wake's required artifact,
/// `DayAgentWorkflow` issues a second `sendMessage` to force it. Scripting an
/// illegal first turn followed by a legal second is therefore how a
/// rejection-then-correction round trip is exercised offline — the shape the
/// eval's guarded constraints are scored on.
///
/// A send with nothing left in the queue yields no tool calls, which is how
/// production behaves when a model answers in prose: the workflow's forced
/// retry fires and, still empty-handed, the wake fails.
class ScriptedConversationRepository extends ConversationRepository {
  final Map<String, ConversationManager> _managers = {};
  final Queue<ScriptedToolCallBuilder> _turns = Queue();
  var _createdCount = 0;

  /// Every user message sent, in order.
  final List<String> userMessages = [];

  /// Tool names offered on each send, in the same order as [userMessages].
  final List<Set<String>> toolNamesBySend = [];

  /// Number of inference requests represented by this fake.
  int get sendCount => userMessages.length;

  /// System prompt of the most recently created conversation.
  String? lastSystemMessage;

  /// The most recent user message, or null when nothing has been sent.
  String? get lastUserMessage =>
      userMessages.isEmpty ? null : userMessages.last;

  /// Turns scripted but not yet consumed.
  int get pendingTurns => _turns.length;

  /// Queues one model turn. Call once per expected `sendMessage`.
  void script(List<ChatCompletionMessageToolCall> toolCalls) =>
      _turns.add((_) => toolCalls);

  /// Queues one model turn whose calls can be derived from the actual prompt.
  ///
  /// This is necessary for full-pipeline capture tests: production generates
  /// the capture id before enqueueing the parse wake, so a faithful script
  /// cannot know that id until it sees the rendered `<capture>` section.
  void scriptFromMessage(ScriptedToolCallBuilder builder) =>
      _turns.add(builder);

  @override
  String createConversation({String? systemMessage, int maxTurns = 20}) {
    _createdCount++;
    final id = 'conversation-$_createdCount';
    lastSystemMessage = systemMessage;
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
    String? consumptionAgentId,
    String? consumptionTaskId,
    String? consumptionCategoryId,
    String? consumptionWakeRunKey,
    String? consumptionThreadId,
    bool rethrowInferenceErrors = false,
  }) async {
    userMessages.add(message);
    toolNamesBySend.add({
      for (final tool in tools ?? const <ChatCompletionTool>[])
        tool.function.name,
    });
    final manager = _managers[conversationId]!..addUserMessage(message);
    final toolCalls = _turns.isEmpty
        ? const <ChatCompletionMessageToolCall>[]
        : _turns.removeFirst()(message);
    if (toolCalls.isNotEmpty) {
      manager.addAssistantMessage(toolCalls: toolCalls);
      await strategy!.processToolCalls(toolCalls: toolCalls, manager: manager);
    }
    return null;
  }

  @override
  void deleteConversation(String conversationId) {
    _managers.remove(conversationId)?.dispose();
  }
}

/// Builds one scripted tool call with JSON-encoded [args].
ChatCompletionMessageToolCall scriptedToolCall({
  required String id,
  required String name,
  required Map<String, Object?> args,
}) => ChatCompletionMessageToolCall(
  id: id,
  type: ChatCompletionMessageToolCallType.function,
  function: ChatCompletionMessageFunctionCall(
    name: name,
    arguments: jsonEncode(args),
  ),
);
