import 'dart:convert';
import 'package:openai_dart/openai_dart.dart';

/// Test harness for conversation continuation with GPT-OSS models
/// 
/// This tests the hypothesis that we can maintain a conversation where:
/// 1. User provides a batch request
/// 2. Model processes one item
/// 3. System asks for the next item
/// 4. Model continues with context
/// 
/// Run with: dart test/features/ai/functions/conversation_continuation_test.dart

void main() async {
  print('=== Conversation Continuation Test ===\n');
  
  const baseUrl = 'http://localhost:11434/v1';
  const model = 'gpt-oss:20b'; // or 'qwen2.5:8b'
  
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
  
  // Conversation state
  final messages = <ChatCompletionMessage>[];
  final createdItems = <String>[];
  
  // Initial user request
  messages.add(ChatCompletionMessage.user(
    content: ChatCompletionUserMessageContent.string(
      'Create a shopping checklist for making pizza with these items: pizza dough, mozzarella cheese, tomato sauce, pepperoni, mushrooms, olive oil'
    ),
  ));
  
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
            ChatCompletionToolChoiceMode.auto,
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
            content: 'Created checklist item: $itemDescription',
          ));
          
          // Ask for next item
          final continuationPrompt = _generateContinuationPrompt(createdItems);
          messages.add(ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(continuationPrompt),
          ));
          
          print('\nUSER: $continuationPrompt');
          
        } catch (e) {
          print('ERROR parsing tool call: $e');
          continueConversation = false;
        }
      } else {
        // No tool call - check if we're done
        final content = assistantMessage.content?.toString().toLowerCase() ?? '';
        if (content.contains('done') || 
            content.contains('complete') || 
            content.contains('finished') ||
            content.contains('that\'s all') ||
            content.contains('no more')) {
          print('\nConversation complete - assistant indicated completion');
          continueConversation = false;
        } else if (createdItems.isEmpty) {
          print('\nNo items created yet, trying a different prompt...');
          messages.add(ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string(
              'Please create the first checklist item from the list I provided.'
            ),
          ));
        } else {
          print('\nNo tool call and unclear response, ending conversation');
          continueConversation = false;
        }
      }
      
    } catch (e) {
      print('ERROR: $e');
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
  
  // client.close(); // OpenAIClient doesn't have a close method
}

String _generateContinuationPrompt(List<String> createdItems) {
  if (createdItems.length == 1) {
    return "Good, I've created '${createdItems.last}'. What's the next item from the pizza shopping list?";
  } else {
    final itemsList = createdItems.map((item) => "'$item'").join(', ');
    return "Great! So far I have: $itemsList. What's the next item from the list?";
  }
}