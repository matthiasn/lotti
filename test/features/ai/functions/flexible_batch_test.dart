import 'dart:convert';

import 'package:openai_dart/openai_dart.dart';

/// Flexible batch processing test that works with both:
/// - Models that can create multiple items at once
/// - Models that only create one item at a time
///
/// Run with: dart test/features/ai/functions/flexible_batch_test.dart

void main() async {
  print('=== Flexible Batch Processing Test ===\n');

  // Test both models
  await testModel('gpt-oss:20b');
  print('\n' + '=' * 50 + '\n');
  await testModel('qwen3:8b');
}

Future<void> testModel(String model) async {
  print('Testing model: $model\n');

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

  // System message that allows flexibility
  const systemMessage = '''
You are a helpful assistant that creates checklist items using the createChecklistItem function.
You can create multiple items if the model supports it, or one at a time.
Always respond to continuation requests by creating more items if there are any remaining.
''';

  // Conversation state
  final messages = <ChatCompletionMessage>[
    ChatCompletionMessage.system(content: systemMessage),
  ];

  final allCreatedItems = <String>[];
  final targetItems = [
    'pizza dough',
    'mozzarella cheese',
    'tomato sauce',
    'pepperoni',
    'mushrooms',
    'olive oil'
  ];

  // Initial request - encourage batch processing
  messages.add(ChatCompletionMessage.user(
    content: ChatCompletionUserMessageContent.string(
        '''Create a shopping checklist for making pizza with these items: ${targetItems.join(', ')}.
You can create multiple items at once if possible, or one at a time.'''),
  ));

  print('USER: ${messages.last.content}\n');

  // Conversation loop
  var continueConversation = true;
  var rounds = 0;
  const maxRounds = 10; // Safety limit

  while (continueConversation && rounds < maxRounds) {
    rounds++;
    print('--- Round $rounds ---');

    try {
      // Make API call
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

      print(
          'ASSISTANT: ${assistantMessage.content ?? "(function calls only)"}');

      // Collect all tool calls from this response
      final roundItems = <String>[];

      if (assistantMessage.toolCalls?.isNotEmpty ?? false) {
        print('Received ${assistantMessage.toolCalls!.length} tool call(s)');

        for (final toolCall in assistantMessage.toolCalls!) {
          print('  TOOL CALL: ${toolCall.function.name}');
          print('  ARGUMENTS: ${toolCall.function.arguments}');

          try {
            final args =
                jsonDecode(toolCall.function.arguments) as Map<String, dynamic>;
            final itemDescription = args['actionItemDescription'] as String;
            roundItems.add(itemDescription);
            allCreatedItems.add(itemDescription);

            // Add tool response
            messages.add(ChatCompletionMessage.tool(
              toolCallId: toolCall.id,
              content: 'Created: $itemDescription',
            ));
          } catch (e) {
            print('  ERROR parsing: $e');
          }
        }

        print('\nCreated in this round: ${roundItems.join(', ')}');
        print('Total created so far: ${allCreatedItems.length} items\n');

        // Check if we have all items
        if (allCreatedItems.length >= targetItems.length) {
          print('All items created!');
          continueConversation = false;
        } else {
          // Mirror back and ask for more
          final remainingCount = targetItems.length - allCreatedItems.length;
          final continuationPrompt = '''
Great! I've successfully created ${roundItems.length} item(s): ${roundItems.join(', ')}.

So far we have ${allCreatedItems.length} items total: ${allCreatedItems.join(', ')}.

Are there more items from the pizza shopping list? If yes, please create the remaining $remainingCount item(s).''';

          messages.add(ChatCompletionMessage.user(
            content:
                ChatCompletionUserMessageContent.string(continuationPrompt),
          ));

          print('USER: $continuationPrompt\n');
        }
      } else {
        // No tool calls - check response
        final content =
            assistantMessage.content?.toString().toLowerCase() ?? '';
        if (content.contains('done') ||
            content.contains('complete') ||
            content.contains('all items') ||
            content.contains('that\'s all')) {
          print('Assistant indicates completion');
          continueConversation = false;
        } else if (allCreatedItems.isEmpty) {
          // No items yet, try a more direct prompt
          messages.add(ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(
                'Please use the createChecklistItem function to create the items I listed.'),
          ));
          print('USER: Requesting function usage...\n');
        } else {
          print('No more items to create');
          continueConversation = false;
        }
      }
    } catch (e) {
      print('ERROR: $e');
      continueConversation = false;
    }
  }

  // Summary
  print('\n=== MODEL SUMMARY: $model ===');
  print('Total items created: ${allCreatedItems.length}');
  print('Items:');
  for (var i = 0; i < allCreatedItems.length; i++) {
    print('  ${i + 1}. ${allCreatedItems[i]}');
  }
  print('Total rounds: $rounds');
  print(
      'Average items per round: ${allCreatedItems.isEmpty ? 0 : (allCreatedItems.length / rounds).toStringAsFixed(2)}');
  print(
      'Success: ${allCreatedItems.length >= targetItems.length ? "YES" : "NO"}');
}
