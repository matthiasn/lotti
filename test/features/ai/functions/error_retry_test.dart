import 'dart:convert';

import 'package:openai_dart/openai_dart.dart';

/// Test error handling and retry logic for malformed JSON responses
///
/// Run with: dart test/features/ai/functions/error_retry_test.dart

void main() async {
  print('=== Error Handling and Retry Test ===\n');

  const baseUrl = 'http://localhost:11434/v1';

  final client = OpenAIClient(
    baseUrl: baseUrl,
    headers: {'User-Agent': 'Lotti'},
  );

  // Define the tool
  final tools = [
    const ChatCompletionTool(
      type: ChatCompletionToolType.function,
      function: FunctionObject(
        name: 'createChecklistItem',
        description: 'Create a new checklist item',
        parameters: {
          'type': 'object',
          'required': ['actionItemDescription'],
          'properties': {
            'actionItemDescription': {
              'type': 'string',
              'description': 'The checklist item description',
            },
          },
        },
      ),
    ),
  ];

  // System message that emphasizes correct format
  const systemMessage = '''
You are a helpful assistant that creates checklist items using the createChecklistItem function.
IMPORTANT: Always use the exact format {"actionItemDescription": "item description"} for the function arguments.
The field name MUST be "actionItemDescription", not any other name.
''';

  // Test with qwen3:8b which sometimes produces malformed JSON
  await testModelWithRetry('qwen3:8b', client, tools, systemMessage);
}

Future<void> testModelWithRetry(
  String model,
  OpenAIClient client,
  List<ChatCompletionTool> tools,
  String systemMessage,
) async {
  print('Testing model: $model\n');

  final messages = <ChatCompletionMessage>[
    ChatCompletionMessage.system(content: systemMessage),
  ];

  // Initial request with specific items that might trigger errors
  messages.add(ChatCompletionMessage.user(
    content: ChatCompletionUserMessageContent.string(
      'Create a shopping checklist for pizza with exactly these 3 items: pepperoni, mushrooms, olive oil',
    ),
  ));

  print('USER: ${messages.last.content}\n');

  var continueConversation = true;
  var rounds = 0;
  const maxRounds = 5;
  final allCreatedItems = <String>[];
  final failedItems = <Map<String, dynamic>>[];

  while (continueConversation && rounds < maxRounds) {
    rounds++;
    print('--- Round $rounds ---');

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

      print('ASSISTANT: ${assistantMessage.content ?? "(function calls only)"}');

      if (assistantMessage.toolCalls?.isNotEmpty ?? false) {
        print('\nReceived ${assistantMessage.toolCalls!.length} tool call(s):');

        for (final toolCall in assistantMessage.toolCalls!) {
          print('\nTOOL CALL: ${toolCall.function.name}');
          print('ARGUMENTS: ${toolCall.function.arguments}');

          try {
            final args = jsonDecode(toolCall.function.arguments) as Map<String, dynamic>;
            
            if (args.containsKey('actionItemDescription')) {
              final itemDescription = args['actionItemDescription'] as String;
              allCreatedItems.add(itemDescription);
              print('✓ SUCCESS: Created "$itemDescription"');
              
              messages.add(ChatCompletionMessage.tool(
                toolCallId: toolCall.id,
                content: 'Created: $itemDescription',
              ));
            } else {
              // Wrong field name
              print('✗ ERROR: Missing "actionItemDescription" field');
              print('  Found fields: ${args.keys.join(', ')}');
              
              // Try to extract the intended item
              String? intendedItem;
              for (final entry in args.entries) {
                if (entry.value is String && entry.value.toString().isNotEmpty) {
                  intendedItem = entry.value.toString();
                  print('  Attempted to create: "$intendedItem" (using field "${entry.key}")');
                  break;
                }
              }
              
              failedItems.add({
                'item': intendedItem ?? 'unknown',
                'error': 'Wrong field name: ${args.keys.first}',
                'args': toolCall.function.arguments,
              });
              
              messages.add(ChatCompletionMessage.tool(
                toolCallId: toolCall.id,
                content: 'Error: Missing required field "actionItemDescription". Found "${args.keys.first}" instead.',
              ));
            }
          } catch (e) {
            print('✗ JSON PARSE ERROR: $e');
            failedItems.add({
              'item': 'unknown',
              'error': 'Invalid JSON',
              'args': toolCall.function.arguments,
            });
            
            messages.add(ChatCompletionMessage.tool(
              toolCallId: toolCall.id,
              content: 'Error parsing JSON: $e',
            ));
          }
        }

        print('\nProgress: ${allCreatedItems.length} items created successfully');
        
        // Check if we need to retry failed items
        if (failedItems.isNotEmpty && rounds < 3) {
          final retryMessage = '''
I noticed errors in your function calls. The correct format is:
{"actionItemDescription": "item description"}

Please retry creating these items with the correct format:
${failedItems.map((f) => '- ${f['item']}').join('\n')}

Remember: The field name MUST be "actionItemDescription".''';
          
          messages.add(ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(retryMessage),
          ));
          
          print('\nUSER: Requesting retry for failed items...');
          failedItems.clear(); // Clear for next attempt
        } else if (allCreatedItems.length >= 3) {
          print('\nAll items created successfully!');
          continueConversation = false;
        } else {
          // Ask for remaining items
          messages.add(ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(
              'Please continue creating the remaining items from the pizza shopping list.',
            ),
          ));
        }
      } else {
        // No tool calls
        continueConversation = false;
      }
    } catch (e) {
      print('ERROR: $e');
      continueConversation = false;
    }
  }

  // Summary
  print('\n=== SUMMARY ===');
  print('Model: $model');
  print('Total rounds: $rounds');
  print('Successfully created: ${allCreatedItems.length} items');
  if (allCreatedItems.isNotEmpty) {
    print('Items:');
    for (var i = 0; i < allCreatedItems.length; i++) {
      print('  ${i + 1}. ${allCreatedItems[i]}');
    }
  }
  print('Success: ${allCreatedItems.length >= 3 ? "YES" : "NO"}');
}