import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Custom error types for AI inference operations
class InferenceError implements Exception {
  InferenceError({
    required this.message,
    required this.type,
    this.originalError,
    this.stackTrace,
  });

  final String message;
  final InferenceErrorType type;
  final dynamic originalError;
  final StackTrace? stackTrace;

  @override
  String toString() => message;
}

/// Types of errors that can occur during inference
enum InferenceErrorType {
  /// Network connection failed (no internet, server unreachable)
  networkConnection,

  /// Request timed out
  timeout,

  /// Authentication failed (invalid API key, expired token)
  authentication,

  /// Rate limit exceeded
  rateLimit,

  /// Invalid request (bad model, invalid parameters)
  invalidRequest,

  /// Server error (5xx errors)
  serverError,

  /// Unknown/generic error
  unknown,
}

/// Extension to provide user-friendly error messages
extension InferenceErrorTypeExtension on InferenceErrorType {
  String getTitle(BuildContext context) {
    switch (this) {
      case InferenceErrorType.networkConnection:
        return context.messages.aiInferenceErrorConnectionFailedTitle;
      case InferenceErrorType.timeout:
        return context.messages.aiInferenceErrorTimeoutTitle;
      case InferenceErrorType.authentication:
        return context.messages.aiInferenceErrorAuthenticationTitle;
      case InferenceErrorType.rateLimit:
        return context.messages.aiInferenceErrorRateLimitTitle;
      case InferenceErrorType.invalidRequest:
        return context.messages.aiInferenceErrorInvalidRequestTitle;
      case InferenceErrorType.serverError:
        return context.messages.aiInferenceErrorServerTitle;
      case InferenceErrorType.unknown:
        return context.messages.aiInferenceErrorUnknownTitle;
    }
  }

  String getDefaultMessage(BuildContext context) {
    switch (this) {
      case InferenceErrorType.networkConnection:
        return context.messages.aiInferenceErrorConnectionFailedMessage;
      case InferenceErrorType.timeout:
        return context.messages.aiInferenceErrorTimeoutMessage;
      case InferenceErrorType.authentication:
        return context.messages.aiInferenceErrorAuthenticationMessage;
      case InferenceErrorType.rateLimit:
        return context.messages.aiInferenceErrorRateLimitMessage;
      case InferenceErrorType.invalidRequest:
        return context.messages.aiInferenceErrorInvalidRequestMessage;
      case InferenceErrorType.serverError:
        return context.messages.aiInferenceErrorServerMessage;
      case InferenceErrorType.unknown:
        return context.messages.aiInferenceErrorUnknownMessage;
    }
  }

  String get defaultMessage {
    switch (this) {
      case InferenceErrorType.networkConnection:
        return 'Unable to connect to the AI service. Please check your internet connection and ensure the service is accessible.';
      case InferenceErrorType.timeout:
        return 'The request took too long to complete. Please try again or check if the service is responding.';
      case InferenceErrorType.authentication:
        return 'Authentication failed. Please check your API key and ensure it is valid.';
      case InferenceErrorType.rateLimit:
        return 'You have exceeded the rate limit. Please wait a moment before trying again.';
      case InferenceErrorType.invalidRequest:
        return 'The request was invalid. Please check your configuration and try again.';
      case InferenceErrorType.serverError:
        return 'The AI service encountered an error. Please try again later.';
      case InferenceErrorType.unknown:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}
