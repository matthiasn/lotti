import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai_chat/models/task_summary_tool.dart';
import 'package:lotti/features/ai_chat/repository/task_summary_repository.dart';
import 'package:openai_dart/openai_dart.dart';

final Provider<AiChatRepository> aiChatRepositoryProvider =
    Provider((ref) => AiChatRepository());

class AiChatRepository {
  /// Process a chat message with streaming support and tool handling
  Future<void> processMessage({
    required String message,
    required List<ChatCompletionMessage> previousMessages,
    required AiConfigModel model,
    required AiConfigInferenceProvider provider,
    required CloudInferenceRepository cloudRepo,
    required String categoryId,
    required TaskSummaryRepository taskSummaryRepo,
    required void Function(String) onStreamingUpdate,
    required void Function(String) onComplete,
    required void Function(String) onError,
  }) async {
    try {
      // Build messages list with system prompt and history
      final messages = <ChatCompletionMessage>[
        ChatCompletionMessage.system(
          content: _getSystemMessage(),
        ),
        ...previousMessages,
        ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string(message),
        ),
      ];

      // Define tools
      final tools = [TaskSummaryTool.toolDefinition];

      // Build conversation context for the prompt
      final promptParts = <String>[];

      // Add previous messages to maintain context
      for (final msg in previousMessages) {
        if (msg.role == ChatCompletionMessageRole.user) {
          promptParts.add('User: ${msg.content}');
        } else if (msg.role == ChatCompletionMessageRole.assistant) {
          promptParts.add('Assistant: ${msg.content}');
        }
      }

      // Add current message
      promptParts.add('User: $message');

      final fullPrompt = promptParts.join('\n\n');

      // Call AI with tools and full conversation context
      final stream = cloudRepo.generate(
        fullPrompt,
        model: model.providerModelId,
        temperature: 0.7,
        baseUrl: provider.baseUrl,
        apiKey: provider.apiKey,
        systemMessage: _getSystemMessage(),
        provider: provider,
        tools: tools,
      );

      final contentBuffer = StringBuffer();
      final toolCalls = <ChatCompletionMessageToolCall>[];

      // Process the streaming response
      await for (final chunk in stream) {
        if (chunk.choices?.isNotEmpty ?? false) {
          final delta = chunk.choices!.first.delta;

          // Handle content streaming
          if (delta?.content != null) {
            contentBuffer.write(delta!.content);
            onStreamingUpdate(contentBuffer.toString());
          }

          // Collect tool calls
          if (delta?.toolCalls != null) {
            for (final toolCallDelta in delta!.toolCalls!) {
              if (toolCallDelta.function != null) {
                // Find or create tool call
                final existingIndex = toolCallDelta.id != null
                    ? toolCalls.indexWhere((tc) => tc.id == toolCallDelta.id)
                    : -1;

                if (existingIndex >= 0) {
                  // Update existing tool call
                  final existing = toolCalls[existingIndex];
                  toolCalls[existingIndex] = ChatCompletionMessageToolCall(
                    id: existing.id,
                    type: existing.type,
                    function: ChatCompletionMessageFunctionCall(
                      name: existing.function.name,
                      arguments: existing.function.arguments +
                          (toolCallDelta.function!.arguments ?? ''),
                    ),
                  );
                } else {
                  // Add new tool call
                  toolCalls.add(ChatCompletionMessageToolCall(
                    id: toolCallDelta.id ?? 'tool_${toolCalls.length}',
                    type: ChatCompletionMessageToolCallType.function,
                    function: ChatCompletionMessageFunctionCall(
                      name: toolCallDelta.function!.name ?? '',
                      arguments: toolCallDelta.function!.arguments ?? '',
                    ),
                  ));
                }
              }
            }
          }
        }
      }

      // If we have tool calls, process them and get the final response
      if (toolCalls.isNotEmpty) {
        // Processing tool calls

        // Add assistant message with tool calls to history
        messages.add(ChatCompletionMessage.assistant(
          toolCalls: toolCalls,
        ));

        // Process each tool call
        for (final toolCall in toolCalls) {
          if (toolCall.function.name == TaskSummaryTool.name) {
            final toolResponse = await _processTaskSummaryTool(
              toolCall: toolCall,
              categoryId: categoryId,
              taskSummaryRepo: taskSummaryRepo,
            );

            // Add tool response to messages
            messages.add(ChatCompletionMessage.tool(
              toolCallId: toolCall.id,
              content: toolResponse,
            ));
          }
        }

        // Get final response after tool calls
        onStreamingUpdate('Generating response...');

        // Convert full conversation including tool results to prompt
        final promptParts = <String>[];

        // Include all messages for context
        for (final msg in messages) {
          if (msg.role == ChatCompletionMessageRole.user) {
            promptParts.add('User: ${msg.content}');
          } else if (msg.role == ChatCompletionMessageRole.assistant &&
              msg.content != null) {
            promptParts.add('Assistant: ${msg.content}');
          } else if (msg.role == ChatCompletionMessageRole.tool) {
            promptParts.add('Tool response: ${msg.content}');
          }
        }

        promptParts.add(
            'Based on the conversation and tool results above, provide a helpful response to the user.');

        final finalStream = cloudRepo.generate(
          promptParts.join('\n\n'),
          model: model.providerModelId,
          temperature: 0.7,
          baseUrl: provider.baseUrl,
          apiKey: provider.apiKey,
          systemMessage: _getSystemMessage(),
          provider: provider,
        );

        final finalBuffer = StringBuffer();
        await for (final chunk in finalStream) {
          if (chunk.choices?.isNotEmpty ?? false) {
            final delta = chunk.choices!.first.delta;
            if (delta?.content != null) {
              finalBuffer.write(delta!.content);
              onStreamingUpdate(finalBuffer.toString());
            }
          }
        }

        onComplete(finalBuffer.toString());
      } else {
        // No tool calls, just return the content
        onComplete(contentBuffer.toString());
      }
    } catch (e) {
      // Error occurred: $e
      onError(e.toString());
    }
  }

  Future<String> _processTaskSummaryTool({
    required ChatCompletionMessageToolCall toolCall,
    required String categoryId,
    required TaskSummaryRepository taskSummaryRepo,
  }) async {
    try {
      final args =
          jsonDecode(toolCall.function.arguments) as Map<String, dynamic>;

      final request = TaskSummaryRequest(
        startDate: DateTime.parse(args['start_date'] as String),
        endDate: DateTime.parse(args['end_date'] as String),
        limit: (args['limit'] as int?) ?? 100,
      );

      final summaries = await taskSummaryRepo.getTaskSummaries(
        categoryId: categoryId,
        request: request,
      );

      if (summaries.isEmpty) {
        return jsonEncode({
          'message': 'No tasks found in the specified date range.',
          'date_range': {
            'start': args['start_date'],
            'end': args['end_date'],
          },
          'debug': {
            'categoryId': categoryId,
            'requestedStart': request.startDate.toIso8601String(),
            'requestedEnd': request.endDate.toIso8601String(),
          },
        });
      }

      final response = summaries
          .map((s) => {
                'task_id': s.taskId,
                'title': s.taskTitle,
                'summary': s.summary,
                'date': s.taskDate.toIso8601String(),
                'status': s.status,
                'metadata': s.metadata,
              })
          .toList();

      return jsonEncode({
        'tasks': response,
        'count': summaries.length,
        'date_range': {
          'start': args['start_date'],
          'end': args['end_date'],
        },
      });
    } catch (e) {
      // Tool error occurred
      return jsonEncode({
        'error': 'Failed to retrieve task summaries: $e',
      });
    }
  }

  String _getSystemMessage() {
    return '''
You are an AI assistant helping users explore and understand their tasks.
You have access to a tool that can retrieve task summaries for specified date ranges.
When users ask about their tasks, use the get_task_summaries tool to fetch relevant information.

Today's date is ${DateTime.now().toIso8601String().split('T')[0]}.

When interpreting time-based queries, use these guidelines:
- "today" = from start of today to end of today
- "yesterday" = from start of yesterday to end of yesterday
- "this week" = last 7 days including today
- "recently" or "lately" = last 14 days
- "this month" = last 30 days
- "last week" = the previous 7-day period (8-14 days ago)
- "last month" = the previous 30-day period (31-60 days ago)

For date ranges, always use full ISO 8601 timestamps:
- start_date: beginning of the day, e.g., "2025-08-26T00:00:00.000"
- end_date: end of the day, e.g., "2025-08-26T23:59:59.999"

Example: For "yesterday" on 2025-08-27, use:
- start_date: "2025-08-26T00:00:00.000"
- end_date: "2025-08-26T23:59:59.999"

Be concise but helpful in your responses. When showing task summaries, organize them by date and status for clarity.''';
  }
}
