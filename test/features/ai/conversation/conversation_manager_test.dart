import 'dart:async';
import 'dart:convert';
import 'package:openai_dart/openai_dart.dart';

/// A flexible conversation manager that maintains context and handles multi-turn interactions
/// 
/// Design goals:
/// - Support various conversation patterns (single-shot, multi-turn, function calling)
/// - Maintain conversation history and context
/// - Allow custom conversation strategies
/// - Enable progress tracking and state management
/// - Be reusable for different AI features in Lotti

/// Represents a single conversation turn
class ConversationTurn {
  ConversationTurn({
    required this.role,
    required this.content,
    this.toolCalls,
    this.toolCallId,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  
  final String role; // 'system', 'user', 'assistant', 'tool'
  final String? content;
  final List<ChatCompletionMessageToolCall>? toolCalls;
  final String? toolCallId;
  final DateTime timestamp;
  
  ChatCompletionMessage toChatMessage() {
    switch (role) {
      case 'system':
        return ChatCompletionMessage.system(content: content!);
      case 'user':
        return ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string(content!),
        );
      case 'assistant':
        return ChatCompletionMessage.assistant(
          content: content,
          toolCalls: toolCalls,
        );
      case 'tool':
        return ChatCompletionMessage.tool(
          toolCallId: toolCallId!,
          content: content!,
        );
      default:
        throw ArgumentError('Unknown role: $role');
    }
  }
}

/// Manages a conversation with an AI model
class ConversationManager {
  ConversationManager({
    required this.client,
    required this.model,
    this.systemMessage,
    this.tools,
    this.temperature = 0.7,
    this.maxTurns = 20,
  });
  
  final OpenAIClient client;
  final String model;
  final String? systemMessage;
  final List<ChatCompletionTool>? tools;
  final double temperature;
  final int maxTurns;
  
  final List<ConversationTurn> _history = [];
  final _eventController = StreamController<ConversationEvent>.broadcast();
  
  List<ConversationTurn> get history => List.unmodifiable(_history);
  Stream<ConversationEvent> get events => _eventController.stream;
  
  /// Start a new conversation
  void initialize() {
    _history.clear();
    if (systemMessage != null) {
      _history.add(ConversationTurn(
        role: 'system',
        content: systemMessage,
      ));
    }
    _eventController.add(ConversationEvent.initialized());
  }
  
  /// Add a user message and get AI response
  Future<ConversationTurn> sendMessage(String message) async {
    // Add user message
    final userTurn = ConversationTurn(
      role: 'user',
      content: message,
    );
    _history.add(userTurn);
    _eventController.add(ConversationEvent.userMessage(message));
    
    // Check turn limit
    if (_history.where((t) => t.role == 'user').length > maxTurns) {
      throw Exception('Maximum conversation turns ($maxTurns) exceeded');
    }
    
    try {
      // Prepare messages
      final messages = _history.map((turn) => turn.toChatMessage()).toList();
      
      // Make API call
      _eventController.add(ConversationEvent.thinking());
      
      final response = await client.createChatCompletion(
        request: CreateChatCompletionRequest(
          model: ChatCompletionModel.modelId(model),
          messages: messages,
          tools: tools,
          toolChoice: tools != null 
            ? ChatCompletionToolChoiceOption.mode(ChatCompletionToolChoiceMode.auto)
            : null,
          temperature: temperature,
        ),
      );
      
      final assistantMessage = response.choices.first.message;
      
      // Create assistant turn
      final assistantTurn = ConversationTurn(
        role: 'assistant',
        content: assistantMessage.content,
        toolCalls: assistantMessage.toolCalls,
      );
      _history.add(assistantTurn);
      
      // Emit appropriate event
      if (assistantMessage.toolCalls?.isNotEmpty ?? false) {
        _eventController.add(ConversationEvent.toolCalls(
          assistantMessage.toolCalls!,
        ));
      } else {
        _eventController.add(ConversationEvent.assistantMessage(
          assistantMessage.content ?? '',
        ));
      }
      
      return assistantTurn;
      
    } catch (e) {
      _eventController.add(ConversationEvent.error(e.toString()));
      rethrow;
    }
  }
  
  /// Add tool response
  void addToolResponse(String toolCallId, String response) {
    final toolTurn = ConversationTurn(
      role: 'tool',
      toolCallId: toolCallId,
      content: response,
    );
    _history.add(toolTurn);
    _eventController.add(ConversationEvent.toolResponse(toolCallId, response));
  }
  
  /// Continue conversation after tool calls
  Future<ConversationTurn> continueAfterTools() async {
    return sendMessage(''); // Empty message to continue
  }
  
  /// Get conversation summary
  String getSummary() {
    final buffer = StringBuffer();
    for (final turn in _history) {
      if (turn.role != 'system') {
        buffer.writeln('${turn.role.toUpperCase()}: ${turn.content ?? '(function calls)'}');
      }
    }
    return buffer.toString();
  }
  
  void dispose() {
    _eventController.close();
  }
}

/// Events emitted during conversation
abstract class ConversationEvent {
  const ConversationEvent();
  
  factory ConversationEvent.initialized() = InitializedEvent;
  factory ConversationEvent.userMessage(String message) = UserMessageEvent;
  factory ConversationEvent.thinking() = ThinkingEvent;
  factory ConversationEvent.assistantMessage(String message) = AssistantMessageEvent;
  factory ConversationEvent.toolCalls(List<ChatCompletionMessageToolCall> calls) = ToolCallsEvent;
  factory ConversationEvent.toolResponse(String toolCallId, String response) = ToolResponseEvent;
  factory ConversationEvent.error(String message) = ErrorEvent;
}

class InitializedEvent extends ConversationEvent {
  const InitializedEvent();
}

class UserMessageEvent extends ConversationEvent {
  const UserMessageEvent(this.message);
  final String message;
}

class ThinkingEvent extends ConversationEvent {
  const ThinkingEvent();
}

class AssistantMessageEvent extends ConversationEvent {
  const AssistantMessageEvent(this.message);
  final String message;
}

class ToolCallsEvent extends ConversationEvent {
  const ToolCallsEvent(this.calls);
  final List<ChatCompletionMessageToolCall> calls;
}

class ToolResponseEvent extends ConversationEvent {
  const ToolResponseEvent(this.toolCallId, this.response);
  final String toolCallId;
  final String response;
}

class ErrorEvent extends ConversationEvent {
  const ErrorEvent(this.message);
  final String message;
}

/// Test the conversation manager
void main() async {
  print('=== Conversation Manager Test ===\n');
  
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
    
    // Test 1: Simple conversation
    print('--- Test 1: Simple Conversation with $model ---\n');
    await testSimpleConversation(client, model);
    
    // Test 2: Function calling conversation
    print('\n--- Test 2: Function Calling Conversation with $model ---\n');
    await testFunctionCallingConversation(client, model);
    
    // Test 3: Batch processing use case
    print('\n--- Test 3: Batch Processing Use Case with $model ---\n');
    await testBatchProcessing(client, model);
  }
}

Future<void> testSimpleConversation(OpenAIClient client, String model) async {
  final manager = ConversationManager(
    client: client,
    model: model,
    systemMessage: 'You are a helpful assistant.',
    temperature: 0.7,
  );
  
  // Listen to events
  manager.events.listen((event) {
    switch (event) {
      case ThinkingEvent():
        print('[Thinking...]');
      case AssistantMessageEvent(:final message):
        print('ASSISTANT: $message');
      case ErrorEvent(:final message):
        print('ERROR: $message');
      default:
        // Handle other events
    }
  });
  
  manager.initialize();
  
  // Send a message
  await manager.sendMessage('What are the main ingredients for pizza dough?');
  
  // Follow up
  await manager.sendMessage('How much water should I use for 500g of flour?');
  
  print('\n--- Conversation Summary ---');
  print(manager.getSummary());
  
  manager.dispose();
}

Future<void> testFunctionCallingConversation(OpenAIClient client, String model) async {
  // Define a simple tool
  final tools = [
    const ChatCompletionTool(
      type: ChatCompletionToolType.function,
      function: FunctionObject(
        name: 'calculate',
        description: 'Perform a calculation',
        parameters: {
          'type': 'object',
          'required': ['expression'],
          'properties': {
            'expression': {
              'type': 'string',
              'description': 'Mathematical expression to evaluate',
            },
          },
        },
      ),
    ),
  ];
  
  final manager = ConversationManager(
    client: client,
    model: model,
    systemMessage: 'You are a helpful math assistant. Use the calculate function when needed.',
    tools: tools,
    temperature: 0.1,
  );
  
  var toolCallsReceived = false;
  
  manager.events.listen((event) {
    switch (event) {
      case ToolCallsEvent(:final calls):
        print('TOOL CALLS: ${calls.length}');
        for (final call in calls) {
          print('  ${call.function.name}(${call.function.arguments})');
          // Simulate tool execution
          manager.addToolResponse(call.id, 'Result: 42');
        }
        toolCallsReceived = true;
      case AssistantMessageEvent(:final message):
        print('ASSISTANT: $message');
      default:
        // Handle other events
    }
  });
  
  manager.initialize();
  await manager.sendMessage('What is 6 times 7?');
  
  // If we got tool calls, continue the conversation
  if (toolCallsReceived) {
    await manager.continueAfterTools();
  }
  
  // Wait a bit for async operations to complete
  await Future.delayed(const Duration(milliseconds: 100));
  
  manager.dispose();
}

Future<void> testBatchProcessing(OpenAIClient client, String model) async {
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
  
  final manager = ConversationManager(
    client: client,
    model: model,
    systemMessage: 'Create checklist items as requested.',
    tools: tools,
    temperature: 0.1,
  );
  
  final createdItems = <String>[];
  var shouldContinue = true;
  final completer = Completer<void>();
  
  manager.events.listen((event) {
    switch (event) {
      case ToolCallsEvent(:final calls):
        print('MODEL $model created ${calls.length} items:');
        for (var i = 0; i < calls.length; i++) {
          final call = calls[i];
          print('  Item ${i + 1}: ${call.function.name}');
          print('  Arguments: ${call.function.arguments}');
          
          // Try to parse the arguments to check validity
          try {
            final args = jsonDecode(call.function.arguments) as Map<String, dynamic>;
            if (args.containsKey('actionItemDescription')) {
              print('  ✓ Valid: "${args['actionItemDescription']}"');
            } else {
              print('  ✗ Invalid: missing actionItemDescription key');
              print('    Keys found: ${args.keys.join(', ')}');
            }
          } catch (e) {
            print('  ✗ JSON Parse Error: $e');
          }
          
          createdItems.add(call.function.arguments);
          manager.addToolResponse(call.id, 'Created');
        }
        
        if (shouldContinue && createdItems.length < 6) {
          // Schedule continuation for next microtask
          Future.microtask(() async {
            try {
              await manager.sendMessage(
                'Good! Created ${calls.length} items. '
                'Please continue with the remaining items from the pizza list.'
              );
            } catch (e) {
              print('Error continuing: $e');
              if (!completer.isCompleted) {
                completer.complete();
              }
            }
          });
        } else {
          // All items created or should stop
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
      case AssistantMessageEvent(:final message):
        if (message.toLowerCase().contains('done') || 
            message.toLowerCase().contains('complete')) {
          shouldContinue = false;
          if (!completer.isCompleted) {
            completer.complete();
          }
        }
      case ErrorEvent(:final message):
        print('ERROR: $message');
        if (!completer.isCompleted) {
          completer.complete();
        }
      default:
        // Handle other events
    }
  });
  
  manager.initialize();
  
  try {
    await manager.sendMessage(
      'Create a shopping checklist for pizza: '
      'dough, cheese, sauce, pepperoni, mushrooms, olive oil'
    );
    
    // Wait for completion or timeout
    await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        print('Timeout waiting for completion');
      },
    );
  } catch (e) {
    print('Error in batch processing: $e');
  }
  
  print('\nTotal items created: ${createdItems.length}');
  
  manager.dispose();
}