import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/inference_error.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

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
    test('exposes exactly the known error types', () {
      // Assert membership both ways: every expected value is present and no
      // unexpected value has crept in. This fails with a useful message
      // (which value was added/removed) instead of a bare count mismatch.
      const expected = {
        InferenceErrorType.networkConnection,
        InferenceErrorType.timeout,
        InferenceErrorType.authentication,
        InferenceErrorType.rateLimit,
        InferenceErrorType.invalidRequest,
        InferenceErrorType.serverError,
        InferenceErrorType.unknown,
      };

      expect(InferenceErrorType.values.toSet(), expected);
    });
  });

  group('InferenceErrorTypeExtension', () {
    group('getTitle with BuildContext', () {
      testWidgets('returns correct localized titles', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(
          makeTestableWidget(
            Builder(
              builder: (context) {
                // Pin each switch arm to its exact localized message —
                // a miswired arm cannot hide behind an isNotEmpty check.
                final expected = <InferenceErrorType, String>{
                  InferenceErrorType.networkConnection:
                      context.messages.aiInferenceErrorConnectionFailedTitle,
                  InferenceErrorType.timeout:
                      context.messages.aiInferenceErrorTimeoutTitle,
                  InferenceErrorType.authentication:
                      context.messages.aiInferenceErrorAuthenticationTitle,
                  InferenceErrorType.rateLimit:
                      context.messages.aiInferenceErrorRateLimitTitle,
                  InferenceErrorType.invalidRequest:
                      context.messages.aiInferenceErrorInvalidRequestTitle,
                  InferenceErrorType.serverError:
                      context.messages.aiInferenceErrorServerTitle,
                  InferenceErrorType.unknown:
                      context.messages.aiInferenceErrorUnknownTitle,
                };
                expect(expected.keys, InferenceErrorType.values);
                for (final errorType in InferenceErrorType.values) {
                  expect(
                    errorType.getTitle(context),
                    expected[errorType],
                    reason: '$errorType',
                  );
                }
                // All titles are distinct — no two arms share a message.
                expect(
                  expected.values.toSet(),
                  hasLength(InferenceErrorType.values.length),
                );
                return const SizedBox();
              },
            ),
          ),
        );
      });
    });
  });
}
