import 'dart:convert';

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
}
