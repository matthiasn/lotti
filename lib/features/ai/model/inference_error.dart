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
}
