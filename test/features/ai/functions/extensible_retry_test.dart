import 'dart:convert';

import 'package:lotti/features/ai/functions/function_handler.dart';
import 'package:openai_dart/openai_dart.dart';

/// Test the extensible system with the scenario that reliably produces errors
///
/// Run with: dart test/features/ai/functions/extensible_retry_test.dart

void main() async {
  print('=== Extensible System Error Retry Test ===\n');

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
    
    await testBatchWithExtensibleSystem(client, model);
  }
}

Future<void> testBatchWithExtensibleSystem(OpenAIClient client, String model) async {
  // Define the tool
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

  // Create handler
  final checklistHandler = ChecklistItemHandler();

  final messages = <ChatCompletionMessage>[
    ChatCompletionMessage.system(content: '''
You are a helpful assistant that creates checklist items.
Always use the provided function to create items.
Be concise and efficient.
'''),
  ];

  // Track results
  final successfulItems = <String>[];
  final allFailedResults = <FunctionCallResult>[];
  var totalRounds = 0;
  var hasRetriedErrors = false;

  // Initial request - the exact same one that triggers errors
  messages.add(ChatCompletionMessage.user(
    content: ChatCompletionUserMessageContent.string(
      'Create a shopping checklist for pizza: dough, cheese, sauce, pepperoni, mushrooms, olive oil'
    ),
  ));

  print('USER: Create pizza shopping checklist\n');

  // Process until done
  var continueProcessing = true;
  
  while (continueProcessing && totalRounds < 10) {
    totalRounds++;
    print('\n--- Round $totalRounds ---');

    try {
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
      messages.add(assistantMessage);

      if (assistantMessage.toolCalls?.isNotEmpty ?? false) {
        print('MODEL $model created ${assistantMessage.toolCalls!.length} function call(s):');
        
        final roundFailures = <FunctionCallResult>[];
        
        for (var i = 0; i < assistantMessage.toolCalls!.length; i++) {
          final call = assistantMessage.toolCalls![i];
          print('\n  Item ${i + 1}: ${call.function.name}');
          print('  Arguments: ${call.function.arguments}');
          
          // Process with handler
          final result = checklistHandler.processFunctionCall(call);
          
          if (result.success) {
            final isDupe = checklistHandler.isDuplicate(result);
            if (!isDupe) {
              final description = checklistHandler.getDescription(result)!;
              successfulItems.add(description);
              print('  ✓ Valid: "$description"');
            } else {
              print('  ⚠️  Duplicate: ${checklistHandler.getDescription(result)}');
            }
          } else {
            print('  ✗ Error: ${result.error}');
            final attempted = checklistHandler.getDescription(result);
            if (attempted != null && attempted.isNotEmpty) {
              print('    Attempted item: "$attempted"');
            }
            roundFailures.add(result);
            allFailedResults.add(result);
          }
          
          // Add tool response
          messages.add(ChatCompletionMessage.tool(
            toolCallId: result.data['toolCallId'] as String,
            content: checklistHandler.createToolResponse(result),
          ));
        }
        
        print('\nProgress: ${successfulItems.length} items created successfully');
        
        // Decide what to do next
        if (roundFailures.isNotEmpty && !hasRetriedErrors) {
          hasRetriedErrors = true;
          
          // Use handler's retry prompt
          final retryMessage = checklistHandler.getRetryPrompt(
            failedItems: roundFailures,
            successfulDescriptions: successfulItems,
          );
          
          messages.add(ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(retryMessage),
          ));
          
          print('\nRETRY REQUEST: Using handler-generated retry prompt');
          print('First line: ${retryMessage.split('\n').first}');
        } else if (successfulItems.length < 6) {
          // Ask for more items
          messages.add(ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(
              'Great! Created ${successfulItems.length} items so far. Please continue with the remaining items from the pizza shopping list.'
            ),
          ));
        } else {
          // All done
          continueProcessing = false;
        }
      } else {
        // No tool calls
        if (assistantMessage.content != null) {
          print('ASSISTANT: ${assistantMessage.content}');
        }
        continueProcessing = false;
      }
    } catch (e) {
      print('Error: $e');
      continueProcessing = false;
    }
  }

  // Summary
  print('\n=== SUMMARY FOR $model ===');
  print('Total rounds: $totalRounds');
  print('Successfully created: ${successfulItems.length} items');
  if (successfulItems.isNotEmpty) {
    print('Items:');
    for (var i = 0; i < successfulItems.length; i++) {
      print('  ${i + 1}. ${successfulItems[i]}');
    }
  }
  print('Total errors encountered: ${allFailedResults.length}');
  if (allFailedResults.isNotEmpty) {
    print('Error details:');
    for (final result in allFailedResults) {
      final attempted = checklistHandler.getDescription(result) ?? 'unknown';
      print('  - ${result.error} (attempted: "$attempted")');
    }
  }
  print('Had to retry errors: ${hasRetriedErrors ? "YES" : "NO"}');
  print('Success: ${successfulItems.length >= 6 ? "YES" : "NO"}');
  
  // Reset handler for next model
  checklistHandler.reset();
}