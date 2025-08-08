import 'dart:convert';
import 'package:openai_dart/openai_dart.dart';

/// Enhanced test for conversation continuation with explicit instructions
/// 
/// Run with: dart test/features/ai/functions/conversation_continuation_v2_test.dart

void main() async {
  print('=== Conversation Continuation Test V2 ===\n');
  
  const baseUrl = 'http://localhost:11434/v1';
  const model = 'qwen3:8b'; // or 'gpt-oss:20b'
  
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
  
  // System message that emphasizes using function calls
  const systemMessage = '''
You are a helpful assistant that creates checklist items. 
When asked to create checklist items, you MUST use the createChecklistItem function.
Never describe what you would do - always use the function to actually create the item.
Process one item at a time and wait for confirmation before continuing.
''';
  
  // Conversation state
  final messages = <ChatCompletionMessage>[
    ChatCompletionMessage.system(
      content: systemMessage,
    ),
  ];
  final createdItems = <String>[];
  
  // Initial user request
  messages.add(ChatCompletionMessage.user(
    content: ChatCompletionUserMessageContent.string(
      'I need a shopping checklist for making pizza. Please create checklist items for: pizza dough, mozzarella cheese, tomato sauce, pepperoni, mushrooms, olive oil. Start with the first item.'
    ),
  ));
  
  print('SYSTEM: $systemMessage\n');
  print('USER: ${messages.last.content}');
  
  // Conversation loop
  var continueConversation = true;
  var attempts = 0;
  const maxAttempts = 10; // Safety limit
  
  while (continueConversation && attempts < maxAttempts) {
    attempts++;
    print('\n--- Attempt $attempts ---');
    
    try {
      // Make API call
      final response = await client.createChatCompletion(
        request: CreateChatCompletionRequest(
          model: ChatCompletionModel.modelId(model),
          messages: messages,
          tools: tools,
          toolChoice: ChatCompletionToolChoiceOption.mode(
            ChatCompletionToolChoiceMode.required,
          ),
          temperature: 0.1,
        ),
      );
      
      final assistantMessage = response.choices.first.message;
      messages.add(assistantMessage);
      
      print('ASSISTANT: ${assistantMessage.content ?? "(no content)"}');
      
      // Check if we got a tool call
      if (assistantMessage.toolCalls?.isNotEmpty ?? false) {
        final toolCall = assistantMessage.toolCalls!.first;
        print('TOOL CALL: ${toolCall.function.name}');
        print('ARGUMENTS: ${toolCall.function.arguments}');
        
        // Parse and store the created item
        try {
          final args = jsonDecode(toolCall.function.arguments) as Map<String, dynamic>;
          final itemDescription = args['actionItemDescription'] as String;
          createdItems.add(itemDescription);
          print('CREATED ITEM: $itemDescription');
          
          // Add tool response
          messages.add(ChatCompletionMessage.tool(
            toolCallId: toolCall.id,
            content: 'Successfully created checklist item: $itemDescription',
          ));
          
          // Check if we have all items
          if (createdItems.length >= 6) {
            print('\nAll items created!');
            continueConversation = false;
          } else {
            // Ask for next item with more explicit instructions
            final remainingCount = 6 - createdItems.length;
            final continuationPrompt = '''
Good! I've created ${createdItems.length} item(s) so far: ${createdItems.join(', ')}.

There are $remainingCount more items to create from the pizza shopping list.
Please use the createChecklistItem function to create the next item.
''';
            
            messages.add(ChatCompletionMessage.user(
              content: ChatCompletionUserMessageContent.string(continuationPrompt),
            ));
            
            print('\nUSER: $continuationPrompt');
          }
          
        } catch (e) {
          print('ERROR parsing tool call: $e');
          continueConversation = false;
        }
      } else {
        print('ERROR: No tool call received despite required mode');
        continueConversation = false;
      }
      
    } catch (e) {
      print('ERROR: $e');
      
      // If we get an error about tool_choice, try without it
      if (e.toString().contains('tool_choice') && attempts == 1) {
        print('Retrying without tool_choice...');
        // Remove the last message and try again without tool_choice
        messages.removeLast();
        attempts--; // Don't count this as an attempt
        continue;
      }
      
      continueConversation = false;
    }
  }
  
  // Summary
  print('\n=== SUMMARY ===');
  print('Total items created: ${createdItems.length}');
  print('Items:');
  for (var i = 0; i < createdItems.length; i++) {
    print('  ${i + 1}. ${createdItems[i]}');
  }
  
  print('\n=== Conversation Analysis ===');
  print('Total messages: ${messages.length}');
  print('Total attempts: $attempts');
  print('Success: ${createdItems.length >= 3 ? "YES" : "NO (expected at least 3 items)"}');
  
  // Test with different continuation strategies
  if (createdItems.length < 3) {
    print('\n=== Testing Alternative Strategy ===');
    await testAlternativeStrategy(client, model, tools);
  }
}

/// Test an alternative strategy where we explicitly list remaining items
Future<void> testAlternativeStrategy(
  OpenAIClient client,
  String model,
  List<ChatCompletionTool> tools,
) async {
  print('\nTrying with explicit remaining items strategy...\n');
  
  final messages = <ChatCompletionMessage>[
    ChatCompletionMessage.system(
      content: 'You are an assistant that creates checklist items. Always use the createChecklistItem function.',
    ),
  ];
  
  final items = ['pizza dough', 'mozzarella cheese', 'tomato sauce', 'pepperoni', 'mushrooms', 'olive oil'];
  final createdItems = <String>[];
  
  for (var i = 0; i < items.length; i++) {
    final prompt = 'Create a checklist item for: ${items[i]}';
    
    messages.add(ChatCompletionMessage.user(
      content: ChatCompletionUserMessageContent.string(prompt),
    ));
    
    print('USER: $prompt');
    
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
        final toolCall = assistantMessage.toolCalls!.first;
        final args = jsonDecode(toolCall.function.arguments) as Map<String, dynamic>;
        final itemDescription = args['actionItemDescription'] as String;
        createdItems.add(itemDescription);
        
        print('CREATED: $itemDescription');
        
        // Add tool response
        messages.add(ChatCompletionMessage.tool(
          toolCallId: toolCall.id,
          content: 'Created: $itemDescription',
        ));
      } else {
        print('NO TOOL CALL for ${items[i]}');
        break;
      }
    } catch (e) {
      print('ERROR: $e');
      break;
    }
  }
  
  print('\nAlternative strategy created ${createdItems.length} items');
}