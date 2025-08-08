import 'dart:convert';

import 'package:openai_dart/openai_dart.dart';

/// Base interface for handling different function types in conversations
abstract class FunctionHandler {
  /// The name of the function this handler processes
  String get functionName;
  
  /// Process a function call and return the result
  FunctionCallResult processFunctionCall(ChatCompletionMessageToolCall call);
  
  /// Check if this result would be a duplicate
  bool isDuplicate(FunctionCallResult result);
  
  /// Get a retry prompt for failed items of this type
  String getRetryPrompt({
    required List<FunctionCallResult> failedItems,
    required List<String> successfulDescriptions,
  });
  
  /// Extract the human-readable description from the result
  String? getDescription(FunctionCallResult result);
  
  /// Create a tool response message
  String createToolResponse(FunctionCallResult result);
}

/// Result of processing a function call
class FunctionCallResult {
  const FunctionCallResult({
    required this.success,
    required this.functionName,
    required this.arguments,
    required this.data,
    this.error,
  });
  
  final bool success;
  final String functionName;
  final String arguments; // Raw JSON string
  final Map<String, dynamic> data; // Parsed data or error info
  final String? error;
  
  Map<String, dynamic> get parsedArguments {
    try {
      return jsonDecode(arguments) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }
}

/// Handler for checklist item creation
class ChecklistItemHandler extends FunctionHandler {
  ChecklistItemHandler();
  
  final Set<String> _createdDescriptions = {};
  
  @override
  String get functionName => 'createChecklistItem';
  
  @override
  FunctionCallResult processFunctionCall(ChatCompletionMessageToolCall call) {
    try {
      final args = jsonDecode(call.function.arguments) as Map<String, dynamic>;
      final description = args['actionItemDescription'] as String?;
      
      if (description != null) {
        return FunctionCallResult(
          success: true,
          functionName: functionName,
          arguments: call.function.arguments,
          data: {
            'description': description,
            'toolCallId': call.id,
          },
        );
      } else {
        // Try to extract attempted item
        String? attemptedItem;
        String? wrongFieldName;
        
        for (final entry in args.entries) {
          if (entry.value is String && entry.value.toString().isNotEmpty) {
            attemptedItem = entry.value.toString();
            wrongFieldName = entry.key;
            break;
          }
        }
        
        return FunctionCallResult(
          success: false,
          functionName: functionName,
          arguments: call.function.arguments,
          data: {
            'attemptedItem': attemptedItem ?? '',
            'wrongFieldName': wrongFieldName,
            'toolCallId': call.id,
          },
          error: 'Found "${wrongFieldName ?? "unknown"}" instead of "actionItemDescription"',
        );
      }
    } catch (e) {
      return FunctionCallResult(
        success: false,
        functionName: functionName,
        arguments: call.function.arguments,
        data: {'toolCallId': call.id},
        error: 'Invalid JSON: $e',
      );
    }
  }
  
  @override
  bool isDuplicate(FunctionCallResult result) {
    if (!result.success) return false;
    
    final description = result.data['description'] as String?;
    if (description == null) return false;
    
    final normalized = description.toLowerCase().trim();
    if (_createdDescriptions.contains(normalized)) {
      return true;
    }
    
    _createdDescriptions.add(normalized);
    return false;
  }
  
  @override
  String? getDescription(FunctionCallResult result) {
    if (result.success) {
      return result.data['description'] as String?;
    } else {
      return result.data['attemptedItem'] as String?;
    }
  }
  
  @override
  String createToolResponse(FunctionCallResult result) {
    if (result.success) {
      final description = result.data['description'] as String;
      return 'Created: $description';
    } else {
      return 'Error: ${result.error}';
    }
  }
  
  @override
  String getRetryPrompt({
    required List<FunctionCallResult> failedItems,
    required List<String> successfulDescriptions,
  }) {
    final errorSummary = failedItems.map((item) {
      final attempted = getDescription(item);
      final attemptedStr = attempted != null ? ' for "$attempted"' : '';
      return '- ${item.error}$attemptedStr';
    }).join('\n');
    
    final itemsToRetry = failedItems
        .map((item) => getDescription(item))
        .where((desc) => desc != null && desc.isNotEmpty)
        .toList();
    
    return '''
I noticed ${failedItems.length == 1 ? 'an error' : 'errors'} in your function call${failedItems.length > 1 ? 's' : ''}:
$errorSummary

You already successfully created these items: ${successfulDescriptions.join(', ')}

Please create ONLY the failed item${itemsToRetry.length > 1 ? 's' : ''}: ${itemsToRetry.join(', ')}

Use the correct format:
{"actionItemDescription": "item description"}

Do NOT recreate the items that were already successful.''';
  }
  
  void reset() {
    _createdDescriptions.clear();
  }
}

/// Example: Handler for a different function type (e.g., adding calendar events)
class CalendarEventHandler extends FunctionHandler {
  CalendarEventHandler();
  
  final Set<String> _createdEvents = {};
  
  @override
  String get functionName => 'createCalendarEvent';
  
  @override
  FunctionCallResult processFunctionCall(ChatCompletionMessageToolCall call) {
    try {
      final args = jsonDecode(call.function.arguments) as Map<String, dynamic>;
      final title = args['title'] as String?;
      final date = args['date'] as String?;
      
      if (title != null && date != null) {
        return FunctionCallResult(
          success: true,
          functionName: functionName,
          arguments: call.function.arguments,
          data: {
            'title': title,
            'date': date,
            'toolCallId': call.id,
          },
        );
      } else {
        final missingFields = <String>[];
        if (title == null) missingFields.add('title');
        if (date == null) missingFields.add('date');
        
        return FunctionCallResult(
          success: false,
          functionName: functionName,
          arguments: call.function.arguments,
          data: {
            'attemptedTitle': title ?? args['name'] ?? args['event'] ?? '',
            'attemptedDate': date ?? args['datetime'] ?? args['when'] ?? '',
            'toolCallId': call.id,
          },
          error: 'Missing required fields: ${missingFields.join(', ')}',
        );
      }
    } catch (e) {
      return FunctionCallResult(
        success: false,
        functionName: functionName,
        arguments: call.function.arguments,
        data: {'toolCallId': call.id},
        error: 'Invalid JSON: $e',
      );
    }
  }
  
  @override
  bool isDuplicate(FunctionCallResult result) {
    if (!result.success) return false;
    
    final title = result.data['title'] as String?;
    final date = result.data['date'] as String?;
    if (title == null || date == null) return false;
    
    final key = '${title.toLowerCase()}|$date';
    if (_createdEvents.contains(key)) {
      return true;
    }
    
    _createdEvents.add(key);
    return false;
  }
  
  @override
  String? getDescription(FunctionCallResult result) {
    if (result.success) {
      return '${result.data['title']} on ${result.data['date']}';
    } else {
      final title = result.data['attemptedTitle'] as String?;
      final date = result.data['attemptedDate'] as String?;
      if (title != null && title.isNotEmpty) {
        return date != null && date.isNotEmpty ? '$title on $date' : title;
      }
      return null;
    }
  }
  
  @override
  String createToolResponse(FunctionCallResult result) {
    if (result.success) {
      return 'Created event: ${getDescription(result)}';
    } else {
      return 'Error: ${result.error}';
    }
  }
  
  @override
  String getRetryPrompt({
    required List<FunctionCallResult> failedItems,
    required List<String> successfulDescriptions,
  }) {
    final errorSummary = failedItems.map((item) {
      final attempted = getDescription(item);
      final attemptedStr = attempted != null ? ' for "$attempted"' : '';
      return '- ${item.error}$attemptedStr';
    }).join('\n');
    
    return '''
I noticed errors in your calendar event creation:
$errorSummary

Successfully created events: ${successfulDescriptions.join(', ')}

Please retry with the correct format:
{"title": "event title", "date": "YYYY-MM-DD"}''';
  }
  
  void reset() {
    _createdEvents.clear();
  }
}