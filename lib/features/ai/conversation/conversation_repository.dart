import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/model/ai_call_impact.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:lotti/features/ai_consumption/model/ai_attribution.dart';
import 'package:lotti/features/ai_consumption/model/ai_consumption_enums.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_identity_resolver.dart';
import 'package:lotti/features/ai_consumption/service/ai_attribution_service.dart';
import 'package:lotti/features/ai_consumption/service/ai_interaction_capture.dart';
import 'package:lotti/get_it.dart';
import 'package:meta/meta.dart';
import 'package:openai_dart/openai_dart.dart' hide Error;
import 'package:uuid/uuid.dart';

/// Matches `<think>...</think>` and `<thinking>...</thinking>` blocks
/// (case-insensitive, possibly spanning newlines). Used to remove
/// chain-of-thought reasoning from assistant content before it is stored
/// in conversation history. Persisting and resending these blocks wastes
/// tokens and, for Gemma 4, violates Google's guidance that past
/// reasoning must not be carried forward into subsequent turns.
final _thinkBlockPattern = RegExp(
  r'<think(?:ing)?\b[^>]*>[\s\S]*?</think(?:ing)?>',
  caseSensitive: false,
);

/// Removes `<think>`/`<thinking>` reasoning blocks from assistant [content]
/// before it is stored in conversation history (see [_thinkBlockPattern]).
/// Returns null when the input is null or nothing meaningful remains after
/// stripping and trimming.
@visibleForTesting
String? stripThinkBlocks(String? content) {
  if (content == null) return null;
  final stripped = content.replaceAll(_thinkBlockPattern, '').trim();
  return stripped.isEmpty ? null : stripped;
}

/// Repository for managing AI conversations.
///
/// Streaming expectations for tool calls (for providers and tests):
/// - Tool calls may arrive across multiple streamed chunks. The repository stitches
///   chunks using a stable `id` or `index` per tool call and accumulates `function.arguments`.
/// - Providers emitting OpenAI‑style deltas should keep id/index stable across chunks.
/// - In tests, you can bypass stream chunking complexity by stubbing `sendMessage` and directly
///   invoking the provided `ConversationStrategy` with predefined
///   `ChatCompletionMessageToolCall` objects. This preserves the strategy/handler execution path
///   while avoiding brittle mock setups.
final NotifierProvider<ConversationRepository, void>
conversationRepositoryProvider =
    NotifierProvider.autoDispose<ConversationRepository, void>(
      ConversationRepository.new,
      name: 'conversationRepositoryProvider',
    );

/// The result recorded for a tool call the loop ended without running (see
/// [ConversationManager.answerPendingToolCalls]).
@visibleForTesting
const unansweredToolCallResult =
    'Error: this tool call was not executed, so it has no result.';

class ConversationRepository extends Notifier<void> {
  final _conversations = <String, ConversationManager>{};

  /// Completes when the latest [sendMessage] queued on a conversation has
  /// returned; the next one waits for it (see [_serialized]).
  final _sendQueues = <String, Completer<void>>{};
  final _uuid = const Uuid();

  @override
  void build() {
    ref.onDispose(_conversations.clear);
  }

  /// Create a new conversation
  String createConversation({
    String? systemMessage,
    int maxTurns = 20,
  }) {
    final conversationId = _uuid.v4();
    final manager = ConversationManager(
      maxTurns: maxTurns,
    )..initialize(systemMessage: systemMessage);
    _conversations[conversationId] = manager;

    return conversationId;
  }

  /// True when a streamed delta looks like Gemini's style of sending
  /// multiple *complete* tool calls in a single chunk: more than one entry,
  /// all with empty/absent ids, null indices, and non-empty arguments.
  @visibleForTesting
  static bool isGeminiStyleToolCallDelta(
    List<ChatCompletionStreamMessageToolCallChunk> chunks,
  ) {
    return chunks.length > 1 &&
        chunks.every(
          (tc) =>
              (tc.id == null || tc.id!.isEmpty) &&
              tc.index == null &&
              tc.function?.arguments != null &&
              tc.function!.arguments!.isNotEmpty,
        );
  }

  /// The id synthesized for the [n]th tool call of [turn] when the provider
  /// sends none. Unique across the conversation because
  /// [ConversationManager.turnCount] never goes back.
  static String _turnScopedToolCallId(int turn, int n) => 'tool_turn${turn}_$n';

  /// Appends Gemini's complete-in-one-chunk tool calls to [toolCalls],
  /// synthesizing ids unique across conversation turns
  /// ([_turnScopedToolCallId]).
  @visibleForTesting
  static void appendGeminiToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required List<ChatCompletionStreamMessageToolCallChunk> chunks,
    required int turn,
  }) {
    for (final toolCallChunk in chunks) {
      if (toolCallChunk.function != null) {
        final toolCallId = _turnScopedToolCallId(turn, toolCalls.length);
        toolCalls.add(
          ChatCompletionMessageToolCall(
            id: toolCallId,
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: toolCallChunk.function!.name ?? '',
              arguments: toolCallChunk.function!.arguments ?? '',
            ),
          ),
        );
      }
    }
  }

  /// Standard OpenAI-style streaming accumulation: tool-call argument
  /// fragments are stitched per tool call via [argumentBuffers] so JSON split
  /// across chunks — even mid-character — reassembles intact.
  ///
  /// A chunk with an id continues the call with that id, or starts a new one
  /// when the id is new, even if its index is taken: some providers number
  /// every call 0. A chunk without an id (an empty one counts as none)
  /// continues the call at its index. A new call without an id gets
  /// [_turnScopedToolCallId] for [turn].
  @visibleForTesting
  static void accumulateOpenAiToolCallChunks({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required Map<String, StringBuffer> argumentBuffers,
    required List<ChatCompletionStreamMessageToolCallChunk> chunks,
    required int turn,
  }) {
    for (final toolCallChunk in chunks) {
      final chunkId = toolCallChunk.id;
      final hasId = chunkId != null && chunkId.isNotEmpty;
      var existingIndex = -1;

      if (hasId) {
        existingIndex = toolCalls.indexWhere((tc) => tc.id == chunkId);
      } else if (toolCallChunk.index != null) {
        final chunkIndex = toolCallChunk.index!;
        if (chunkIndex < toolCalls.length) {
          existingIndex = chunkIndex;
        }
      }

      if (existingIndex >= 0) {
        // Append to existing tool call's argument buffer
        final existing = toolCalls[existingIndex];
        final toolCallKey = existing.id;

        // Get or create buffer for this tool call
        final buffer =
            argumentBuffers[toolCallKey] ??
            StringBuffer(existing.function.arguments);
        argumentBuffers[toolCallKey] = buffer;

        // Append new chunk to buffer
        buffer.write(toolCallChunk.function?.arguments ?? '');

        // Update the tool call with buffered arguments
        toolCalls[existingIndex] = ChatCompletionMessageToolCall(
          id: existing.id,
          type: existing.type,
          function: ChatCompletionMessageFunctionCall(
            name: existing.function.name,
            arguments: buffer.toString(),
          ),
        );
      } else if (toolCallChunk.function != null) {
        // Add new tool call
        final toolCallId = hasId
            ? chunkId
            : _turnScopedToolCallId(
                turn,
                toolCallChunk.index ?? toolCalls.length,
              );

        // Initialize buffer for new tool call
        final initialArgs = toolCallChunk.function!.arguments ?? '';
        argumentBuffers[toolCallId] = StringBuffer(initialArgs);

        toolCalls.add(
          ChatCompletionMessageToolCall(
            id: toolCallId,
            type: ChatCompletionMessageToolCallType.function,
            function: ChatCompletionMessageFunctionCall(
              name: toolCallChunk.function!.name ?? '',
              arguments: initialArgs,
            ),
          ),
        );
      }
    }
  }

  /// Get a conversation manager
  ConversationManager? getConversation(String conversationId) {
    return _conversations[conversationId];
  }

  /// Send a message in a conversation.
  ///
  /// Calls on one conversation run one at a time, in the order they were
  /// made: a second call waits until the first has returned. The loop ends
  /// when the strategy stops, a reply has no tool calls, or
  /// [ConversationManager.canContinue] refuses the next turn; any tool call
  /// it leaves unanswered is answered with [unansweredToolCallResult].
  ///
  /// When [toolChoice] is supplied it overrides the provider default (`auto`)
  /// for every inference call this `sendMessage` makes. This is the hook the
  /// Task Agent uses to force a terminal `update_report` call when a weaker
  /// model stopped early without publishing its report. Currently honored
  /// on provider adapters that support forced tools. Adapters that do not
  /// support it should make that limitation explicit instead of silently
  /// dropping the constraint.
  ///
  /// Returns the accumulated [InferenceUsage] across all turns, or `null`
  /// if no usage data was reported by the inference provider.
  ///
  /// Set [rethrowInferenceErrors] for orchestration that owns retry/failure
  /// state. Interactive callers keep the default behavior, which stores the
  /// error in [ConversationManager.lastError] and ends the conversation.
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
    // Owner ids for per-turn consumption recording. When [consumptionAgentId]
    // is null, recording is skipped (non-agent callers). Agent workflows pass
    // these so each turn is attributed to the task/category/wake.
    String? consumptionAgentId,
    String? consumptionTaskId,
    String? consumptionCategoryId,
    String? consumptionWakeRunKey,
    String? consumptionThreadId,
    bool rethrowInferenceErrors = false,
  }) => _serialized(conversationId, () async {
    final manager = _conversations[conversationId];
    if (manager == null) {
      throw ArgumentError('Conversation $conversationId not found');
    }

    // Clear the prior request state before adding this user turn.
    manager
      ..clearLastError()
      ..addUserMessage(message);

    // Check if we can continue
    if (!manager.canContinue()) {
      manager.lastError = 'Maximum conversation turns reached';
      return null;
    }

    final capture = getIt.isRegistered<AiInteractionCapture>()
        ? getIt<AiInteractionCapture>()
        : null;
    AiAttributionSession? attributionSession;
    if (capture != null) {
      final agentId = consumptionAgentId;
      final initiator = agentId == null
          ? null
          : await getIt<AiAttributionIdentityResolver>().agentInitiator(
              id: agentId,
              displayName: agentId,
            );
      attributionSession = await capture.beginSession(
        workType: agentId == null
            ? AiWorkType.textGeneration
            : AiWorkType.agentReport,
        trigger: AiTriggerSnapshot(
          type: agentId == null
              ? AiTriggerType.manual
              : AiTriggerType.agentTool,
          agentId: agentId,
          wakeRunKey: consumptionWakeRunKey,
        ),
        initiator: initiator,
        attributionId: consumptionWakeRunKey == null
            ? null
            : agentWakeAttributionId(consumptionWakeRunKey),
        taskId: consumptionTaskId,
        categoryId: consumptionCategoryId,
      );
    }

    // OpenAI GPT-5 models only accept temperature=1.0 (the default).
    // Other providers support custom temperature values.
    final effectiveTemperature =
        provider.inferenceProviderType == InferenceProviderType.openAi
        ? 1.0
        : temperature;

    // Start conversation loop
    var shouldContinue = true;
    var nonAgentStreamFailed = false;
    var accumulated = InferenceUsage.empty;

    while (shouldContinue) {
      try {
        // Get all messages for the request
        final messages = manager.getMessagesForRequest();

        // Create signature collector for this turn (Gemini 3 multi-turn support)
        final signatureCollector = ThoughtSignatureCollector();
        // Per-turn cost/energy side-channel (Melious populates it) + timing and
        // the turn index captured before the request advances the count.
        final impactCollector = InferenceImpactCollector();
        final turnIndex = manager.turnCount;
        // `turnCount` counts user messages and this turn's user message is
        // already in the log, so the first request sees 1. Strategies reason
        // about "the opening turn", so they get a zero-based index while
        // provider calls and telemetry keep the one-based value they had.
        final strategyTurnIndex = turnIndex > 0 ? turnIndex - 1 : 0;
        // Ask the strategy what to advertise for this turn. Without this the
        // list captured at sendMessage is reused for every turn, so a wake
        // cannot narrow its opening turn and widen later.
        // A forced `toolChoice` means the caller is constraining this call to
        // one named tool and passed the matching one-tool list — the report-only
        // retry does exactly that. A staging strategy must not widen it back,
        // or a provider that ignores `toolChoice` could reach a mutation tool
        // during report recovery.
        // `ChatCompletionToolChoiceOption` is a union: `.mode(auto|none|...)`
        // or `.tool(named)`. Only the named-tool variant means the caller
        // pinned this call to one tool.
        final callerConstrainedTools =
            toolChoice
                is ChatCompletionToolChoiceOptionChatCompletionNamedToolChoice;
        final turnTools =
            (callerConstrainedTools
                ? null
                : strategy?.toolsForTurn(
                    turnIndex: strategyTurnIndex,
                    manager: manager,
                  )) ??
            tools;

        // Collect response
        final toolCalls = <ChatCompletionMessageToolCall>[];
        final contentBuffer = StringBuffer();
        // Use StringBuffer for each tool call to safely accumulate arguments
        // This prevents JSON corruption when chunks are split mid-character or arrive out of order
        final toolCallArgumentBuffers = <String, StringBuffer>{};
        InferenceUsage? turnUsage;

        try {
          // Make the provider call with full conversation history. The
          // rethrow contract is intentionally scoped to this stream only;
          // post-inference telemetry and tool handling degrade gracefully.
          Stream<CreateChatCompletionStreamResponse> invoke() =>
              inferenceRepo.generateTextWithMessages(
                messages: messages,
                model: model,
                provider: provider,
                tools: turnTools,
                toolChoice: toolChoice,
                temperature: effectiveTemperature,
                thoughtSignatures: manager.thoughtSignatures,
                signatureCollector: signatureCollector,
                turnIndex: turnIndex,
                impactCollector: impactCollector,
              );
          final stream = capture == null
              ? invoke()
              : capture.captureStream(
                  workType: consumptionAgentId == null
                      ? AiWorkType.textGeneration
                      : AiWorkType.agentReport,
                  interactionKind: AiInteractionKind.chatCompletion,
                  responseType: consumptionAgentId == null
                      ? AiConsumptionResponseType.textGeneration
                      : AiConsumptionResponseType.agentTurn,
                  providerType: provider.inferenceProviderType,
                  modelId: model,
                  requestText: messages.toString(),
                  invoke: invoke,
                  responseText: (chunk) =>
                      chunk.choices?.firstOrNull?.delta?.content ?? '',
                  usageForChunk: (chunk) {
                    final chunkUsage = chunk.usage;
                    if (chunkUsage == null) return null;
                    return AiCapturedUsage(
                      inputTokens: chunkUsage.promptTokens,
                      outputTokens: chunkUsage.completionTokens,
                      cachedInputTokens:
                          chunkUsage.promptTokensDetails?.cachedTokens,
                      thoughtsTokens:
                          chunkUsage.completionTokensDetails?.reasoningTokens,
                      totalTokens: chunkUsage.totalTokens,
                    );
                  },
                  impact: () => impactCollector.impact,
                  interactionContext: AiCapturedContext(
                    parentId: consumptionWakeRunKey,
                    agentId: consumptionAgentId,
                    wakeRunKey: consumptionWakeRunKey,
                    threadId: consumptionThreadId,
                    turnIndex: turnIndex,
                  ),
                  existingSession: attributionSession,
                  terminalizeSuccess: false,
                  // Agent workflows own their wake's terminal attribution.
                  // A standalone chat has no outer coordinator, so the
                  // capture boundary must terminalize a failed stream itself.
                  terminalizeFailure: consumptionAgentId == null,
                  taskId: consumptionTaskId,
                  categoryId: consumptionCategoryId,
                );

          await for (final response in stream) {
            // Capture usage from the response (typically on the final chunk).
            if (response.usage != null) {
              final u = response.usage!;
              turnUsage = InferenceUsage(
                inputTokens: u.promptTokens,
                outputTokens: u.completionTokens,
                thoughtsTokens: u.completionTokensDetails?.reasoningTokens,
                cachedInputTokens: u.promptTokensDetails?.cachedTokens,
              );
            }
            if (response.choices?.isNotEmpty ?? false) {
              final delta = response.choices!.first.delta;

              // Collect content
              if (delta?.content != null) {
                contentBuffer.write(delta!.content);
              }

              // Collect tool calls
              if (delta?.toolCalls != null) {
                final chunks = delta!.toolCalls!;
                if (isGeminiStyleToolCallDelta(chunks)) {
                  appendGeminiToolCalls(
                    toolCalls: toolCalls,
                    chunks: chunks,
                    turn: turnIndex,
                  );
                } else {
                  accumulateOpenAiToolCallChunks(
                    toolCalls: toolCalls,
                    argumentBuffers: toolCallArgumentBuffers,
                    chunks: chunks,
                    turn: turnIndex,
                  );
                }
              }
            }
          }
        } catch (e, stackTrace) {
          nonAgentStreamFailed = consumptionAgentId == null;
          if (turnUsage != null) {
            accumulated = accumulated.merge(turnUsage);
          }
          _storeTurnError(manager, e, stackTrace);
          if (rethrowInferenceErrors) {
            throw _RethrownInferenceError(e, stackTrace);
          }
          shouldContinue = false;
          continue;
        }

        // Accumulate token usage from this turn.
        if (turnUsage != null) {
          accumulated = accumulated.merge(turnUsage);
        }

        // Add assistant message.
        //
        // Strip `<think>...</think>` blocks before persisting. The streaming
        // UI has already received the thinking content in real time; what
        // gets stored here is later resent on subsequent turns via
        // `getMessagesForRequest()`, and we must not echo past reasoning
        // back to the model.
        final rawContent = contentBuffer.toString();
        final persistedContent = stripThinkBlocks(rawContent);

        developer.log(
          'Stream completed: collected ${toolCalls.length} tool calls, '
          '${rawContent.length} chars of content '
          '(${persistedContent?.length ?? 0} chars after stripping think blocks), '
          '${signatureCollector.signatures.length} signatures captured',
          name: 'ConversationRepository',
        );

        // Pass captured signatures to manager for use in subsequent turns
        manager.addAssistantMessage(
          content: persistedContent,
          toolCalls: toolCalls.isNotEmpty ? toolCalls : null,
          signatures: signatureCollector.hasSignatures
              ? signatureCollector.signatures
              : null,
        );

        // Process with strategy if provided
        if (strategy != null && toolCalls.isNotEmpty) {
          developer.log(
            'Processing ${toolCalls.length} tool calls with strategy',
            name: 'ConversationRepository',
          );
          final action = await strategy.processToolCalls(
            toolCalls: toolCalls,
            manager: manager,
          );

          switch (action) {
            case ConversationAction.continueConversation:
              // Get continuation prompt
              final continuationPrompt = strategy.getContinuationPrompt(
                manager,
              );
              if (continuationPrompt != null) {
                manager.addUserMessage(continuationPrompt);
                // Continue loop
              } else {
                shouldContinue = false;
              }

            case ConversationAction.complete:
            case ConversationAction.wait:
              shouldContinue = false;
          }
        } else {
          // No strategy or no tool calls - end conversation
          shouldContinue = false;
        }

        // Check turn limit
        if (!manager.canContinue()) {
          shouldContinue = false;
        }
      } catch (e, stackTrace) {
        if (e is _RethrownInferenceError) {
          Error.throwWithStackTrace(e.error, e.stackTrace);
        }
        _storeTurnError(manager, e, stackTrace);
        shouldContinue = false;
      }
    }

    // A strategy that threw part-way, or none to run the calls, leaves the
    // last round's calls unanswered, and strict providers would reject the
    // next message on this conversation for it.
    manager.answerPendingToolCalls(unansweredToolCallResult);

    if (attributionSession != null &&
        (consumptionAgentId == null || consumptionWakeRunKey == null) &&
        !nonAgentStreamFailed) {
      await capture!.completeSession(
        session: attributionSession,
        outputs: const [],
        status: AiWorkStatus.partial,
        errorCode: 'output_carrier_unavailable',
      );
    }

    return accumulated.hasData ? accumulated : null;
  });

  /// Runs [send] once every earlier [sendMessage] on [conversationId] has
  /// returned.
  ///
  /// A turn awaits the provider and every tool execution. A second message
  /// interleaved there lands between an assistant's tool calls and their
  /// results, which strict providers reject for the rest of the
  /// conversation, and both would read the same turn for their tool-call
  /// ids.
  Future<T> _serialized<T>(
    String conversationId,
    Future<T> Function() send,
  ) async {
    final previous = _sendQueues[conversationId];
    final done = Completer<void>();
    _sendQueues[conversationId] = done;
    try {
      if (previous != null) await previous.future;
      return await send();
    } finally {
      done.complete();
      if (identical(_sendQueues[conversationId], done)) {
        _sendQueues.remove(conversationId);
      }
    }
  }

  void _storeTurnError(
    ConversationManager manager,
    Object error,
    StackTrace stackTrace,
  ) {
    final errorMessage = error.toString();
    developer.log(
      'Error during conversation turn:\n$errorMessage',
      name: 'ConversationRepository',
      error: error,
      stackTrace: stackTrace,
    );
    manager.lastError = errorMessage;
  }

  /// Delete a conversation
  void deleteConversation(String conversationId) {
    _conversations.remove(conversationId);
  }
}

class _RethrownInferenceError implements Exception {
  const _RethrownInferenceError(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}
