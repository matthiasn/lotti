import 'dart:async';
import 'dart:developer' as developer;

import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/model/ai_chat_message.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/gemini_tool_call.dart';
import 'package:lotti/features/ai/model/inference_usage.dart';
import 'package:lotti/features/ai/repository/inference_repository_interface.dart';
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

String? _stripThinkBlocks(String? content) {
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

  /// Get a conversation manager
  ConversationManager? getConversation(String conversationId) {
    return _conversations[conversationId];
  }

  /// Send a message in a conversation.
  ///
  /// When [toolChoice] is supplied it overrides the provider default (`auto`)
  /// for every inference call this `sendMessage` makes. This is the hook the
  /// Task Agent uses to force a terminal `update_report` call when a weaker
  /// model stopped early without publishing its report. Currently honored
  /// only on the OpenAI-compatible inference path — Gemini/Ollama/Mistral
  /// sub-repositories silently ignore it.
  ///
  /// Returns the accumulated [InferenceUsage] across all turns, or `null`
  /// if no usage data was reported by the inference provider.
  Future<InferenceUsage?> sendMessage({
    required String conversationId,
    required String message,
    required String model,
    required AiConfigInferenceProvider provider,
    required InferenceRepositoryInterface inferenceRepo,
    List<AiTool>? tools,
    AiToolChoice? toolChoice,
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

    while (shouldContinue) {
      try {
        // Emit thinking event
        manager.emitThinking();

        // Get all messages for the request
        final messages = manager.getMessagesForRequest();

        // Create signature collector for this turn (Gemini 3 multi-turn support)
        final signatureCollector = ThoughtSignatureCollector();

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
          turnIndex: manager.turnCount,
        );

        // Collect response
        final toolCalls = <AiToolCall>[];
        final contentBuffer = StringBuffer();
        // Use StringBuffer for each tool call to safely accumulate arguments —
        // prevents JSON corruption when chunks split mid-character or arrive
        // out of order.
        final toolCallArgumentBuffers = <String, StringBuffer>{};
        InferenceUsage? turnUsage;

        await for (final response in stream) {
          if (response.usage != null) {
            final u = response.usage!;
            turnUsage = InferenceUsage(
              inputTokens: u.promptTokens,
              outputTokens: u.completionTokens,
              thoughtsTokens: u.reasoningTokens,
              cachedInputTokens: u.cachedInputTokens,
            );
          }
          if (response.choices.isEmpty) continue;
          final delta = response.choices.first.delta;

          if (delta.content != null) {
            contentBuffer.write(delta.content);
          }

          final chunkToolCalls = delta.toolCalls;
          if (chunkToolCalls == null) continue;

          // Gemini streams *multiple complete* tool calls in one chunk with
          // empty IDs and null indices — detect and emit them directly.
          final isGeminiStyle =
              chunkToolCalls.length > 1 &&
              chunkToolCalls.every(
                (tc) =>
                    (tc.id == null || tc.id!.isEmpty) &&
                    tc.index == null &&
                    tc.arguments != null &&
                    tc.arguments!.isNotEmpty,
              );

          if (isGeminiStyle) {
            final turn = manager.turnCount;
            for (final tc in chunkToolCalls) {
              if (tc.name != null || tc.arguments != null) {
                final toolCallId = 'tool_turn${turn}_${toolCalls.length}';
                toolCalls.add(
                  AiToolCall(
                    id: toolCallId,
                    name: tc.name ?? '',
                    arguments: tc.arguments ?? '',
                  ),
                );
              }
            }
            continue;
          }

          // Standard OpenAI-style incremental accumulation.
          for (final tc in chunkToolCalls) {
            var existingIndex = -1;
            if (tc.id != null && tc.id!.isNotEmpty) {
              existingIndex = toolCalls.indexWhere((e) => e.id == tc.id);
            }
            if (existingIndex < 0 && tc.index != null) {
              final chunkIndex = tc.index!;
              if (chunkIndex < toolCalls.length) {
                existingIndex = chunkIndex;
              }
            }

            if (existingIndex >= 0) {
              final existing = toolCalls[existingIndex];
              final buffer =
                  toolCallArgumentBuffers[existing.id] ??
                  StringBuffer(existing.arguments);
              toolCallArgumentBuffers[existing.id] = buffer;
              buffer.write(tc.arguments ?? '');
              toolCalls[existingIndex] = AiToolCall(
                id: existing.id,
                name: existing.name,
                arguments: buffer.toString(),
              );
            } else if (tc.name != null || tc.arguments != null) {
              final toolCallId =
                  tc.id ?? 'tool_${tc.index ?? toolCalls.length}';
              final initialArgs = tc.arguments ?? '';
              toolCallArgumentBuffers[toolCallId] = StringBuffer(initialArgs);
              toolCalls.add(
                AiToolCall(
                  id: toolCallId,
                  name: tc.name ?? '',
                  arguments: initialArgs,
                ),
              );
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
        final persistedContent = _stripThinkBlocks(rawContent);

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
List<AiChatMessage> conversationMessages(
  Ref ref,
  String conversationId,
) {
  final repo = ref.watch(conversationRepositoryProvider.notifier);
  final manager = repo.getConversation(conversationId);

  return manager?.messages ?? [];
}
