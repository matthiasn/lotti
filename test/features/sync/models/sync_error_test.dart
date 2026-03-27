import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/models/sync_error.dart';
import 'package:lotti/services/logging_service.dart';

void main() {
  late LoggingService loggingService;

  setUp(() {
    loggingService = LoggingService();
  });

  group('SyncErrorType', () {
    test('has expected values', () {
      expect(SyncErrorType.values, hasLength(4));
      expect(
        SyncErrorType.values,
        containsAll([
          SyncErrorType.database,
          SyncErrorType.network,
          SyncErrorType.outbox,
          SyncErrorType.unknown,
        ]),
      );
    });
  });

  group('SyncError', () {
    test('constructor sets all fields', () {
      final error = SyncError(
        type: SyncErrorType.database,
        message: 'Test message',
        originalError: Exception('original'),
        stackTrace: StackTrace.current,
      );

      expect(error.type, SyncErrorType.database);
      expect(error.message, 'Test message');
      expect(error.originalError, isA<Exception>());
      expect(error.stackTrace, isNotNull);
    });

    test('toString returns message', () {
      final error = SyncError(
        type: SyncErrorType.network,
        message: 'Connection lost',
      );

      expect(error.toString(), 'Connection lost');
    });

    group('fromException', () {
      test('detects database error type', () {
        final error = SyncError.fromException(
          Exception('database error occurred'),
          StackTrace.current,
          loggingService,
        );

        expect(error.type, SyncErrorType.database);
        expect(
          error.message,
          'Failed to access local data. Please try again.',
        );
      });

      test('detects network error type', () {
        final error = SyncError.fromException(
          Exception('network timeout'),
          StackTrace.current,
          loggingService,
        );

        expect(error.type, SyncErrorType.network);
        expect(
          error.message,
          'Network connection issue. Please check your internet connection.',
        );
      });

      test('detects connection error type', () {
        final error = SyncError.fromException(
          Exception('connection refused'),
          StackTrace.current,
          loggingService,
        );

        expect(error.type, SyncErrorType.network);
      });

      test('detects outbox error type', () {
        final error = SyncError.fromException(
          Exception('outbox queue full'),
          StackTrace.current,
          loggingService,
        );

        expect(error.type, SyncErrorType.outbox);
        expect(
          error.message,
          'Failed to queue sync items. Please try again.',
        );
      });

      test('falls back to unknown for unrecognized errors', () {
        final error = SyncError.fromException(
          Exception('something weird happened'),
          StackTrace.current,
          loggingService,
        );

        expect(error.type, SyncErrorType.unknown);
        expect(
          error.message,
          'An unexpected error occurred. Please try again.',
        );
      });

      test('logs the exception via logging service without error', () {
        // LoggingService is a no-op in test env, but we verify it does not throw
        SyncError.fromException(
          Exception('test error'),
          StackTrace.current,
          loggingService,
        );
      });

      test('uses custom domain without error', () {
        SyncError.fromException(
          Exception('test error'),
          StackTrace.current,
          loggingService,
          domain: 'CUSTOM_DOMAIN',
        );
      });

      test('preserves original error', () {
        final originalError = Exception('database failure');
        final error = SyncError.fromException(
          originalError,
          StackTrace.current,
          loggingService,
        );

        expect(error.originalError, originalError);
      });

      test('preserves stack trace', () {
        final stackTrace = StackTrace.current;
        final error = SyncError.fromException(
          Exception('test'),
          stackTrace,
          loggingService,
        );

        expect(error.stackTrace, stackTrace);
      });
    });
  });
}
