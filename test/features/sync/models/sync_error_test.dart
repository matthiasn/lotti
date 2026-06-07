import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/sync/models/sync_error.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';
import '../../../mocks/mocks.dart';

void main() {
  late DomainLogger loggingService;

  setUp(() {
    loggingService = MockDomainLogger();
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

      test('logs the exception on the sync domain', () {
        final original = Exception('test error');
        final trace = StackTrace.current;

        SyncError.fromException(original, trace, loggingService);

        verify(
          () => loggingService.error(
            LogDomain.sync,
            original,
            stackTrace: trace,
            subDomain: 'SYNC_CONTROLLER',
          ),
        ).called(1);
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
  group('fromException classification properties', () {
    glados.Glados2(
      glados.AnyUtils(glados.any).choose(
        const ['database', 'network', 'connection', 'outbox', ''],
      ),
      glados.StringAnys(glados.any).stringOf('xyz '),
      glados.ExploreConfig(numRuns: 150),
    ).test(
      'keyword presence drives the type; absence falls back to unknown',
      (keyword, noise) {
        final loggingService = MockDomainLogger();
        // Surround the keyword with keyword-free noise so the property
        // sweeps arbitrary message shapes.
        final message = '$noise$keyword$noise';
        final error = SyncError.fromException(
          Exception(message),
          StackTrace.current,
          loggingService,
        );

        final expected = switch (keyword) {
          'database' => SyncErrorType.database,
          'network' || 'connection' => SyncErrorType.network,
          'outbox' => SyncErrorType.outbox,
          _ => SyncErrorType.unknown,
        };
        expect(error.type, expected, reason: 'message="$message"');
        // The user-facing message is exactly the canonical text for the
        // resolved type — never raw exception output.
        const friendly = {
          SyncErrorType.database:
              'Failed to access local data. '
              'Please try again.',
          SyncErrorType.network:
              'Network connection issue. '
              'Please check your internet connection.',
          SyncErrorType.outbox:
              'Failed to queue sync items. '
              'Please try again.',
          SyncErrorType.unknown:
              'An unexpected error occurred. '
              'Please try again.',
        };
        expect(error.message, friendly[error.type], reason: 'msg="$message"');
      },
      tags: 'glados',
    );
  });
}
