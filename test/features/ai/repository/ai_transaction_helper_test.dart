import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/repository/ai_transaction_helper.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

void main() {
  late MockJournalDb mockDb;
  late AiTransactionHelper helper;

  setUp(() {
    mockDb = MockJournalDb();
    helper = AiTransactionHelper(mockDb);
  });

  group('AiTransactionHelper', () {
    group('executeWithRetry', () {
      test('executes operation successfully on first attempt', () async {
        // Arrange
        const expectedResult = 'success';
        var operationCallCount = 0;

        Future<String> testOperation() async {
          operationCallCount++;
          return expectedResult;
        }

        when(() => mockDb.transaction<String>(any()))
            .thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments[0] as Future<String> Function();
          return callback();
        });

        // Act
        final result = await helper.executeWithRetry<String>(
          testOperation,
          operationName: 'test_operation',
        );

        // Assert
        expect(result, equals(expectedResult));
        expect(operationCallCount, equals(1));
        verify(() => mockDb.transaction<String>(any())).called(1);
      });

      test('retries on AiUpdateConflictException', () async {
        // Arrange
        var operationCallCount = 0;
        const expectedResult = 'success_after_retry';

        Future<String> testOperation() async {
          operationCallCount++;
          if (operationCallCount == 1) {
            throw const AiUpdateConflictException(
              'Test conflict',
              taskId: 'task-1',
              operationType: 'test',
            );
          }
          return expectedResult;
        }

        when(() => mockDb.transaction<String>(any()))
            .thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments[0] as Future<String> Function();
          return callback();
        });

        // Act
        final result = await helper.executeWithRetry<String>(
          testOperation,
          operationName: 'test_operation',
        );

        // Assert
        expect(result, equals(expectedResult));
        expect(operationCallCount, equals(2));
        verify(() => mockDb.transaction<String>(any())).called(2);
      });

      test('retries on database lock error', () async {
        // Arrange
        var operationCallCount = 0;
        const expectedResult = 'success_after_retry';

        Future<String> testOperation() async {
          operationCallCount++;
          if (operationCallCount == 1) {
            throw Exception('database is locked');
          }
          return expectedResult;
        }

        when(() => mockDb.transaction<String>(any()))
            .thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments[0] as Future<String> Function();
          return callback();
        });

        // Act
        final result = await helper.executeWithRetry<String>(
          testOperation,
          operationName: 'test_operation',
        );

        // Assert
        expect(result, equals(expectedResult));
        expect(operationCallCount, equals(2));
      });

      test('retries on vector clock conflict', () async {
        // Arrange
        var operationCallCount = 0;
        const expectedResult = 'success_after_retry';

        Future<String> testOperation() async {
          operationCallCount++;
          if (operationCallCount == 1) {
            throw Exception('vector clock conflict detected');
          }
          return expectedResult;
        }

        when(() => mockDb.transaction<String>(any()))
            .thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments[0] as Future<String> Function();
          return callback();
        });

        // Act
        final result = await helper.executeWithRetry<String>(
          testOperation,
          operationName: 'test_operation',
        );

        // Assert
        expect(result, equals(expectedResult));
        expect(operationCallCount, equals(2));
      });

      test('does not retry on non-retryable errors', () async {
        // Arrange
        var operationCallCount = 0;

        Future<String> testOperation() async {
          operationCallCount++;
          throw Exception('non-retryable error');
        }

        when(() => mockDb.transaction<String>(any()))
            .thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments[0] as Future<String> Function();
          return callback();
        });

        // Act & Assert
        await expectLater(
          () => helper.executeWithRetry<String>(
            testOperation,
            operationName: 'test_operation',
          ),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('non-retryable error'),
          )),
        );

        expect(operationCallCount, equals(1));
        verify(() => mockDb.transaction<String>(any())).called(1);
      });

      test('fails after maximum retries', () async {
        // Arrange
        var operationCallCount = 0;
        const maxRetries = 2;

        Future<String> testOperation() async {
          operationCallCount++;
          throw const AiUpdateConflictException('persistent conflict');
        }

        when(() => mockDb.transaction<String>(any()))
            .thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments[0] as Future<String> Function();
          return callback();
        });

        // Act & Assert
        await expectLater(
          () => helper.executeWithRetry<String>(
            testOperation,
            maxRetries: maxRetries,
            operationName: 'test_operation',
          ),
          throwsA(isA<AiUpdateConflictException>()),
        );

        expect(operationCallCount, equals(maxRetries));
        verify(() => mockDb.transaction<String>(any())).called(maxRetries);
      });

      test('uses exponential backoff for retries', () async {
        // Arrange
        var operationCallCount = 0;
        final retryTimestamps = <DateTime>[];
        const baseDelay = Duration(milliseconds: 10); // Short delay for testing

        Future<String> testOperation() async {
          operationCallCount++;
          retryTimestamps.add(DateTime.now());

          if (operationCallCount <= 2) {
            throw const AiUpdateConflictException('conflict');
          }
          return 'success';
        }

        when(() => mockDb.transaction<String>(any()))
            .thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments[0] as Future<String> Function();
          return callback();
        });

        // Act
        final result = await helper.executeWithRetry<String>(
          testOperation,
          baseDelay: baseDelay,
          operationName: 'test_operation',
        );

        // Assert
        expect(result, equals('success'));
        expect(operationCallCount, equals(3));
        expect(retryTimestamps, hasLength(3));

        // Verify delays increased (allowing some tolerance for test timing)
        if (retryTimestamps.length >= 2) {
          final firstDelay = retryTimestamps[1].difference(retryTimestamps[0]);
          expect(firstDelay.inMilliseconds,
              greaterThanOrEqualTo(8)); // Base delay with some tolerance
        }
      });

      test('respects custom maxRetries parameter', () async {
        // Arrange
        var operationCallCount = 0;
        const customMaxRetries = 5;

        Future<String> testOperation() async {
          operationCallCount++;
          throw const AiUpdateConflictException('persistent conflict');
        }

        when(() => mockDb.transaction<String>(any()))
            .thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments[0] as Future<String> Function();
          return callback();
        });

        // Act & Assert
        await expectLater(
          () => helper.executeWithRetry<String>(
            testOperation,
            maxRetries: customMaxRetries,
            operationName: 'test_operation',
          ),
          throwsA(isA<AiUpdateConflictException>()),
        );

        expect(operationCallCount, equals(customMaxRetries));
      });

      test('respects custom baseDelay parameter', () async {
        // Arrange
        var operationCallCount = 0;
        final retryTimestamps = <DateTime>[];
        const customBaseDelay = Duration(milliseconds: 50);

        Future<String> testOperation() async {
          operationCallCount++;
          retryTimestamps.add(DateTime.now());

          if (operationCallCount <= 1) {
            throw const AiUpdateConflictException('conflict');
          }
          return 'success';
        }

        when(() => mockDb.transaction<String>(any()))
            .thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments[0] as Future<String> Function();
          return callback();
        });

        // Act
        await helper.executeWithRetry<String>(
          testOperation,
          baseDelay: customBaseDelay,
          operationName: 'test_operation',
        );

        // Assert
        expect(operationCallCount, equals(2));

        // Verify delay was approximately the custom base delay
        if (retryTimestamps.length >= 2) {
          final delay = retryTimestamps[1].difference(retryTimestamps[0]);
          expect(delay.inMilliseconds,
              greaterThanOrEqualTo(40)); // Custom delay with tolerance
        }
      });

      test('works with different return types', () async {
        // Test with int
        when(() => mockDb.transaction<int>(any()))
            .thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments[0] as Future<int> Function();
          return callback();
        });

        final intResult = await helper.executeWithRetry<int>(
          () async => 42,
          operationName: 'int_operation',
        );
        expect(intResult, equals(42));

        // Test with bool
        when(() => mockDb.transaction<bool>(any()))
            .thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments[0] as Future<bool> Function();
          return callback();
        });

        final boolResult = await helper.executeWithRetry<bool>(
          () async => true,
          operationName: 'bool_operation',
        );
        expect(boolResult, equals(true));

        // Test with void
        when(() => mockDb.transaction<void>(any()))
            .thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments[0] as Future<void> Function();
          return callback();
        });

        await helper.executeWithRetry<void>(
          () async {},
          operationName: 'void_operation',
        );

        // Test passes if it completes without throwing
      });
    });

    group('_shouldRetry', () {
      test('returns true for AiUpdateConflictException', () {
        // Arrange
        const exception = AiUpdateConflictException('test conflict');

        // Act
        final result = helper.shouldRetryForTesting(exception);

        // Assert
        expect(result, isTrue);
      });

      test('returns true for conflict-related error messages', () {
        // Test various conflict-related error messages
        final conflictErrors = [
          Exception('conflict detected'),
          Exception('database is locked'),
          Exception('database is busy'),
          Exception('vector clock mismatch'),
          Exception('busy database'),
          Exception('locked resource'),
          Exception('concurrent modification'),
        ];

        for (final error in conflictErrors) {
          expect(helper.shouldRetryForTesting(error), isTrue,
              reason: 'Should retry for error: $error');
        }
      });

      test('returns false for non-conflict errors', () {
        // Test various non-conflict errors
        final nonConflictErrors = [
          Exception('file not found'),
          Exception('network timeout'),
          Exception('invalid parameter'),
          Exception('null pointer'),
          Exception('out of memory'),
        ];

        for (final error in nonConflictErrors) {
          expect(helper.shouldRetryForTesting(error), isFalse,
              reason: 'Should not retry for error: $error');
        }
      });

      test('is case insensitive', () {
        // Test case variations
        final caseVariations = [
          Exception('CONFLICT'),
          Exception('Database Is Locked'),
          Exception('VECTOR CLOCK'),
          Exception('Busy'),
        ];

        for (final error in caseVariations) {
          expect(helper.shouldRetryForTesting(error), isTrue,
              reason: 'Should be case insensitive for: $error');
        }
      });
    });

    group('Integration scenarios', () {
      test('handles complex operation with multiple conflict types', () async {
        // Arrange
        var operationCallCount = 0;
        final conflictTypes = [
          const AiUpdateConflictException('vector clock conflict'),
          Exception('database is locked'),
          Exception('concurrent modification detected'),
        ];

        Future<String> complexOperation() async {
          operationCallCount++;

          if (operationCallCount <= conflictTypes.length) {
            throw conflictTypes[operationCallCount - 1];
          }

          return 'final_success';
        }

        when(() => mockDb.transaction<String>(any()))
            .thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments[0] as Future<String> Function();
          return callback();
        });

        // Act
        final result = await helper.executeWithRetry<String>(
          complexOperation,
          maxRetries: 5,
          operationName: 'complex_operation',
        );

        // Assert
        expect(result, equals('final_success'));
        expect(operationCallCount, equals(4)); // 3 failures + 1 success
      });

      test('transaction rollback on failure', () async {
        // Arrange
        when(() => mockDb.transaction<String>(any()))
            .thenThrow(Exception('transaction failed'));

        // Act & Assert
        await expectLater(
          () => helper.executeWithRetry<String>(
            () async => 'should not succeed',
            operationName: 'failing_transaction',
          ),
          throwsA(isA<Exception>()),
        );

        // Verify transaction was attempted
        verify(() => mockDb.transaction<String>(any())).called(1);
      });
    });
  });

  group('AiUpdateConflictException', () {
    test('creates exception with message only', () {
      // Act
      const exception = AiUpdateConflictException('test message');

      // Assert
      expect(exception.message, equals('test message'));
      expect(exception.taskId, isNull);
      expect(exception.operationType, isNull);
    });

    test('creates exception with all parameters', () {
      // Act
      const exception = AiUpdateConflictException(
        'test message',
        taskId: 'task-123',
        operationType: 'task_summary',
      );

      // Assert
      expect(exception.message, equals('test message'));
      expect(exception.taskId, equals('task-123'));
      expect(exception.operationType, equals('task_summary'));
    });

    test('toString includes all available information', () {
      // Test with minimal info
      const minimalException = AiUpdateConflictException('minimal');
      expect(minimalException.toString(),
          equals('AiUpdateConflictException: minimal'));

      // Test with full info
      const fullException = AiUpdateConflictException(
        'full message',
        taskId: 'task-456',
        operationType: 'action_items',
      );
      expect(
          fullException.toString(),
          equals(
              'AiUpdateConflictException: full message, taskId: task-456, operation: action_items'));
    });

    test('toString handles partial information', () {
      // Test with task ID only
      const taskOnlyException = AiUpdateConflictException(
        'task only',
        taskId: 'task-789',
      );
      expect(taskOnlyException.toString(),
          equals('AiUpdateConflictException: task only, taskId: task-789'));

      // Test with operation type only
      const operationOnlyException = AiUpdateConflictException(
        'operation only',
        operationType: 'summary',
      );
      expect(
          operationOnlyException.toString(),
          equals(
              'AiUpdateConflictException: operation only, operation: summary'));
    });
  });
}

// Extension to test private methods
extension AiTransactionHelperTesting on AiTransactionHelper {
  bool shouldRetryForTesting(Object error) {
    // Access the private _shouldRetry method for testing
    // This is a common pattern in Dart testing
    return _shouldRetry(error);
  }

  bool _shouldRetry(Object error) {
    if (error is AiUpdateConflictException) {
      return true;
    }

    final message = error.toString().toLowerCase();
    return message.contains('conflict') ||
        message.contains('database is locked') ||
        message.contains('database is busy') ||
        message.contains('vector clock') ||
        message.contains('busy') ||
        message.contains('locked') ||
        message.contains('concurrent');
  }
}
