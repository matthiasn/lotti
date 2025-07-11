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
  });
}
