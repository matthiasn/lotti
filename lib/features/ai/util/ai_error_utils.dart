import 'dart:convert';
import 'dart:io';

import 'package:lotti/features/ai/model/inference_error.dart';

/// Utility class for AI feature error handling.
class AiErrorUtils {
  /// Extracts a detailed error message from various error object structures.
  ///
  /// Attempts to find a 'detail' field within the error, potentially decoding
  /// a JSON string body. Falls back to a general 'message' field or the
  /// string representation of the error if specific details aren't found.
  static String extractDetailedErrorMessage(
    dynamic error, {
    String? defaultMessage,
  }) {
    // Handle null error input upfront
    if (error == null) {
      return defaultMessage ??
          'Unknown error (null object)'; // Provide a more informative default if error is null
    }

    var extractedMessage = error.toString();
    var specificFieldWasAccessed = false;

    final dynamic dynError = error;
    try {
      dynamic errorBody;
      try {
        // ignore: avoid_dynamic_calls
        errorBody = dynError.body;
      } catch (_) {
        // dynError doesn't have a .body property or access failed
      }

      dynamic detailContent;

      if (errorBody != null) {
        if (errorBody is Map && errorBody.containsKey('detail')) {
          detailContent = errorBody['detail'];
          specificFieldWasAccessed = true;
        } else if (errorBody is String) {
          try {
            final decodedBody = jsonDecode(errorBody) as Map<String, dynamic>;
            if (decodedBody.containsKey('detail')) {
              detailContent = decodedBody['detail'];
              specificFieldWasAccessed = true;
            }
          } catch (_) {
            // JSON decoding failed, or not a map, or no 'detail' key
          }
        }
      }

      if (specificFieldWasAccessed && detailContent != null) {
        extractedMessage = detailContent.toString();
      } else if (specificFieldWasAccessed && detailContent == null) {
        // If 'detail' was present but was null, its string is "null"
        extractedMessage = 'null';
      } else {
        dynamic errorMessageFromError;
        var messageFieldAccessed = false;
        try {
          // ignore: avoid_dynamic_calls
          errorMessageFromError = dynError.message;
          messageFieldAccessed = true; // assume accessed if no throw
        } catch (_) {
          // dynError doesn't have a .message property or access failed
        }

        if (messageFieldAccessed && errorMessageFromError != null) {
          extractedMessage = errorMessageFromError.toString();
          specificFieldWasAccessed =
              true; // A specific field (message) was now found
        } else if (messageFieldAccessed && errorMessageFromError == null) {
          // If 'message' was present but was null, its string is "null"
          extractedMessage = 'null';
          specificFieldWasAccessed =
              true; // A specific field (message) was now found
        }
        // If no specific field (detail or message) was found,
        // extractedMessage remains error.toString() and specificFieldWasAccessed is false.
      }
    } catch (extractionException) {
      // If any part of the extraction itself fails,
      // extractedMessage remains error.toString().
      // Optionally log extractionException here if needed.
    }

    // If a specific field was targeted and resulted in an empty or "null" string,
    // or if no specific field was found and error.toString() is empty or "null",
    // then use the defaultMessage. If defaultMessage is also null, fall back to a generic message or original error.toString().
    if (extractedMessage.trim().isEmpty ||
        extractedMessage.trim().toLowerCase() == 'null') {
      return defaultMessage ??
          error
              .toString(); // Fallback to error.toString() if default is also null and initial extraction was bad
    }

    return extractedMessage;
  }

  /// Converts various error types into InferenceError with appropriate categorization
  static InferenceError categorizeError(
    dynamic error, {
    StackTrace? stackTrace,
  }) {
    // Handle null error
    if (error == null) {
      return InferenceError(
        message: 'An unknown error occurred',
        type: InferenceErrorType.unknown,
        stackTrace: stackTrace,
      );
    }

    // Network connection errors
    if (error is SocketException ||
        error.toString().contains('SocketException') ||
        error.toString().contains('Failed host lookup') ||
        error.toString().contains('Connection refused') ||
        error.toString().contains('Connection closed') ||
        error.toString().contains('No address associated with hostname')) {
      return InferenceError(
        message: _getNetworkErrorMessage(error),
        type: InferenceErrorType.networkConnection,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Timeout errors
    if (error.toString().contains('TimeoutException') ||
        error.toString().contains('timed out') ||
        error.toString().contains('timeout')) {
      return InferenceError(
        message:
            'The request timed out. The server might be slow or unresponsive.',
        type: InferenceErrorType.timeout,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Check for OpenAI-style API errors by examining the error structure
    if (error.runtimeType.toString().contains('OpenAI') ||
        error.runtimeType.toString().contains('RequestException')) {
      return _handleApiError(error, stackTrace);
    }

    // HTTP status code errors
    final errorString = error.toString();
    if (errorString.contains('401') || errorString.contains('Unauthorized')) {
      return InferenceError(
        message: 'Authentication failed. Please check your API key.',
        type: InferenceErrorType.authentication,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (errorString.contains('429') || errorString.contains('Rate limit')) {
      return InferenceError(
        message:
            'Rate limit exceeded. Please wait before making more requests.',
        type: InferenceErrorType.rateLimit,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (errorString.contains('400') || errorString.contains('Bad Request')) {
      return InferenceError(
        message: extractDetailedErrorMessage(error,
            defaultMessage:
                'Invalid request. Please check your configuration.'),
        type: InferenceErrorType.invalidRequest,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('504') ||
        errorString.contains('Internal Server Error') ||
        errorString.contains('Bad Gateway') ||
        errorString.contains('Service Unavailable')) {
      return InferenceError(
        message:
            'The AI service is experiencing issues. Please try again later.',
        type: InferenceErrorType.serverError,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    // Default to unknown error with extracted message
    return InferenceError(
      message: extractDetailedErrorMessage(error),
      type: InferenceErrorType.unknown,
      originalError: error,
      stackTrace: stackTrace,
    );
  }

  static String _getNetworkErrorMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('failed host lookup') ||
        errorString.contains('no address associated')) {
      return 'Unable to resolve the server address. Please check your internet connection and the server URL.';
    }

    if (errorString.contains('connection refused')) {
      return 'Connection refused. The server may be down or not accepting connections.';
    }

    if (errorString.contains('connection closed')) {
      return 'Connection was closed unexpectedly. Please try again.';
    }

    return 'Unable to connect to the AI service. Please check your internet connection and try again.';
  }

  static InferenceError _handleApiError(
    dynamic error,
    StackTrace? stackTrace,
  ) {
    // Try to extract status code from error
    final errorString = error.toString();

    if (errorString.contains('401') || errorString.contains('Unauthorized')) {
      return InferenceError(
        message: 'Invalid API key. Please check your API key configuration.',
        type: InferenceErrorType.authentication,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (errorString.contains('429') || errorString.contains('Rate limit')) {
      return InferenceError(
        message:
            'Rate limit exceeded. Please wait before making more requests.',
        type: InferenceErrorType.rateLimit,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (errorString.contains('400') || errorString.contains('Bad Request')) {
      return InferenceError(
        message: extractDetailedErrorMessage(error),
        type: InferenceErrorType.invalidRequest,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    if (errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('504') ||
        errorString.contains('Internal Server Error') ||
        errorString.contains('Bad Gateway') ||
        errorString.contains('Service Unavailable')) {
      return InferenceError(
        message:
            'The AI service is experiencing issues. Please try again later.',
        type: InferenceErrorType.serverError,
        originalError: error,
        stackTrace: stackTrace,
      );
    }

    return InferenceError(
      message: extractDetailedErrorMessage(error),
      type: InferenceErrorType.unknown,
      originalError: error,
      stackTrace: stackTrace,
    );
  }
}
