import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:crypto/crypto.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
import 'package:meta/meta.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'conversation_repository.g.dart';

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

/// Non-secret snapshot of one provider request made inside
/// [ConversationRepository.sendMessage].
///
/// This intentionally stores hashes and structural metadata only. Prompt text,
/// assistant content, tool arguments, and provider credentials must never be
/// persisted through this object.
class ConversationProviderRequest {
  const ConversationProviderRequest({
    required this.requestIndex,
    required this.turnIndex,
    required this.providerModelId,
    required this.providerId,
    required this.providerType,
    required this.messageDigest,
    required this.messageCount,
    required this.toolSchemaDigest,
    required this.toolCount,
    required this.toolNames,
    required this.temperature,
    required this.thoughtSignatureCount,
    this.forcedToolName,
  });

  final int requestIndex;
  final int turnIndex;
  final String providerModelId;
  final String providerId;
  final String providerType;
  final String messageDigest;
  final int messageCount;
  final String toolSchemaDigest;
  final int toolCount;
  final List<String> toolNames;
  final String? forcedToolName;
  final double temperature;
  final int thoughtSignatureCount;
}

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
@riverpod
class ConversationRepository extends _$ConversationRepository {
  final _conversations = <String, ConversationManager>{};
  final _uuid = const Uuid();

  @override
  void build() {
    // Initialize repository
    ref.onDispose(() {
      // Clean up all conversations
      for (final conversation in _conversations.values) {
        conversation.dispose();
      }
      _conversations.clear();
    });
  }

  /// Create a new conversation
  String createConversation({
    String? systemMessage,
    int maxTurns = 20,
  }) {
    final conversationId = _uuid.v4();
    final manager = ConversationManager(
      conversationId: conversationId,
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

  /// Appends Gemini's complete-in-one-chunk tool calls to [toolCalls],
  /// synthesizing ids unique across conversation turns
  /// (`tool_turn<turn>_<n>`).
  @visibleForTesting
  static void appendGeminiToolCalls({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required List<ChatCompletionStreamMessageToolCallChunk> chunks,
    required int turn,
  }) {
    for (final toolCallChunk in chunks) {
      if (toolCallChunk.function != null) {
        final toolCallId = 'tool_turn${turn}_${toolCalls.length}';
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
  /// fragments are stitched per tool call (matched by id first, then by
  /// chunk index) via [argumentBuffers] so JSON split across chunks — even
  /// mid-character — reassembles intact.
  @visibleForTesting
  static void accumulateOpenAiToolCallChunks({
    required List<ChatCompletionMessageToolCall> toolCalls,
    required Map<String, StringBuffer> argumentBuffers,
    required List<ChatCompletionStreamMessageToolCallChunk> chunks,
  }) {
    for (final toolCallChunk in chunks) {
      // Find existing tool call by ID or index
      var existingIndex = -1;

      // First try to find by ID if available
      if (toolCallChunk.id != null && toolCallChunk.id!.isNotEmpty) {
        existingIndex = toolCalls.indexWhere(
          (tc) => tc.id == toolCallChunk.id,
        );
      }

      // If not found by ID and we have an index, use the index
      if (existingIndex < 0 && toolCallChunk.index != null) {
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
        final toolCallId =
            toolCallChunk.id ??
            'tool_${toolCallChunk.index ?? toolCalls.length}';

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

  /// Hook for eval/test observers that need request-level provenance.
  ///
  /// The default implementation is intentionally a no-op so production behavior
  /// remains unchanged unless a subclass opts in.
  @protected
  void observeProviderRequest(ConversationProviderRequest request) {}

  /// Send a message in a conversation.
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
    final manager = _conversations[conversationId];
    if (manager == null) {
      throw ArgumentError('Conversation $conversationId not found');
    }

    // Add user message
    manager.addUserMessage(message);

    // Check if we can continue
    if (!manager.canContinue()) {
      manager.emitError('Maximum conversation turns reached');
      return null;
    }

    // OpenAI GPT-5 models only accept temperature=1.0 (the default).
    // Other providers support custom temperature values.
    final effectiveTemperature =
        provider.inferenceProviderType == InferenceProviderType.openAi
        ? 1.0
        : temperature;

    // Start conversation loop
    var shouldContinue = true;
    var accumulated = InferenceUsage.empty;
    var providerRequestIndex = 0;

    while (shouldContinue) {
      try {
        // Emit thinking event
        manager.emitThinking();

        // Get all messages for the request
        final messages = manager.getMessagesForRequest();

        // Create signature collector for this turn (Gemini 3 multi-turn support)
        final signatureCollector = ThoughtSignatureCollector();
        final turnIndex = manager.turnCount;
        observeProviderRequest(
          ConversationProviderRequest(
            requestIndex: providerRequestIndex++,
            turnIndex: turnIndex,
            providerModelId: model,
            providerId: provider.id,
            providerType: provider.inferenceProviderType.name,
            messageDigest: _digestJson([
              for (final message in messages) message.toJson(),
            ]),
            messageCount: messages.length,
            toolSchemaDigest: _digestJson([
              for (final tool in tools ?? const <ChatCompletionTool>[])
                tool.toJson(),
            ]),
            toolCount: tools?.length ?? 0,
            toolNames: [
              for (final tool in tools ?? const <ChatCompletionTool>[])
                tool.function.name,
            ],
            forcedToolName: _forcedToolName(toolChoice),
            temperature: effectiveTemperature,
            thoughtSignatureCount: manager.thoughtSignatures.length,
          ),
        );

        // Make API call with full conversation history
        // Pass previous signatures and collector for new ones
        // turnCount provides unique tool call IDs across conversation turns
        final stream = inferenceRepo.generateTextWithMessages(
          messages: messages,
          model: model,
          provider: provider,
          tools: tools,
          toolChoice: toolChoice,
          temperature: effectiveTemperature,
          thoughtSignatures: manager.thoughtSignatures,
          signatureCollector: signatureCollector,
          turnIndex: turnIndex,
        );

        // Collect response
        final toolCalls = <ChatCompletionMessageToolCall>[];
        final contentBuffer = StringBuffer();
        // Use StringBuffer for each tool call to safely accumulate arguments
        // This prevents JSON corruption when chunks are split mid-character or arrive out of order
        final toolCallArgumentBuffers = <String, StringBuffer>{};
        InferenceUsage? turnUsage;

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
                  turn: manager.turnCount,
                );
              } else {
                accumulateOpenAiToolCallChunks(
                  toolCalls: toolCalls,
                  argumentBuffers: toolCallArgumentBuffers,
                  chunks: chunks,
                );
              }
            }
          }
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
        // Log full error details for debugging
        final errorMessage = e.toString();
        developer.log(
          'Error during conversation turn:\n$errorMessage',
          name: 'ConversationRepository',
          error: e,
          stackTrace: stackTrace,
        );
        try {
          manager.emitError(errorMessage);
        } catch (_) {
          // Ignore errors when emitting error events
        }
        shouldContinue = false;
      }
    }

    return accumulated.hasData ? accumulated : null;
  }

  /// Delete a conversation
  void deleteConversation(String conversationId) {
    final manager = _conversations.remove(conversationId);
    manager?.dispose();
  }
}

String _digestJson(Object? value) =>
    'sha256:${sha256.convert(utf8.encode(jsonEncode(_canonicalize(value))))}';

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return {
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is Set) {
    return value.map(_canonicalize).toList()
      ..sort((a, b) => jsonEncode(a).compareTo(jsonEncode(b)));
  }
  if (value is List) {
    return value.map(_canonicalize).toList();
  }
  return value;
}

String? _forcedToolName(ChatCompletionToolChoiceOption? toolChoice) {
  return toolChoice?.map(
    mode: (_) => null,
    tool: (choice) => choice.value.function.name,
  );
}

/// Provider for accessing conversation events
@riverpod
Stream<ConversationEvent> conversationEvents(
  Ref ref,
  String conversationId,
) {
  final repo = ref.watch(conversationRepositoryProvider.notifier);
  final manager = repo.getConversation(conversationId);

  if (manager == null) {
    return Stream.error('Conversation $conversationId not found');
  }

  return manager.events;
}

/// Provider for conversation messages
@riverpod
List<ChatCompletionMessage> conversationMessages(
  Ref ref,
  String conversationId,
) {
  final repo = ref.watch(conversationRepositoryProvider.notifier);
  final manager = repo.getConversation(conversationId);

  return manager?.messages ?? [];
}
