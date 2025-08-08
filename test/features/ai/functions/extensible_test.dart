import 'dart:convert';

import 'package:lotti/features/ai/functions/function_handler.dart';
import 'package:openai_dart/openai_dart.dart';

/// Test the extensible function handler system
///
/// Run with: dart test/features/ai/functions/extensible_test.dart

void main() async {
  print('=== Extensible Function Handler Test ===\n');

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
    
    await testMultipleFunctions(client, model);
  }
}

Future<void> testMultipleFunctions(OpenAIClient client, String model) async {
  print('Testing model: $model with multiple function types\n');

  // Define multiple tools
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
    const ChatCompletionTool(
      type: ChatCompletionToolType.function,
      function: FunctionObject(
        name: 'createCalendarEvent',
        description: 'Create a calendar event',
        parameters: {
          'type': 'object',
          'required': ['title', 'date'],
          'properties': {
            'title': {
              'type': 'string',
              'description': 'Event title',
            },
            'date': {
              'type': 'string',
              'description': 'Event date (YYYY-MM-DD)',
            },
          },
        },
      ),
    ),
  ];

  // Create handlers
  final checklistHandler = ChecklistItemHandler();
  final calendarHandler = CalendarEventHandler();
  final handlers = [checklistHandler, calendarHandler];

  final messages = <ChatCompletionMessage>[
    ChatCompletionMessage.system(content: '''
You are a helpful assistant that can create checklist items and calendar events.
Use the appropriate functions based on the user's request.
'''),
  ];

  // Test 1: Mixed request
  messages.add(ChatCompletionMessage.user(
    content: ChatCompletionUserMessageContent.string('''
Please help me plan a pizza party:
1. Create a shopping checklist: dough, cheese, sauce
2. Create calendar events: "Buy ingredients" on 2024-12-20 and "Pizza party" on 2024-12-21
'''),
  ));

  print('USER: Plan pizza party with checklist and calendar events\n');

  var continueProcessing = true;
  var rounds = 0;
  const maxRounds = 5;

  while (continueProcessing && rounds < maxRounds) {
    rounds++;
    print('\n--- Round $rounds ---');

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
        print('Received ${assistantMessage.toolCalls!.length} function call(s):\n');

        for (final call in assistantMessage.toolCalls!) {
          // Find appropriate handler
          final handler = handlers.firstWhere(
            (h) => h.functionName == call.function.name,
            orElse: () => throw Exception('No handler for ${call.function.name}'),
          );

          // Process the call
          final result = handler.processFunctionCall(call);
          
          print('${call.function.name}:');
          print('  Arguments: ${call.function.arguments}');
          
          if (result.success) {
            final isDupe = handler.isDuplicate(result);
            if (!isDupe) {
              print('  ✓ Success: ${handler.getDescription(result)}');
            } else {
              print('  ⚠️  Duplicate: ${handler.getDescription(result)}');
            }
          } else {
            print('  ✗ Error: ${result.error}');
            final attempted = handler.getDescription(result);
            if (attempted != null && attempted.isNotEmpty) {
              print('    Attempted: $attempted');
            }
          }
          
          // Add tool response
          messages.add(ChatCompletionMessage.tool(
            toolCallId: result.data['toolCallId'] as String,
            content: handler.createToolResponse(result),
          ));
        }
        
        // Continue conversation
        messages.add(ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string(
            'Please continue if there are more items to create.'
          ),
        ));
      } else {
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

  // Test 2: Error handling with wrong field names
  print('\n\n=== Testing Error Handling ===\n');
  
  // Reset handlers
  checklistHandler.reset();
  calendarHandler.reset();

  // Simulate calls with errors
  final errorCalls = [
    ChatCompletionMessageToolCall(
      id: 'call_1',
      type: ChatCompletionMessageToolCallType.function,
      function: ChatCompletionMessageFunctionCall(
        name: 'createChecklistItem',
        arguments: '{"description":"pepperoni"}', // Wrong field name
      ),
    ),
    ChatCompletionMessageToolCall(
      id: 'call_2',
      type: ChatCompletionMessageToolCallType.function,
      function: ChatCompletionMessageFunctionCall(
        name: 'createCalendarEvent',
        arguments: '{"name":"Team meeting","when":"tomorrow"}', // Wrong field names
      ),
    ),
  ];

  print('Processing calls with errors:\n');
  
  final failedResults = <String, List<FunctionCallResult>>{};
  
  for (final call in errorCalls) {
    final handler = handlers.firstWhere((h) => h.functionName == call.function.name);
    final result = handler.processFunctionCall(call);
    
    print('${call.function.name}:');
    print('  Arguments: ${call.function.arguments}');
    print('  ✗ Error: ${result.error}');
    
    failedResults.putIfAbsent(handler.functionName, () => []).add(result);
  }

  // Generate retry prompts
  print('\n--- Retry Prompts ---\n');
  
  for (final entry in failedResults.entries) {
    final handler = handlers.firstWhere((h) => h.functionName == entry.key);
    final retryPrompt = handler.getRetryPrompt(
      failedItems: entry.value,
      successfulDescriptions: [], // No successes yet
    );
    
    print('For ${handler.functionName}:');
    print(retryPrompt);
    print('');
  }
}