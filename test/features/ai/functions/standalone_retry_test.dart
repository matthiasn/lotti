import 'dart:async';
import 'dart:convert';
import 'package:openai_dart/openai_dart.dart';

/// Standalone test for error handling and retry logic
///
/// Run with: dart test/features/ai/functions/standalone_retry_test.dart

void main() async {
  print('=== Standalone Error Handling and Retry Test ===\n');

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
    
    await testBatchWithRetry(client, model);
  }
}

Future<void> testBatchWithRetry(OpenAIClient client, String model) async {
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

  final messages = <ChatCompletionMessage>[
    ChatCompletionMessage.system(content: '''
You are a helpful assistant that creates checklist items.
Always use the provided function to create items.
IMPORTANT: The correct format is {"actionItemDescription": "item description"}.
'''),
  ];

  // Track results
  final successfulItems = <String>[];
  final failedItems = <Map<String, dynamic>>[];
  var totalRounds = 0;
  var hasRetriedErrors = false;

  // Initial request
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
        
        final roundFailures = <Map<String, dynamic>>[];
        
        for (var i = 0; i < assistantMessage.toolCalls!.length; i++) {
          final call = assistantMessage.toolCalls![i];
          print('\n  Item ${i + 1}: ${call.function.name}');
          print('  Arguments: ${call.function.arguments}');
          
          try {
            final args = jsonDecode(call.function.arguments) as Map<String, dynamic>;
            
            if (args.containsKey('actionItemDescription')) {
              final item = args['actionItemDescription'] as String;
              successfulItems.add(item);
              print('  ✓ Valid: "$item"');
              
              messages.add(ChatCompletionMessage.tool(
                toolCallId: call.id,
                content: 'Created: $item',
              ));
            } else {
              // Wrong field name
              print('  ✗ Invalid: missing actionItemDescription key');
              print('    Keys found: ${args.keys.join(', ')}');
              
              // Extract attempted item
              String? attemptedItem;
              for (final entry in args.entries) {
                if (entry.value is String && entry.value.toString().isNotEmpty) {
                  attemptedItem = entry.value.toString();
                  print('    Attempted item: "$attemptedItem" (field: "${entry.key}")');
                  break;
                }
              }
              
              if (attemptedItem != null) {
                roundFailures.add({
                  'item': attemptedItem,
                  'error': 'Wrong field name: ${args.keys.first}',
                  'id': call.id,
                });
              }
              
              messages.add(ChatCompletionMessage.tool(
                toolCallId: call.id,
                content: 'Error: Missing required field "actionItemDescription". Found "${args.keys.first}" instead.',
              ));
            }
          } catch (e) {
            print('  ✗ JSON Parse Error: $e');
            messages.add(ChatCompletionMessage.tool(
              toolCallId: call.id,
              content: 'Error parsing JSON: $e',
            ));
          }
        }
        
        failedItems.addAll(roundFailures);
        
        print('\nProgress: ${successfulItems.length} items created successfully');
        
        // Decide what to do next
        if (failedItems.isNotEmpty && !hasRetriedErrors) {
          hasRetriedErrors = true;
          
          // Create detailed retry message
          final errorSummary = failedItems.map((f) => 
            '- ${f['error']} for "${f['item']}"'
          ).join('\n');
          
          final retryItems = failedItems
              .map((f) => f['item'] as String)
              .toList();
          
          final retryMessage = '''
I noticed ${failedItems.length == 1 ? 'an error' : 'errors'} in your function call${failedItems.length > 1 ? 's' : ''}:
$errorSummary

You already successfully created these items: ${successfulItems.join(', ')}

Please create ONLY the failed item${retryItems.length > 1 ? 's' : ''}: ${retryItems.join(', ')}

Use the correct format:
{"actionItemDescription": "item description"}

Do NOT recreate the items that were already successful.''';
          
          messages.add(ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(retryMessage),
          ));
          
          print('\nRETRY REQUEST: Asking to fix ${failedItems.length} failed items');
          failedItems.clear(); // Clear for next round
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
  print('Had to retry errors: ${hasRetriedErrors ? "YES" : "NO"}');
  print('Success: ${successfulItems.length >= 6 ? "YES" : "NO"}');
}