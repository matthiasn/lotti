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
    test('constructor sets the user-facing message', () {
      final error = SyncError(message: 'Test message');

      expect(error.message, 'Test message');
    });

    test('toString returns message', () {
      final error = SyncError(message: 'Connection lost');

      expect(error.toString(), 'Connection lost');
    });

    group('fromException', () {
      test('detects database error type', () {
        final error = SyncError.fromException(
          Exception('database error occurred'),
          StackTrace.current,
          loggingService,
        );

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

        expect(
          error.message,
          'Network connection issue. Please check your internet connection.',
        );
      });

      test('detects outbox error type', () {
        final error = SyncError.fromException(
          Exception('outbox queue full'),
          StackTrace.current,
          loggingService,
        );

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
          'database' => 'Failed to access local data. Please try again.',
          'network' || 'connection' =>
            'Network connection issue. Please check your internet connection.',
          'outbox' => 'Failed to queue sync items. Please try again.',
          _ => 'An unexpected error occurred. Please try again.',
        };
        expect(error.message, expected, reason: 'msg="$message"');
      },
      tags: 'glados',
    );
  });
}
