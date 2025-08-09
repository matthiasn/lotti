import 'dart:convert';
import 'dart:developer' as developer;

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
    } catch (e) {
      developer.log(
        'Failed to parse function arguments for $functionName: $e',
        name: 'FunctionCallResult',
        error: e,
      );
      return {};
    }
  }
}
