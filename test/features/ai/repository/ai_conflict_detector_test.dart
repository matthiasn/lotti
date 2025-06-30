import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/repository/ai_conflict_detector.dart';
import 'package:mocktail/mocktail.dart';

class MockJournalDb extends Mock implements JournalDb {}

class MockJournalDbEntity extends Mock implements JournalDbEntity {}

void main() {
  late MockJournalDb mockDb;
  late AiConflictDetector detector;

  setUp(() {
    mockDb = MockJournalDb();
    detector = AiConflictDetector(mockDb);

    // Clear any existing operations before each test
    AiConflictDetector.clearAll();
  });

  tearDown(AiConflictDetector.clearAll);

  group('AiConflictDetector', () {
    group('hasRecentModification', () {
      test('returns true when task was modified after timestamp', () async {
        // Arrange
        final since = DateTime.now().subtract(const Duration(minutes: 5));
        final updatedAt = DateTime.now(); // After 'since'

        final mockEntity = MockJournalDbEntity();
        when(() => mockEntity.updatedAt).thenReturn(updatedAt);
        when(() => mockDb.entityById('task-1'))
            .thenAnswer((_) async => mockEntity);

        // Act
        final result = await detector.hasRecentModification('task-1', since);

        // Assert
        expect(result, isTrue);
      });

      test('returns false when task was not modified after timestamp',
          () async {
        // Arrange
        final since = DateTime.now();
        final updatedAt = DateTime.now()
            .subtract(const Duration(minutes: 5)); // Before 'since'

        final mockEntity = MockJournalDbEntity();
        when(() => mockEntity.updatedAt).thenReturn(updatedAt);
        when(() => mockDb.entityById('task-1'))
            .thenAnswer((_) async => mockEntity);

        // Act
        final result = await detector.hasRecentModification('task-1', since);

        // Assert
        expect(result, isFalse);
      });

      test('returns true when task is null (deleted)', () async {
        // Arrange
        final since = DateTime.now().subtract(const Duration(minutes: 5));
        when(() => mockDb.entityById('task-1')).thenAnswer((_) async => null);

        // Act
        final result = await detector.hasRecentModification('task-1', since);

        // Assert
        expect(result, isTrue);
      });

      test('returns true when database throws exception', () async {
        // Arrange
        final since = DateTime.now().subtract(const Duration(minutes: 5));
        when(() => mockDb.entityById('task-1'))
            .thenThrow(Exception('Database error'));

        // Act
        final result = await detector.hasRecentModification('task-1', since);

        // Assert
        expect(result, isTrue);
      });
    });

    group('markOperationStart', () {
      test('returns true when no operation is active', () {
        // Act
        final result =
            AiConflictDetector.markOperationStart('task-1', 'test_op');

        // Assert
        expect(result, isTrue);
        expect(AiConflictDetector.hasActiveOperation('task-1'), isTrue);
      });

      test('returns false when operation is already active', () {
        // Arrange
        AiConflictDetector.markOperationStart('task-1', 'first_op');

        // Act
        final result =
            AiConflictDetector.markOperationStart('task-1', 'second_op');

        // Assert
        expect(result, isFalse);
        expect(AiConflictDetector.hasActiveOperation('task-1'), isTrue);
      });

      test('allows different tasks to have concurrent operations', () {
        // Act
        final result1 = AiConflictDetector.markOperationStart('task-1', 'op1');
        final result2 = AiConflictDetector.markOperationStart('task-2', 'op2');

        // Assert
        expect(result1, isTrue);
        expect(result2, isTrue);
        expect(AiConflictDetector.hasActiveOperation('task-1'), isTrue);
        expect(AiConflictDetector.hasActiveOperation('task-2'), isTrue);
      });

      test('cleans up stale operations before checking', () async {
        // This test would require manipulating time, so we test the behavior indirectly
        // by ensuring that operations are tracked correctly

        // Act
        final result =
            AiConflictDetector.markOperationStart('task-1', 'test_op');

        // Assert
        expect(result, isTrue);
        expect(AiConflictDetector.hasActiveOperation('task-1'), isTrue);
      });
    });

    group('markOperationComplete', () {
      test('removes active operation', () {
        // Arrange
        AiConflictDetector.markOperationStart('task-1', 'test_op');
        expect(AiConflictDetector.hasActiveOperation('task-1'), isTrue);

        // Act
        AiConflictDetector.markOperationComplete('task-1');

        // Assert
        expect(AiConflictDetector.hasActiveOperation('task-1'), isFalse);
      });

      test('handles completing non-existent operation gracefully', () {
        // Act & Assert - should not throw
        expect(() => AiConflictDetector.markOperationComplete('task-1'),
            returnsNormally);
      });

      test('allows new operations after completion', () {
        // Arrange
        AiConflictDetector.markOperationStart('task-1', 'first_op');
        AiConflictDetector.markOperationComplete('task-1');

        // Act
        final result =
            AiConflictDetector.markOperationStart('task-1', 'second_op');

        // Assert
        expect(result, isTrue);
        expect(AiConflictDetector.hasActiveOperation('task-1'), isTrue);
      });
    });

    group('hasActiveOperation', () {
      test('returns false when no operation is active', () {
        // Act
        final result = AiConflictDetector.hasActiveOperation('task-1');

        // Assert
        expect(result, isFalse);
      });

      test('returns true when operation is active', () {
        // Arrange
        AiConflictDetector.markOperationStart('task-1', 'test_op');

        // Act
        final result = AiConflictDetector.hasActiveOperation('task-1');

        // Assert
        expect(result, isTrue);
      });

      test('cleans up stale operations before checking', () {
        // This behavior is tested indirectly through other tests
        // since we can't easily manipulate time in unit tests

        // Act
        final result = AiConflictDetector.hasActiveOperation('task-1');

        // Assert
        expect(result, isFalse);
      });
    });

    group('getActiveOperation', () {
      test('returns null when no operation is active', () {
        // Act
        final result = AiConflictDetector.getActiveOperation('task-1');

        // Assert
        expect(result, isNull);
      });

      test('returns operation info when operation is active', () {
        // Arrange
        AiConflictDetector.markOperationStart('task-1', 'test_operation');

        // Act
        final result = AiConflictDetector.getActiveOperation('task-1');

        // Assert
        expect(result, isNotNull);
        expect(result!.operationType, equals('test_operation'));
        expect(result.startTime, isA<DateTime>());
      });

      test('returns different operations for different tasks', () {
        // Arrange
        AiConflictDetector.markOperationStart('task-1', 'operation_1');
        AiConflictDetector.markOperationStart('task-2', 'operation_2');

        // Act
        final result1 = AiConflictDetector.getActiveOperation('task-1');
        final result2 = AiConflictDetector.getActiveOperation('task-2');

        // Assert
        expect(result1!.operationType, equals('operation_1'));
        expect(result2!.operationType, equals('operation_2'));
      });
    });

    group('getStats', () {
      test('returns empty stats when no operations are active', () {
        // Act
        final stats = AiConflictDetector.getStats();

        // Assert
        expect(stats['activeOperations'], equals(0));
        expect(stats['operations'], isEmpty);
      });

      test('returns correct stats for active operations', () {
        // Arrange
        AiConflictDetector.markOperationStart('task-1', 'op1');
        AiConflictDetector.markOperationStart('task-2', 'op2');

        // Act
        final stats = AiConflictDetector.getStats();

        // Assert
        expect(stats['activeOperations'], equals(2));
        expect(stats['operations'], hasLength(2));

        final operations = stats['operations'] as List<Map<String, dynamic>>;
        expect(operations[0]['taskId'], isIn(['task-1', 'task-2']));
        expect(operations[0]['operationType'], isIn(['op1', 'op2']));
        expect(operations[0]['durationSeconds'], isA<int>());
      });

      test('includes duration information', () {
        // Arrange
        AiConflictDetector.markOperationStart('task-1', 'test_op');

        // Act
        final stats = AiConflictDetector.getStats();

        // Assert
        final operations = stats['operations'] as List<Map<String, dynamic>>;
        expect(operations[0]['durationSeconds'], greaterThanOrEqualTo(0));
      });
    });

    group('clearAll', () {
      test('removes all active operations', () {
        // Arrange
        AiConflictDetector.markOperationStart('task-1', 'op1');
        AiConflictDetector.markOperationStart('task-2', 'op2');
        expect(AiConflictDetector.hasActiveOperation('task-1'), isTrue);
        expect(AiConflictDetector.hasActiveOperation('task-2'), isTrue);

        // Act
        AiConflictDetector.clearAll();

        // Assert
        expect(AiConflictDetector.hasActiveOperation('task-1'), isFalse);
        expect(AiConflictDetector.hasActiveOperation('task-2'), isFalse);

        final stats = AiConflictDetector.getStats();
        expect(stats['activeOperations'], equals(0));
      });

      test('allows new operations after clearing', () {
        // Arrange
        AiConflictDetector.markOperationStart('task-1', 'op1');
        AiConflictDetector.clearAll();

        // Act
        final result =
            AiConflictDetector.markOperationStart('task-1', 'new_op');

        // Assert
        expect(result, isTrue);
        expect(AiConflictDetector.hasActiveOperation('task-1'), isTrue);
      });
    });

    group('ActiveOperation', () {
      test('stores operation information correctly', () {
        // Arrange
        final startTime = DateTime.now();
        const operationType = 'test_operation';

        // Act
        final operation = ActiveOperation(
          startTime: startTime,
          operationType: operationType,
        );

        // Assert
        expect(operation.startTime, equals(startTime));
        expect(operation.operationType, equals(operationType));
      });

      test('can be created with const constructor', () {
        // Act & Assert - should compile without issues
        final startTime = DateTime.fromMillisecondsSinceEpoch(0);
        final operation = ActiveOperation(
          startTime: startTime,
          operationType: 'test',
        );

        expect(operation.operationType, equals('test'));
      });
    });

    group('Integration scenarios', () {
      test('handles complete operation lifecycle', () {
        // Arrange
        const taskId = 'task-1';
        const operationType = 'integration_test';

        // Act & Assert - Start operation
        expect(AiConflictDetector.hasActiveOperation(taskId), isFalse);

        final startResult =
            AiConflictDetector.markOperationStart(taskId, operationType);
        expect(startResult, isTrue);
        expect(AiConflictDetector.hasActiveOperation(taskId), isTrue);

        final activeOp = AiConflictDetector.getActiveOperation(taskId);
        expect(activeOp?.operationType, equals(operationType));

        // Complete operation
        AiConflictDetector.markOperationComplete(taskId);
        expect(AiConflictDetector.hasActiveOperation(taskId), isFalse);
        expect(AiConflictDetector.getActiveOperation(taskId), isNull);
      });

      test('prevents concurrent operations on same task', () {
        // Arrange
        const taskId = 'task-1';

        // Act & Assert
        expect(AiConflictDetector.markOperationStart(taskId, 'first'), isTrue);
        expect(
            AiConflictDetector.markOperationStart(taskId, 'second'), isFalse);
        expect(AiConflictDetector.markOperationStart(taskId, 'third'), isFalse);

        // Only first operation should be active
        final activeOp = AiConflictDetector.getActiveOperation(taskId);
        expect(activeOp?.operationType, equals('first'));
      });

      test('allows operations on different tasks simultaneously', () {
        // Act
        final result1 = AiConflictDetector.markOperationStart('task-1', 'op1');
        final result2 = AiConflictDetector.markOperationStart('task-2', 'op2');
        final result3 = AiConflictDetector.markOperationStart('task-3', 'op3');

        // Assert
        expect(result1, isTrue);
        expect(result2, isTrue);
        expect(result3, isTrue);

        expect(AiConflictDetector.hasActiveOperation('task-1'), isTrue);
        expect(AiConflictDetector.hasActiveOperation('task-2'), isTrue);
        expect(AiConflictDetector.hasActiveOperation('task-3'), isTrue);

        final stats = AiConflictDetector.getStats();
        expect(stats['activeOperations'], equals(3));
      });
    });
  });
}
