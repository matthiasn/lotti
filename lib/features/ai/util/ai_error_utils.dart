import 'dart:convert';
import 'dart:io';

import 'package:lotti/features/ai/model/inference_error.dart';
import 'package:lotti/features/ai/repository/inference_http_exception.dart';
import 'package:lotti/features/ai/repository/ollama_inference_repository.dart';
import 'package:lotti/features/ai/repository/transcription_exception.dart';
import 'package:openai_dart/openai_dart.dart' show OpenAIClientException;

/// Utility class for AI feature error handling.
class AiErrorUtils {
  /// HTTP statuses a provider answers when the credentials are refused, in
  /// the forms the repositories report them: `error 403`, `status code: 401`,
  /// `HTTP 401`, and Mistral's `API error (HTTP 401)`, which drops the body.
  static final _authStatus = RegExp(
    r'(?:error|status(?:\s*code)?|http)[\s:=(]*(?:http\s*)?(?:401|403)\b',
    caseSensitive: false,
  );

  /// What providers say about a refused key in the response body. Gemini
  /// answers a bad key with **400** `API key not valid` (`API_KEY_INVALID`),
  /// a revoked or restricted one with 403 `PERMISSION_DENIED`.
  static const _authPhrases = [
    'api key not valid',
    'api_key_invalid',
    'permission_denied',
    'unauthenticated',
    'unauthorized',
    'invalid api key',
    'incorrect api key',
    'invalid x-api-key',
  ];

  /// [error]'s text, with a [TranscriptionException]'s cause, which its
  /// `toString` leaves out — the Melious path wraps the provider's answer
  /// there under a generic message.
  static String _textWithCause(Object error) => [
    error,
    if (error is TranscriptionException) error.originalError,
  ].whereType<Object>().join(' ');

  /// Whether [error] says the provider refused the credentials — an invalid,
  /// revoked or restricted API key.
  ///
  /// Retrying such a failure cannot succeed until the user changes the key,
  /// so callers treat it as a setup problem: they surface it and stop, or
  /// back off, instead of retrying on a short timer. Checked before rate
  /// limits, because a provider error can mention 429 in boilerplate (the
  /// Gemini streaming error does) while carrying a 403. A
  /// [TranscriptionException] is read with its cause.
  static bool isAuthenticationFailure(Object? error) {
    if (error == null) return false;
    final text = _textWithCause(error);
    if (_authStatus.hasMatch(text)) return true;
    final lower = text.toLowerCase();
    return _authPhrases.any(lower.contains);
  }

  /// HTTP 402 Payment Required, in the same textual forms as [_authStatus].
  static final _paymentRequiredStatus = RegExp(
    r'(?:error|status(?:\s*code)?|http)[\s:=(]*(?:http\s*)?402\b',
    caseSensitive: false,
  );

  /// What providers say when the account has no money left, or a spend
  /// limit stops it spending more (researched 2026-11-11 from each
  /// provider's error docs):
  ///
  /// - OpenAI: 429 `insufficient_quota`, `credit_balance_exhausted`, and the
  ///   `*_spend_limit_exceeded` / `organization_usage_limit_exceeded` codes;
  /// - Anthropic: 400 "Your credit balance is too low …";
  /// - OpenRouter: 402 "Insufficient credits", 403 "Budget limit exceeded";
  /// - Melious: 429 `billing_error` with `billing_insufficient_balance`;
  /// - Gemini: 402 or 429 "Your prepayment credits are depleted";
  /// - Alibaba DashScope: 403 `Arrearage`, and a model's exhausted free tier;
  /// - ElevenLabs: 402 `insufficient_credits`, or 401 `quota_exceeded`
  ///   "… You have 3 credits remaining …";
  /// - Mistral: a bare 402, caught by [_paymentRequiredStatus].
  ///
  /// Never "exceeded your current quota" or `quota_exceeded` alone: Gemini
  /// words its ordinary free-tier rate limit that way.
  static const _outOfCreditPhrases = [
    'insufficient_quota',
    'credit_balance_exhausted',
    'spend_limit_exceeded',
    'organization_usage_limit_exceeded',
    'credit balance is too low',
    'insufficient credits',
    'insufficient_credits',
    'billing_insufficient_balance',
    'insufficient balance',
    'credits are depleted',
    'credit balance is depleted',
    'budget limit exceeded',
    'arrearage',
    'free tier of the model has been exhausted',
    'credits remaining',
    'payment required',
    'payment_required',
  ];

  /// What makes an out-of-credit phrase or a 402 a passing limit instead:
  /// DashScope's `insufficient_quota` is a throughput throttle ("Allocated
  /// quota exceeded"), and OpenRouter's in-flight budget 402 carries a
  /// Retry-After.
  static const _transientLimitPhrases = [
    'throttling',
    'allocated quota exceeded',
    'openrouter_in_flight_budget',
  ];

  /// Whether [error] says the provider account is out of credit — a prepaid
  /// balance spent, a billing or spend limit reached, a payment overdue.
  ///
  /// Like a refused key, only the user can fix it (in the provider's
  /// billing page), so callers surface it and back off instead of retrying
  /// on a short timer. Typed exceptions are read by their status as well,
  /// and a [TranscriptionException] by its cause, which its `toString` leaves
  /// out.
  static bool isOutOfCredit(Object? error) {
    if (error == null) return false;
    final status = switch (error) {
      OpenAIClientException(:final code) => code,
      InferenceHttpException(:final statusCode) => statusCode,
      TranscriptionException(:final statusCode) => statusCode,
      _ => null,
    };
    final text = _textWithCause(error);
    final lower = text.toLowerCase();
    if (_transientLimitPhrases.any(lower.contains)) return false;
    return status == 402 ||
        _paymentRequiredStatus.hasMatch(text) ||
        _outOfCreditPhrases.any(lower.contains);
  }

  /// Whether [error] is a failure only the user can fix in their provider
  /// account or Settings — a refused key or an empty balance — so a
  /// background retry should back off rather than run on a short timer.
  static bool needsUserAction(Object? error) =>
      isAuthenticationFailure(error) || isOutOfCredit(error);

  /// The longest provider message [providerMessage] relays.
  static const providerMessageMaxLength = 300;

  /// The provider's own words about a failed call, for an on-device surface
  /// to relay — "Insufficient credits. Add more using …" — or null when
  /// [error] is no provider answer: a network failure, a timeout, or an
  /// error of the app's own, whose text is not the user's to read.
  static String? providerMessage(Object? error) {
    if (error == null) return null;
    // A transcription wrapper's own message can be generic; the provider's
    // words, when there are any, are in its cause.
    if (error is TranscriptionException) {
      final cause = providerMessage(error.originalError);
      if (cause != null) return cause;
    }
    switch (categorizeError(error).type) {
      case InferenceErrorType.networkConnection:
      case InferenceErrorType.timeout:
      case InferenceErrorType.unknown:
        return null;
      case InferenceErrorType.authentication:
      case InferenceErrorType.rateLimit:
      case InferenceErrorType.outOfCredit:
      case InferenceErrorType.invalidRequest:
      case InferenceErrorType.serverError:
        final message = extractDetailedErrorMessage(error).trim();
        return message.length <= providerMessageMaxLength
            ? message
            : '${message.substring(0, providerMessageMaxLength - 1)}…';
    }
  }

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
        if (errorBody is Map) {
          // Check for nested error.message structure (OpenAI format)
          if (errorBody.containsKey('error') && errorBody['error'] is Map) {
            final errorObj = errorBody['error'] as Map;
            if (errorObj.containsKey('message')) {
              detailContent = errorObj['message'];
              specificFieldWasAccessed = true;
            }
          } else if (errorBody.containsKey('detail')) {
            detailContent = errorBody['detail'];
            specificFieldWasAccessed = true;
          } else if (errorBody.containsKey('message')) {
            detailContent = errorBody['message'];
            specificFieldWasAccessed = true;
          }
        } else if (errorBody is String) {
          try {
            final decodedBody = jsonDecode(errorBody) as Map<String, dynamic>;
            // Check for nested error.message structure
            if (decodedBody.containsKey('error') &&
                decodedBody['error'] is Map) {
              final errorObj = decodedBody['error'] as Map;
              if (errorObj.containsKey('message')) {
                detailContent = errorObj['message'];
                specificFieldWasAccessed = true;
              }
            } else if (decodedBody.containsKey('detail')) {
              detailContent = decodedBody['detail'];
              specificFieldWasAccessed = true;
            } else if (decodedBody.containsKey('message')) {
              detailContent = decodedBody['message'];
              specificFieldWasAccessed = true;
            }
          } catch (_) {
            // JSON decoding failed, or not a map
          }
        }
      }

      // ElevenLabs nests its words one level down: `{"detail": {"message"}}`.
      if (detailContent is Map && detailContent['message'] != null) {
        detailContent = detailContent['message'];
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
  static InferenceError categorizeError(dynamic error) {
    // Handle null error
    if (error == null) {
      return InferenceError(
        message: 'An unknown error occurred',
        type: InferenceErrorType.unknown,
      );
    }

    // An empty account first: OpenAI reports it as a 429 and Anthropic as a
    // 400, which would otherwise read as a rate limit or a bad request. The
    // provider's own words say which account and how to top it up.
    if (isOutOfCredit(error)) {
      return InferenceError(
        message: extractDetailedErrorMessage(error),
        type: InferenceErrorType.outOfCredit,
        originalError: error,
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
      );
    }

    // Check for OpenAI-style API errors by examining the error structure
    // Note: We use string-based type checking here because the openai_dart package
    // doesn't expose specific exception types that we can check with 'is'.
    // This approach is brittle but necessary given the current library constraints.
    if (error.runtimeType.toString().contains('OpenAI') ||
        error.runtimeType.toString().contains('RequestException')) {
      return _handleApiError(error);
    }

    // Check for ModelNotInstalledException first (most specific)
    if (error is ModelNotInstalledException) {
      return InferenceError(
        message: error.toString(),
        type: InferenceErrorType.invalidRequest,
        originalError: error,
      );
    }

    // Check for 404 model not found errors (common with Ollama)
    final errorString = error.toString();
    if (errorString.contains('404') || errorString.contains('Not Found')) {
      final detailedMessage = extractDetailedErrorMessage(error);
      // Check if this is a model not found error
      if (detailedMessage.contains('not found') &&
          detailedMessage.contains('model')) {
        return InferenceError(
          message: detailedMessage,
          type: InferenceErrorType.invalidRequest,
          originalError: error,
        );
      }
    }

    // HTTP status code errors. A refused key first: Gemini's error text ends
    // in a "(429)" hint whatever its status, so a 400/403 bad-key error used
    // to be reported as a rate limit.
    if (isAuthenticationFailure(error) ||
        errorString.contains('401') ||
        errorString.contains('Unauthorized')) {
      return InferenceError(
        message: 'Authentication failed. Please check your API key.',
        type: InferenceErrorType.authentication,
        originalError: error,
      );
    }

    if (errorString.contains('429') || errorString.contains('Rate limit')) {
      return InferenceError(
        message:
            'Rate limit exceeded. Please wait before making more requests.',
        type: InferenceErrorType.rateLimit,
        originalError: error,
      );
    }

    if (errorString.contains('400') || errorString.contains('Bad Request')) {
      return InferenceError(
        message: extractDetailedErrorMessage(
          error,
          defaultMessage: 'Invalid request. Please check your configuration.',
        ),
        type: InferenceErrorType.invalidRequest,
        originalError: error,
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
      );
    }

    // Default to unknown error with extracted message
    return InferenceError(
      message: extractDetailedErrorMessage(error),
      type: InferenceErrorType.unknown,
      originalError: error,
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

  static InferenceError _handleApiError(dynamic error) {
    // Try to extract status code from error
    final errorString = error.toString();

    // Handle 404 errors (model not found, etc.)
    if (errorString.contains('404') || errorString.contains('Not Found')) {
      final detailedMessage = extractDetailedErrorMessage(error);
      // Check if this is a model not found error
      if (detailedMessage.contains('not found') &&
          detailedMessage.contains('model')) {
        return InferenceError(
          message: detailedMessage,
          type: InferenceErrorType.invalidRequest,
          originalError: error,
        );
      }
      return InferenceError(
        message: extractDetailedErrorMessage(
          error,
          defaultMessage: 'The requested resource was not found.',
        ),
        type: InferenceErrorType.invalidRequest,
        originalError: error,
      );
    }

    if (errorString.contains('401') || errorString.contains('Unauthorized')) {
      return InferenceError(
        message: 'Invalid API key. Please check your API key configuration.',
        type: InferenceErrorType.authentication,
        originalError: error,
      );
    }

    if (errorString.contains('429') || errorString.contains('Rate limit')) {
      return InferenceError(
        message:
            'Rate limit exceeded. Please wait before making more requests.',
        type: InferenceErrorType.rateLimit,
        originalError: error,
      );
    }

    if (errorString.contains('400') || errorString.contains('Bad Request')) {
      return InferenceError(
        message: extractDetailedErrorMessage(error),
        type: InferenceErrorType.invalidRequest,
        originalError: error,
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
      );
    }

    return InferenceError(
      message: extractDetailedErrorMessage(error),
      type: InferenceErrorType.unknown,
      originalError: error,
    );
  }
}
