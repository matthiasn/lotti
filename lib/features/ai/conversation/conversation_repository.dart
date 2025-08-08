import 'dart:async';

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
    );

    manager.initialize(systemMessage: systemMessage);
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

        // Get the last user message as the prompt
        final messages = manager.getMessagesForRequest();
        final lastUserMessage = messages
            .where((m) => m.role == ChatCompletionMessageRole.user)
            .lastOrNull;

        final systemMessage = messages
            .where((m) => m.role == ChatCompletionMessageRole.system)
            .firstOrNull
            ?.content;

        // Make API call
        final stream = ollamaRepo.generateText(
          prompt: lastUserMessage?.content?.toString() ?? '',
          model: model,
          provider: provider,
          systemMessage: systemMessage?.toString(),
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
                // Create or update tool call
                final toolCallId =
                    toolCallChunk.id ?? 'tool_${toolCalls.length}';
                final existingIndex =
                    toolCalls.indexWhere((tc) => tc.id == toolCallId);

                if (existingIndex >= 0) {
                  // Append to existing
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
                  // Add new
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
        manager.addAssistantMessage(
          content: content.isNotEmpty ? content : null,
          toolCalls: toolCalls.isNotEmpty ? toolCalls : null,
        );

        // Process with strategy if provided
        if (strategy != null && toolCalls.isNotEmpty) {
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
        manager.emitError(e.toString());
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
  ConversationEventsRef ref,
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
