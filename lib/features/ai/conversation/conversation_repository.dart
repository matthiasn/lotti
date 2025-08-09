import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'conversation_repository.g.dart';

/// Repository for managing AI conversations
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

  /// Send a message in a conversation
  Future<void> sendMessage({
    required String conversationId,
    required String message,
    required String model,
    required AiConfigInferenceProvider provider,
    required OllamaInferenceRepository ollamaRepo,
    List<ChatCompletionTool>? tools,
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
      return;
    }

    // Start conversation loop
    var shouldContinue = true;

    while (shouldContinue) {
      try {
        // Emit thinking event
        manager.emitThinking();

        // Get all messages for the request
        final messages = manager.getMessagesForRequest();

        // Make API call with full conversation history
        final stream = ollamaRepo.generateTextWithMessages(
          messages: messages,
          model: model,
          provider: provider,
          tools: tools,
          temperature: temperature,
        );

        // Collect response
        final toolCalls = <ChatCompletionMessageToolCall>[];
        final contentBuffer = StringBuffer();

        await for (final response in stream) {
          if (response.choices?.isNotEmpty ?? false) {
            final delta = response.choices!.first.delta;

            // Collect content
            if (delta?.content != null) {
              contentBuffer.write(delta!.content);
            }

            // Collect tool calls
            if (delta?.toolCalls != null) {
              for (final toolCallChunk in delta!.toolCalls!) {
                // Find existing tool call by ID or index
                var existingIndex = -1;

                // First try to find by ID if available
                if (toolCallChunk.id != null) {
                  existingIndex =
                      toolCalls.indexWhere((tc) => tc.id == toolCallChunk.id);
                }

                // If not found by ID and we have an index, use the index
                if (existingIndex < 0 && toolCallChunk.index != null) {
                  final chunkIndex = toolCallChunk.index!;
                  if (chunkIndex < toolCalls.length) {
                    existingIndex = chunkIndex;
                  }
                }

                if (existingIndex >= 0) {
                  // Append to existing tool call
                  final existing = toolCalls[existingIndex];
                  final updatedArgs = existing.function.arguments +
                      (toolCallChunk.function?.arguments ?? '');
                  toolCalls[existingIndex] = ChatCompletionMessageToolCall(
                    id: existing.id,
                    type: existing.type,
                    function: ChatCompletionMessageFunctionCall(
                      name: existing.function.name,
                      arguments: updatedArgs,
                    ),
                  );
                } else if (toolCallChunk.function != null) {
                  // Add new tool call
                  final toolCallId = toolCallChunk.id ??
                      'tool_${toolCallChunk.index ?? toolCalls.length}';
                  toolCalls.add(ChatCompletionMessageToolCall(
                    id: toolCallId,
                    type: ChatCompletionMessageToolCallType.function,
                    function: ChatCompletionMessageFunctionCall(
                      name: toolCallChunk.function!.name ?? '',
                      arguments: toolCallChunk.function!.arguments ?? '',
                    ),
                  ));
                }
              }
            }
          }
        }

        // Add assistant message
        final content = contentBuffer.toString();

        developer.log(
          'Stream completed: collected ${toolCalls.length} tool calls and '
          '${content.length} chars of content',
          name: 'ConversationRepository',
        );

        manager.addAssistantMessage(
          content: content.isNotEmpty ? content : null,
          toolCalls: toolCalls.isNotEmpty ? toolCalls : null,
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
              final continuationPrompt =
                  strategy.getContinuationPrompt(manager);
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
      } catch (e) {
        developer.log(
          'Error during conversation turn',
          name: 'ConversationRepository',
          error: e,
        );
        try {
          manager.emitError(e.toString());
        } catch (_) {
          // Ignore errors when emitting error events
        }
        shouldContinue = false;
      }
    }
  }

  /// Delete a conversation
  void deleteConversation(String conversationId) {
    final manager = _conversations.remove(conversationId);
    manager?.dispose();
  }

  /// Get all active conversation IDs
  List<String> getActiveConversations() {
    return _conversations.keys.toList();
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
List<ChatCompletionMessage> conversationMessages(
  Ref ref,
  String conversationId,
) {
  final repo = ref.watch(conversationRepositoryProvider.notifier);
  final manager = repo.getConversation(conversationId);

  return manager?.messages ?? [];
}
