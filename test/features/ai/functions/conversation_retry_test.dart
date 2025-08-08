import 'dart:async';
import 'dart:convert';

import 'package:lotti/features/ai/conversation/conversation_manager.dart';
import 'package:lotti/features/ai/functions/conversation_batch_processor.dart';
import 'package:openai_dart/openai_dart.dart';

/// Test conversation-based batch processing with error retry
///
/// Run with: dart test/features/ai/functions/conversation_retry_test.dart

void main() async {
  print('=== Conversation Batch Processing with Error Retry Test ===\n');

  const baseUrl = 'http://localhost:11434/v1';
  final client = OpenAIClient(
    baseUrl: baseUrl,
    headers: {'User-Agent': 'Lotti'},
  );

  // Test with both models
  final models = ['gpt-oss:20b', 'qwen3:8b'];
  
  for (final model in models) {
    print('\n' + '=' * 60);
    print('TESTING WITH MODEL: $model');
    print('=' * 60 + '\n');
    
    await testBatchProcessingWithRetry(client, model);
  }
}

Future<void> testBatchProcessingWithRetry(OpenAIClient client, String model) async {
  final tools = [
    const ChatCompletionTool(
      type: ChatCompletionToolType.function,
      function: FunctionObject(
        name: 'createChecklistItem',
        description: 'Create a checklist item',
        parameters: {
          'type': 'object',
          'required': ['actionItemDescription'],
          'properties': {
            'actionItemDescription': {
              'type': 'string',
              'description': 'The item description',
            },
          },
        },
      ),
    ),
  ];

  // Create a conversation manager
  final manager = ConversationManager(
    conversationId: 'test-$model',
    maxTurns: 20,
  );

  manager.initialize(systemMessage: '''
You are a helpful assistant that creates checklist items.
Always use the provided function to create items.
IMPORTANT: The correct format is {"actionItemDescription": "item description"}.
''');

  // Create strategy with error handling
  final strategy = FlexibleBatchStrategy(
    onItemCreated: (item) {
      if (item.success) {
        print('  ✓ Created: ${item.originalItem}');
      } else {
        print('  ✗ Failed: ${item.error} (attempted: ${item.originalItem})');
      }
    },
  );

  // Track events
  final successfulItems = <String>[];
  final failedItems = <String>[];
  
  strategy.events.listen((event) {
    switch (event) {
      case StartingBatchEvent():
        print('Starting batch processing...');
      case ItemsCreatedEvent(:final items, :final totalSoFar):
        print('\nRound completed:');
        for (final item in items) {
          if (item.success) {
            successfulItems.add(item.originalItem);
          } else {
            failedItems.add('${item.originalItem} (${item.error})');
          }
        }
        print('Total successful so far: $totalSoFar');
      case BatchCompletedEvent():
        print('\nBatch processing completed!');
      case ErrorEvent(:final message):
        print('ERROR: $message');
      default:
        // Handle other events
    }
  });

  // Initial request
  manager.addUserMessage(
    'Create a shopping checklist for pizza: dough, cheese, sauce, pepperoni, mushrooms, olive oil'
  );

  print('USER: Create pizza shopping checklist\n');

  // Simulate conversation loop
  var rounds = 0;
  const maxRounds = 10;
  var continueConversation = true;

  while (continueConversation && rounds < maxRounds) {
    rounds++;
    print('\n--- Round $rounds ---');

    try {
      // Get messages for request
      final messages = manager.getMessagesForRequest();

      // Make API call
      manager.emitThinking();
      
      final response = await client.createChatCompletion(
        request: CreateChatCompletionRequest(
          model: ChatCompletionModel.modelId(model),
          messages: messages,
          tools: tools,
          toolChoice: ChatCompletionToolChoiceOption.mode(
            ChatCompletionToolChoiceMode.auto,
          ),
          temperature: 0.1,
        ),
      );

      final assistantMessage = response.choices.first.message;
      
      // Add assistant response
      manager.addAssistantMessage(
        content: assistantMessage.content,
        toolCalls: assistantMessage.toolCalls,
      );

      if (assistantMessage.toolCalls?.isNotEmpty ?? false) {
        print('MODEL $model created ${assistantMessage.toolCalls!.length} function call(s):');
        
        // Process tool calls
        final action = await strategy.processToolCalls(
          toolCalls: assistantMessage.toolCalls!,
          manager: manager,
        );

        switch (action) {
          case ConversationAction.continueConversation:
            final continuationPrompt = strategy.getContinuationPrompt(manager);
            if (continuationPrompt != null) {
              print('\nCONTINUATION: ${continuationPrompt.split('\n').first}...');
              manager.addUserMessage(continuationPrompt);
            } else {
              continueConversation = false;
            }
            
          case ConversationAction.complete:
          case ConversationAction.wait:
            continueConversation = false;
        }
      } else {
        // No tool calls - check for completion
        if (assistantMessage.content != null) {
          print('ASSISTANT: ${assistantMessage.content}');
          final content = assistantMessage.content!.toLowerCase();
          if (content.contains('done') || content.contains('complete')) {
            continueConversation = false;
          }
        } else {
          continueConversation = false;
        }
      }
    } catch (e) {
      print('Error in round $rounds: $e');
      continueConversation = false;
    }
  }

  // Wait for any pending events
  await Future.delayed(const Duration(milliseconds: 100));

  // Summary
  print('\n=== SUMMARY FOR $model ===');
  print('Total rounds: $rounds');
  print('Successfully created: ${successfulItems.length} items');
  if (successfulItems.isNotEmpty) {
    print('Successful items:');
    for (var i = 0; i < successfulItems.length; i++) {
      print('  ${i + 1}. ${successfulItems[i]}');
    }
  }
  if (failedItems.isNotEmpty) {
    print('Failed items: ${failedItems.join(', ')}');
  }
  print('Success: ${successfulItems.length >= 6 ? "YES" : "NO"}');
  
  strategy.dispose();
  manager.dispose();
}