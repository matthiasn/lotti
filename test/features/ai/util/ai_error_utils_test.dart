import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_error.dart';
import 'package:lotti/features/ai/util/ai_error_utils.dart';

// A generic error class that might have a body or message
class TestErrorWithMessage {
  TestErrorWithMessage({this.message});
  final String? message;

  @override
  String toString() => 'TestErrorWithMessage: ${message ?? "No message"}';
}

// An error class that might have a body which could be a Map or a JSON String
class TestErrorWithBody {
  TestErrorWithBody({this.body});
  final dynamic body;

  @override
  String toString() => 'TestErrorWithBody: ${body?.toString() ?? "No body"}';
}

// A simple custom error class
class CustomError {
  CustomError(this.customInfo);
  final String customInfo;

  @override
  String toString() => 'CustomError: $customInfo';
}

// Helper for the prioritization test
class TestErrorWithBodyAndMessage {
  TestErrorWithBodyAndMessage({this.body, this.message});
  final dynamic body;
  final String? message;

  @override
  String toString() => 'TestErrorWithBodyAndMessage';
}

// Helper for testing error.toString() that returns literal "null"
class TestErrorToStringReturnsLiteralNull {
  @override
  String toString() => 'null';
}

// Helper for testing error.toString() that returns an empty string
class TestErrorToStringReturnsEmpty {
  @override
  String toString() => '  '; // Whitespace
}

void main() {
  group('AiErrorUtils', () {
    group('categorizeError', () {
      test('categorizes SocketException as network connection error', () {
        const error = SocketException('Failed to connect');
        final result = AiErrorUtils.categorizeError(error);

        expect(result.type, InferenceErrorType.networkConnection);
        expect(result.message, contains('Unable to connect'));
      });

      test('categorizes "Failed host lookup" as network connection error', () {
        const error = 'SocketException: Failed host lookup: api.example.com';
        final result = AiErrorUtils.categorizeError(error);

        expect(result.type, InferenceErrorType.networkConnection);
        expect(
            result.message, contains('Unable to resolve the server address'));
      });

      test('categorizes "Connection refused" as network connection error', () {
        const error = 'Connection refused';
        final result = AiErrorUtils.categorizeError(error);

        expect(result.type, InferenceErrorType.networkConnection);
        expect(result.message, contains('Connection refused'));
      });

      test('categorizes timeout errors correctly', () {
        const error = 'TimeoutException: Request timed out';
        final result = AiErrorUtils.categorizeError(error);

        expect(result.type, InferenceErrorType.timeout);
        expect(result.message, contains('timed out'));
      });

      test('categorizes 401 errors as authentication errors', () {
        const error = 'HTTP 401 Unauthorized';
        final result = AiErrorUtils.categorizeError(error);

        expect(result.type, InferenceErrorType.authentication);
        expect(result.message, contains('Authentication failed'));
      });

      test('categorizes 429 errors as rate limit errors', () {
        const error = 'HTTP 429 Rate limit exceeded';
        final result = AiErrorUtils.categorizeError(error);

        expect(result.type, InferenceErrorType.rateLimit);
        expect(result.message, contains('Rate limit exceeded'));
      });

      test('categorizes 400 errors as invalid request errors', () {
        const error = 'HTTP 400 Bad Request';
        final result = AiErrorUtils.categorizeError(error);

        expect(result.type, InferenceErrorType.invalidRequest);
        expect(result.message, contains('HTTP 400 Bad Request'));
      });

      test('categorizes 500 errors as server errors', () {
        const error = 'HTTP 500 Internal Server Error';
        final result = AiErrorUtils.categorizeError(error);

        expect(result.type, InferenceErrorType.serverError);
        expect(
            result.message, contains('The AI service is experiencing issues'));
      });

      test('categorizes 502 errors as server errors', () {
        const error = 'HTTP 502 Bad Gateway';
        final result = AiErrorUtils.categorizeError(error);

        expect(result.type, InferenceErrorType.serverError);
        expect(
            result.message, contains('The AI service is experiencing issues'));
      });

      test('categorizes 503 errors as server errors', () {
        const error = 'HTTP 503 Service Unavailable';
        final result = AiErrorUtils.categorizeError(error);

        expect(result.type, InferenceErrorType.serverError);
        expect(
            result.message, contains('The AI service is experiencing issues'));
      });

      test('categorizes unknown errors correctly', () {
        const error = 'Some random error';
        final result = AiErrorUtils.categorizeError(error);

        expect(result.type, InferenceErrorType.unknown);
        expect(result.message, 'Some random error');
      });

      test('handles null errors', () {
        final result = AiErrorUtils.categorizeError(null);

        expect(result.type, InferenceErrorType.unknown);
        expect(result.message, 'An unknown error occurred');
      });

      test('handles API errors with 401 status code', () {
        const error = 'RequestException: 401 Unauthorized';

        final result = AiErrorUtils.categorizeError(error);

        expect(result.type, InferenceErrorType.authentication);
        expect(result.message, contains('Authentication failed'));
      });

      test('preserves stack trace when provided', () {
        const error = 'Test error';
        final stackTrace = StackTrace.current;
        final result =
            AiErrorUtils.categorizeError(error, stackTrace: stackTrace);

        expect(result.stackTrace, stackTrace);
      });

      test('preserves original error', () {
        const error = 'Test error';
        final result = AiErrorUtils.categorizeError(error);

        expect(result.originalError, error);
      });

      test('handles Ollama model not found error', () {
        const error = '''
OpenAIClientException({
  "uri": "http://localhost:11434/v1/chat/completions",
  "method": "POST",
  "code": 404,
  "message": "Unsuccessful response",
  "body": {
    "error": {
      "message": "model "gemma3:12b-it-qat" not found, try pulling it first",
      "type": "api_error",
      "param": null,
      "code": null
    }
  }
})''';

        final result = AiErrorUtils.categorizeError(error);

        expect(result.type, InferenceErrorType.invalidRequest);
        expect(result.message, contains('model "gemma3:12b-it-qat" not found'));
        expect(result.message, contains('try pulling it first'));
      });

      test('handles generic model not found error', () {
        const error = '''
OpenAIClientException({
  "uri": "https://api.openai.com/v1/chat/completions",
  "method": "POST",
  "code": 404,
  "message": "Not Found",
  "body": {
    "error": {
      "message": "The model gpt-5 not found"
    }
  }
})''';

        final result = AiErrorUtils.categorizeError(error);

        expect(result.type, InferenceErrorType.invalidRequest);
        expect(result.message, contains('The model gpt-5 not found'));
      });
    });

    group('extractDetailedErrorMessage', () {
      test('extracts detail from error.body.detail where body is a Map', () {
        final error =
            TestErrorWithBody(body: {'detail': 'Detailed error from map body'});
        expect(
          AiErrorUtils.extractDetailedErrorMessage(error),
          equals('Detailed error from map body'),
        );
      });

      test(
          'extracts detail from error.body.detail where detail is not a string',
          () {
        final error = TestErrorWithBody(body: {'detail': 12345});
        expect(
          AiErrorUtils.extractDetailedErrorMessage(error),
          equals('12345'), // Should be stringified
        );
      });

      test('extracts detail from error.body where body is a JSON string', () {
        final error = TestErrorWithBody(
          body: '{"detail": "Detailed error from JSON string"}',
        );
        expect(
          AiErrorUtils.extractDetailedErrorMessage(error),
          equals('Detailed error from JSON string'),
        );
      });

      test('extracts message from nested error.message structure', () {
        final error = TestErrorWithBody(
          body: {
            'error': {
              'message': 'model "llama2" not found, try pulling it first',
              'type': 'api_error',
            },
          },
        );
        expect(
          AiErrorUtils.extractDetailedErrorMessage(error),
          equals('model "llama2" not found, try pulling it first'),
        );
      });

      test('extracts message from nested error structure in JSON string', () {
        final error = TestErrorWithBody(
          body:
              '{"error": {"message": "Model not available", "code": "model_not_found"}}',
        );
        expect(
          AiErrorUtils.extractDetailedErrorMessage(error),
          equals('Model not available'),
        );
      });

      test('extracts message from error.message if body.detail is not present',
          () {
        final error = TestErrorWithMessage(message: 'Error message property');
        expect(
          AiErrorUtils.extractDetailedErrorMessage(error),
          equals('Error message property'),
        );
      });

      test('uses error.toString() if no body.detail or message is present', () {
        final error = CustomError('Custom info for toString');
        expect(
          AiErrorUtils.extractDetailedErrorMessage(error),
          equals('CustomError: Custom info for toString'),
        );
      });

      test(
          'uses defaultMessage if provided and no specific field is found on error, but error.toString() is still preferred if error is not null',
          () {
        final error = CustomError('Custom info for toString');
        // If the error object itself is not null, its toString() representation will be used
        // if no .body.detail or .message is found. The defaultMessage is a fallback for when error is null
        // or when the extracted message ends up being empty or literally "null".
        expect(
          AiErrorUtils.extractDetailedErrorMessage(
            error,
            defaultMessage: 'Provided default',
          ),
          equals(
            'CustomError: Custom info for toString',
          ), // error.toString() is preferred over defaultMessage here
        );

        // Test case where defaultMessage IS used because error itself might be problematic to stringify (e.g. null)
        // This is covered by the 'handles null input for error gracefully using defaultMessage' test.
        // Adding another scenario: if extracted detail/message is empty.
        final errorWithEmptyDetail = TestErrorWithBody(body: {'detail': ''});
        expect(
          AiErrorUtils.extractDetailedErrorMessage(
            errorWithEmptyDetail,
            defaultMessage: 'Used Default Because Extracted Was Empty',
          ),
          equals('Used Default Because Extracted Was Empty'),
        );
      });

      test(
          'handles error.body being a Map without a "detail" key (falls back to message or toString)',
          () {
        final error = TestErrorWithBody(body: {'other_key': 'some value'});
        expect(
          AiErrorUtils.extractDetailedErrorMessage(error),
          equals(
            'TestErrorWithBody: {other_key: some value}',
          ), // Falls back to toString of error
        );
      });

      test(
          'handles error.body being an unparsable JSON string (falls back to message or toString)',
          () {
        final error = TestErrorWithBody(body: 'not a json string');
        expect(
          AiErrorUtils.extractDetailedErrorMessage(error),
          equals(
            'TestErrorWithBody: not a json string',
          ), // Falls back to toString of error
        );
      });

      test('handles error.body being null (falls back to message or toString)',
          () {
        final error = TestErrorWithBody();
        expect(
          AiErrorUtils.extractDetailedErrorMessage(error),
          equals(
              'TestErrorWithBody: No body'), // Falls back to toString of error
        );
      });

      test('handles error.message being null (falls back to toString)', () {
        final error = TestErrorWithMessage();
        expect(
          AiErrorUtils.extractDetailedErrorMessage(error),
          equals(
            'TestErrorWithMessage: No message',
          ), // Falls back to toString of error
        );
      });

      test(
          'handles empty string in body.detail, falls back to message or toString if logic allows (current is empty string)',
          () {
        final error = TestErrorWithBody(body: {'detail': ''});
        // Current implementation will return empty string if detail is empty. Then trim check makes it use default/toString()
        expect(
          AiErrorUtils.extractDetailedErrorMessage(
            error,
            defaultMessage: 'Fallback',
          ),
          equals('Fallback'),
        );
      });

      test(
          'handles empty string in error.message, falls back to toString if logic allows (current is empty string)',
          () {
        final error = TestErrorWithMessage(message: '');
        expect(
          AiErrorUtils.extractDetailedErrorMessage(
            error,
            defaultMessage: 'Fallback',
          ),
          equals('Fallback'),
        );
      });

      test('handles input error being a simple string', () {
        const errorString = 'This is a simple string error';
        expect(
          AiErrorUtils.extractDetailedErrorMessage(errorString),
          equals(errorString),
        );
      });

      test('prioritizes body.detail over message', () {
        // final error = { // This variable is unused
        //   'body': {'detail': 'Detail is king'},
        //   'message': 'Message is secondary'
        // };
        // For simplicity, using a helper that mimics the dynamic access
        // In a real scenario, this would be an instance of a specific error class from a library
        final dynamicError = TestErrorWithBodyAndMessage(
          body: {'detail': 'Detail is king'},
          message: 'Message is secondary',
        );

        expect(
          AiErrorUtils.extractDetailedErrorMessage(dynamicError),
          equals('Detail is king'),
        );
      });

      test('prioritizes message over toString if body.detail is not present',
          () {
        final error = TestErrorWithMessage(message: 'Use this message');
        // toString() for TestErrorWithMessage would be 'TestErrorWithMessage: Use this message'
        expect(
          AiErrorUtils.extractDetailedErrorMessage(error),
          equals('Use this message'),
        );
      });

      test('handles null input for error gracefully using defaultMessage', () {
        expect(
          AiErrorUtils.extractDetailedErrorMessage(
            null,
            defaultMessage: 'Null error occurred',
          ),
          equals('Null error occurred'),
        );
      });

      test('handles null input for error gracefully when no defaultMessage',
          () {
        // Expect the specific string returned by the utility for a null error without a default.
        expect(
          AiErrorUtils.extractDetailedErrorMessage(
            null,
          ), // No defaultMessage provided
          equals('Unknown error (null object)'),
        );
      });

      test(
          "if extracted message is literally 'null' or empty, uses defaultMessage or error.toString()",
          () {
        final errorWithNullDetail = TestErrorWithBody(
          body: {'detail': null},
        ); // detail field exists but is null
        expect(
          AiErrorUtils.extractDetailedErrorMessage(
            errorWithNullDetail,
            defaultMessage: 'Fallback for null detail',
          ),
          equals(
            'Fallback for null detail',
          ), // 'detail' was accessed, was null, so extractedMessage became "null", then fallback
        );

        final errorWithEmptyDetailString =
            TestErrorWithBody(body: {'detail': '  '}); // Whitespace only
        expect(
          AiErrorUtils.extractDetailedErrorMessage(
            errorWithEmptyDetailString,
            defaultMessage: 'Fallback for empty detail',
          ),
          equals(
            'Fallback for empty detail',
          ), // 'detail' was accessed, was empty, then fallback
        );

        final errorWithMessageAsNull =
            TestErrorWithMessage(); // message field exists but is effectively null by default
        expect(
          AiErrorUtils.extractDetailedErrorMessage(
            errorWithMessageAsNull,
            defaultMessage: 'Fallback for null message',
          ),
          equals(
            'Fallback for null message',
          ), // 'message' was accessed, was null, so extractedMessage became "null", then fallback
        );

        final errorWithEmptyMessageString = TestErrorWithMessage(
          message: '  ',
        ); // message field exists, is whitespace
        expect(
          AiErrorUtils.extractDetailedErrorMessage(
            errorWithEmptyMessageString,
            defaultMessage: 'Fallback for empty message',
          ),
          equals(
            'Fallback for empty message',
          ), // 'message' was accessed, was empty, then fallback
        );

        // Case: No specific field, error.toString() itself results in "null"
        // This test simulates if error.toString() was literally the string "null"
        final errorToStringIsNullLiteral =
            TestErrorToStringReturnsLiteralNull();
        expect(
          AiErrorUtils.extractDetailedErrorMessage(
            errorToStringIsNullLiteral,
            defaultMessage: 'Fallback for toString as literal null',
          ),
          equals('Fallback for toString as literal null'),
        );

        // Case: No specific field, error.toString() itself results in an empty string
        final errorToStringIsEmptyLiteral = TestErrorToStringReturnsEmpty();
        expect(
          AiErrorUtils.extractDetailedErrorMessage(
            errorToStringIsEmptyLiteral,
            defaultMessage: 'Fallback for toString as empty literal',
          ),
          equals('Fallback for toString as empty literal'),
        );

        // Case: No specific field, error.toString() is a non-empty, non-"null" string that happens to contain "null"
        final errorToStringContainsNull = CustomError(
          'null',
        ); // Simulates error.toString() returning "CustomError: null"
        expect(
          AiErrorUtils.extractDetailedErrorMessage(
            errorToStringContainsNull,
            defaultMessage: 'This default should not be used',
          ),
          equals(
            'CustomError: null',
          ), // Utility should return the actual toString() if it's not literally "null" or empty
        );
      });
    });
  });
}
