import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_error.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('InferenceError', () {
    test('creates instance with all parameters', () {
      final originalError = Exception('Original error');
      final stackTrace = StackTrace.current;

      final error = InferenceError(
        message: 'Test error message',
        type: InferenceErrorType.networkConnection,
        originalError: originalError,
        stackTrace: stackTrace,
      );

      expect(error.message, 'Test error message');
      expect(error.type, InferenceErrorType.networkConnection);
      expect(error.originalError, originalError);
      expect(error.stackTrace, stackTrace);
    });

    test('creates instance with required parameters only', () {
      final error = InferenceError(
        message: 'Test error message',
        type: InferenceErrorType.timeout,
      );

      expect(error.message, 'Test error message');
      expect(error.type, InferenceErrorType.timeout);
      expect(error.originalError, isNull);
      expect(error.stackTrace, isNull);
    });

    test('toString returns message', () {
      final error = InferenceError(
        message: 'Custom error message',
        type: InferenceErrorType.authentication,
      );

      expect(error.toString(), 'Custom error message');
    });
  });

  group('InferenceErrorType', () {
    test('has all expected enum values', () {
      expect(InferenceErrorType.values.length, 7);
      expect(InferenceErrorType.values,
          contains(InferenceErrorType.networkConnection));
      expect(InferenceErrorType.values, contains(InferenceErrorType.timeout));
      expect(InferenceErrorType.values,
          contains(InferenceErrorType.authentication));
      expect(InferenceErrorType.values, contains(InferenceErrorType.rateLimit));
      expect(InferenceErrorType.values,
          contains(InferenceErrorType.invalidRequest));
      expect(
          InferenceErrorType.values, contains(InferenceErrorType.serverError));
      expect(InferenceErrorType.values, contains(InferenceErrorType.unknown));
    });
  });

  group('InferenceErrorTypeExtension', () {
    group('title getter', () {
      test('returns correct non-localized titles', () {
        expect(InferenceErrorType.networkConnection.title, 'Connection Failed');
        expect(InferenceErrorType.timeout.title, 'Request Timed Out');
        expect(
            InferenceErrorType.authentication.title, 'Authentication Failed');
        expect(InferenceErrorType.rateLimit.title, 'Rate Limit Exceeded');
        expect(InferenceErrorType.invalidRequest.title, 'Invalid Request');
        expect(InferenceErrorType.serverError.title, 'Server Error');
        expect(InferenceErrorType.unknown.title, 'Error');
      });
    });

    group('defaultMessage getter', () {
      test('returns correct non-localized messages', () {
        expect(
          InferenceErrorType.networkConnection.defaultMessage,
          'Unable to connect to the AI service. Please check your internet connection and ensure the service is accessible.',
        );
        expect(
          InferenceErrorType.timeout.defaultMessage,
          'The request took too long to complete. Please try again or check if the service is responding.',
        );
        expect(
          InferenceErrorType.authentication.defaultMessage,
          'Authentication failed. Please check your API key and ensure it is valid.',
        );
        expect(
          InferenceErrorType.rateLimit.defaultMessage,
          'You have exceeded the rate limit. Please wait a moment before trying again.',
        );
        expect(
          InferenceErrorType.invalidRequest.defaultMessage,
          'The request was invalid. Please check your configuration and try again.',
        );
        expect(
          InferenceErrorType.serverError.defaultMessage,
          'The AI service encountered an error. Please try again later.',
        );
        expect(
          InferenceErrorType.unknown.defaultMessage,
          'An unexpected error occurred. Please try again.',
        );
      });
    });

    group('getTitle with BuildContext', () {
      testWidgets('returns correct localized titles',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (context) {
                // Test all error types
                for (final errorType in InferenceErrorType.values) {
                  final title = errorType.getTitle(context);
                  expect(title, isNotEmpty);

                  // Just verify it returns a non-empty string
                  // The actual content depends on localization
                }
                return const SizedBox();
              },
            ),
          ),
        );
      });
    });

    group('getDefaultMessage with BuildContext', () {
      testWidgets('returns correct localized messages',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (context) {
                // Test all error types
                for (final errorType in InferenceErrorType.values) {
                  final message = errorType.getDefaultMessage(context);
                  expect(message, isNotEmpty);

                  // Just verify it returns a non-empty string
                  // The actual content depends on localization
                }
                return const SizedBox();
              },
            ),
          ),
        );
      });
    });
  });
}
