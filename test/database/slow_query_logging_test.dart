import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/slow_query_logging.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;

import '../mocks/mocks.dart';
import 'slow_query_logging_test_utils.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(
      BatchedStatements(<String>[], <ArgumentsForBatchedStatement>[]),
    );
  });

  group('SlowQueryLoggingGate', () {
    tearDown(resetSlowQueryLoggingGate);

    test('defaults to disabled', () {
      expect(SlowQueryLoggingGate.isEnabled, isFalse);
    });

    test('can be enabled', () {
      SlowQueryLoggingGate.isEnabled = true;
      addTearDown(resetSlowQueryLoggingGate);

      expect(SlowQueryLoggingGate.isEnabled, isTrue);
    });

    test('the test reset restores the disabled state', () {
      SlowQueryLoggingGate.isEnabled = true;
      resetSlowQueryLoggingGate();

      expect(SlowQueryLoggingGate.isEnabled, isFalse);
    });
  });

  group('SlowQueryLogEntry', () {
    test(
      'formattedStatement collapses multiple whitespace into single space',
      () {
        const entry = SlowQueryLogEntry(
          databaseName: 'test_db',
          operation: 'select',
          statement: 'SELECT  *\n  FROM   users\n  WHERE  id = ?',
          arguments: <Object?>[1],
          elapsed: Duration(milliseconds: 100),
        );

        expect(entry.formattedStatement, 'SELECT * FROM users WHERE id = ?');
      },
    );

    test('formattedStatement trims leading and trailing whitespace', () {
      const entry = SlowQueryLogEntry(
        databaseName: 'test_db',
        operation: 'select',
        statement: '  SELECT * FROM users  ',
        arguments: <Object?>[],
        elapsed: Duration(milliseconds: 50),
      );

      expect(entry.formattedStatement, 'SELECT * FROM users');
    });

    test('formattedStatement handles tabs and mixed whitespace', () {
      const entry = SlowQueryLogEntry(
        databaseName: 'test_db',
        operation: 'select',
        statement: 'SELECT\t*\t\tFROM\n\n\tusers',
        arguments: <Object?>[],
        elapsed: Duration(milliseconds: 50),
      );

      expect(entry.formattedStatement, 'SELECT * FROM users');
    });

    test('stores all fields correctly', () {
      final args = <Object?>[1, 'hello', null];
      const elapsed = Duration(milliseconds: 250);

      const entry = SlowQueryLogEntry(
        databaseName: 'my_db',
        operation: 'insert',
        statement: 'INSERT INTO t VALUES (?, ?, ?)',
        arguments: [1, 'hello', null],
        elapsed: elapsed,
      );

      expect(entry.databaseName, 'my_db');
      expect(entry.operation, 'insert');
      expect(entry.statement, 'INSERT INTO t VALUES (?, ?, ?)');
      expect(entry.arguments, args);
      expect(entry.elapsed, elapsed);
    });
  });

  group('SlowQueryInterceptor', () {
    late MockQueryExecutor mockExecutor;
    late List<SlowQueryLogEntry> reportedEntries;
    late SlowQueryInterceptor interceptor;

    setUp(() {
      mockExecutor = MockQueryExecutor();
      reportedEntries = <SlowQueryLogEntry>[];
    });

    tearDown(resetSlowQueryLoggingGate);

    SlowQueryInterceptor createInterceptor({
      Duration threshold = Duration.zero,
    }) {
      return SlowQueryInterceptor(
        databaseName: 'test_db',
        threshold: threshold,
        reporter: reportedEntries.add,
      );
    }

    group('gate disabled - no reporter calls', () {
      setUp(() {
        // Gate stays disabled (default)
        interceptor = createInterceptor();
      });

      test('runSelect does not report when gate is disabled', () async {
        when(
          () => mockExecutor.runSelect(any(), any()),
        ).thenAnswer((_) async => <Map<String, Object?>>[]);

        final result = await interceptor.runSelect(
          mockExecutor,
          'SELECT * FROM users',
          <Object?>[],
        );

        expect(result, isEmpty);
        expect(reportedEntries, isEmpty);
        verify(
          () => mockExecutor.runSelect('SELECT * FROM users', <Object?>[]),
        ).called(1);
      });

      test('runInsert does not report when gate is disabled', () async {
        when(
          () => mockExecutor.runInsert(any(), any()),
        ).thenAnswer((_) async => 1);

        await interceptor.runInsert(
          mockExecutor,
          'INSERT INTO users VALUES (?)',
          <Object?>['Alice'],
        );

        expect(reportedEntries, isEmpty);
      });

      test('runUpdate does not report when gate is disabled', () async {
        when(
          () => mockExecutor.runUpdate(any(), any()),
        ).thenAnswer((_) async => 1);

        await interceptor.runUpdate(
          mockExecutor,
          'UPDATE users SET name = ?',
          <Object?>['Bob'],
        );

        expect(reportedEntries, isEmpty);
      });

      test('runDelete does not report when gate is disabled', () async {
        when(
          () => mockExecutor.runDelete(any(), any()),
        ).thenAnswer((_) async => 1);

        await interceptor.runDelete(
          mockExecutor,
          'DELETE FROM users WHERE id = ?',
          <Object?>[1],
        );

        expect(reportedEntries, isEmpty);
      });

      test('runCustom does not report when gate is disabled', () async {
        when(
          () => mockExecutor.runCustom(any(), any()),
        ).thenAnswer((_) async {});

        await interceptor.runCustom(
          mockExecutor,
          'PRAGMA journal_mode=WAL',
          <Object?>[],
        );

        expect(reportedEntries, isEmpty);
      });

      test('runBatched does not report when gate is disabled', () async {
        final statements = BatchedStatements(
          ['INSERT INTO users VALUES (?)'],
          [
            ArgumentsForBatchedStatement(0, ['Alice']),
          ],
        );
        when(() => mockExecutor.runBatched(any())).thenAnswer((_) async {});

        await interceptor.runBatched(mockExecutor, statements);

        expect(reportedEntries, isEmpty);
      });
    });

    group('gate enabled with zero threshold - reports every query', () {
      setUp(() {
        SlowQueryLoggingGate.isEnabled = true;
        addTearDown(resetSlowQueryLoggingGate);
        interceptor = createInterceptor();
      });

      test('runSelect reports and returns result', () async {
        final expectedResult = <Map<String, Object?>>[
          {'id': 1, 'name': 'Alice'},
        ];
        when(
          () => mockExecutor.runSelect(any(), any()),
        ).thenAnswer((_) async => expectedResult);

        final result = await interceptor.runSelect(
          mockExecutor,
          'SELECT * FROM users',
          <Object?>[],
        );

        expect(result, expectedResult);
        expect(reportedEntries, hasLength(1));

        final entry = reportedEntries.first;
        expect(entry.databaseName, 'test_db');
        expect(entry.operation, 'select');
        expect(entry.statement, 'SELECT * FROM users');
        expect(entry.arguments, <Object?>[]);
        expect(entry.elapsed, greaterThanOrEqualTo(Duration.zero));
      });

      test('runInsert reports and returns inserted row id', () async {
        when(
          () => mockExecutor.runInsert(any(), any()),
        ).thenAnswer((_) async => 42);

        final result = await interceptor.runInsert(
          mockExecutor,
          'INSERT INTO users VALUES (?, ?)',
          <Object?>[1, 'Alice'],
        );

        expect(result, 42);
        expect(reportedEntries, hasLength(1));
        expect(reportedEntries.first.operation, 'insert');
        expect(reportedEntries.first.arguments, <Object?>[1, 'Alice']);
      });

      test('runUpdate reports and returns affected row count', () async {
        when(
          () => mockExecutor.runUpdate(any(), any()),
        ).thenAnswer((_) async => 3);

        final result = await interceptor.runUpdate(
          mockExecutor,
          'UPDATE users SET active = 1',
          <Object?>[],
        );

        expect(result, 3);
        expect(reportedEntries, hasLength(1));
        expect(reportedEntries.first.operation, 'update');
      });

      test('runDelete reports and returns affected row count', () async {
        when(
          () => mockExecutor.runDelete(any(), any()),
        ).thenAnswer((_) async => 5);

        final result = await interceptor.runDelete(
          mockExecutor,
          'DELETE FROM users WHERE active = 0',
          <Object?>[],
        );

        expect(result, 5);
        expect(reportedEntries, hasLength(1));
        expect(reportedEntries.first.operation, 'delete');
      });

      test('runCustom reports', () async {
        when(
          () => mockExecutor.runCustom(any(), any()),
        ).thenAnswer((_) async {});

        await interceptor.runCustom(
          mockExecutor,
          'PRAGMA journal_mode=WAL',
          <Object?>[],
        );

        expect(reportedEntries, hasLength(1));
        expect(reportedEntries.first.operation, 'custom');
        expect(
          reportedEntries.first.statement,
          'PRAGMA journal_mode=WAL',
        );
      });

      test(
        'runBatched reports with correct operation and expanded args',
        () async {
          final statements = BatchedStatements(
            ['INSERT INTO users VALUES (?, ?)'],
            [
              ArgumentsForBatchedStatement(0, ['Alice', 1]),
              ArgumentsForBatchedStatement(0, ['Bob', 2]),
              ArgumentsForBatchedStatement(0, ['Carol', 3]),
            ],
          );
          when(() => mockExecutor.runBatched(any())).thenAnswer((_) async {});

          await interceptor.runBatched(mockExecutor, statements);

          expect(reportedEntries, hasLength(1));

          final entry = reportedEntries.first;
          expect(entry.operation, 'batch[3]');
          expect(entry.statement, 'INSERT INTO users VALUES (?, ?)');
          expect(
            entry.arguments,
            <Object?>['Alice', 1, 'Bob', 2, 'Carol', 3],
          );
        },
      );

      test('runBatched uses <empty batch> for empty statements list', () async {
        final statements = BatchedStatements(
          <String>[],
          <ArgumentsForBatchedStatement>[],
        );
        when(() => mockExecutor.runBatched(any())).thenAnswer((_) async {});

        await interceptor.runBatched(mockExecutor, statements);

        expect(reportedEntries, hasLength(1));
        expect(reportedEntries.first.operation, 'batch[0]');
        expect(reportedEntries.first.statement, '<empty batch>');
        expect(reportedEntries.first.arguments, isEmpty);
      });

      test('delegates to actual executor for each method', () async {
        when(
          () => mockExecutor.runSelect(any(), any()),
        ).thenAnswer((_) async => <Map<String, Object?>>[]);
        when(
          () => mockExecutor.runInsert(any(), any()),
        ).thenAnswer((_) async => 1);
        when(
          () => mockExecutor.runUpdate(any(), any()),
        ).thenAnswer((_) async => 1);
        when(
          () => mockExecutor.runDelete(any(), any()),
        ).thenAnswer((_) async => 1);
        when(
          () => mockExecutor.runCustom(any(), any()),
        ).thenAnswer((_) async {});
        when(() => mockExecutor.runBatched(any())).thenAnswer((_) async {});

        await interceptor.runSelect(
          mockExecutor,
          'SELECT 1',
          <Object?>[],
        );
        await interceptor.runInsert(
          mockExecutor,
          'INSERT INTO t VALUES (1)',
          <Object?>[],
        );
        await interceptor.runUpdate(
          mockExecutor,
          'UPDATE t SET x = 1',
          <Object?>[],
        );
        await interceptor.runDelete(
          mockExecutor,
          'DELETE FROM t',
          <Object?>[],
        );
        await interceptor.runCustom(
          mockExecutor,
          'PRAGMA x',
          <Object?>[],
        );

        final batch = BatchedStatements(
          ['INSERT INTO t VALUES (?)'],
          [
            ArgumentsForBatchedStatement(0, [1]),
          ],
        );
        await interceptor.runBatched(mockExecutor, batch);

        verify(() => mockExecutor.runSelect('SELECT 1', <Object?>[])).called(1);
        verify(
          () => mockExecutor.runInsert('INSERT INTO t VALUES (1)', <Object?>[]),
        ).called(1);
        verify(
          () => mockExecutor.runUpdate('UPDATE t SET x = 1', <Object?>[]),
        ).called(1);
        verify(
          () => mockExecutor.runDelete('DELETE FROM t', <Object?>[]),
        ).called(1);
        verify(() => mockExecutor.runCustom('PRAGMA x', <Object?>[])).called(1);
        verify(() => mockExecutor.runBatched(batch)).called(1);
      });
    });

    group('threshold behavior', () {
      test('does not report when query is below threshold', () async {
        SlowQueryLoggingGate.isEnabled = true;
        addTearDown(resetSlowQueryLoggingGate);

        // Use a very high threshold so no real query can exceed it
        interceptor = createInterceptor(
          threshold: const Duration(hours: 1),
        );

        when(
          () => mockExecutor.runSelect(any(), any()),
        ).thenAnswer((_) async => <Map<String, Object?>>[]);

        await interceptor.runSelect(
          mockExecutor,
          'SELECT 1',
          <Object?>[],
        );

        expect(reportedEntries, isEmpty);
      });

      test('reports when gate enabled and threshold is zero', () async {
        SlowQueryLoggingGate.isEnabled = true;
        addTearDown(resetSlowQueryLoggingGate);

        interceptor = createInterceptor();

        when(
          () => mockExecutor.runSelect(any(), any()),
        ).thenAnswer((_) async => <Map<String, Object?>>[]);

        await interceptor.runSelect(
          mockExecutor,
          'SELECT 1',
          <Object?>[],
        );

        expect(reportedEntries, hasLength(1));
      });
    });

    test(
      'captures executor boundaries before deferred query-plan reporting',
      () async {
        SlowQueryLoggingGate.isEnabled = true;
        final select = Completer<List<Map<String, Object?>>>();
        final plan = Completer<List<Map<String, Object?>>>();
        final planStarted = Completer<void>();
        var now = DateTime.utc(2024, 1, 1, 10);
        when(() => mockExecutor.runSelect('SELECT 1', any())).thenAnswer(
          (_) => select.future,
        );
        when(
          () => mockExecutor.runSelect('EXPLAIN QUERY PLAN SELECT 1', any()),
        ).thenAnswer((_) {
          planStarted.complete();
          return plan.future;
        });
        interceptor = SlowQueryInterceptor(
          databaseName: 'test_db',
          threshold: Duration.zero,
          superSlowThreshold: Duration.zero,
          reporter: reportedEntries.add,
        );
        await withClock(Clock(() => now), () async {
          final operation = interceptor.runSelect(mockExecutor, 'SELECT 1', []);
          now = DateTime.utc(2024, 1, 1, 10, 0, 3);
          select.complete([]);
          await planStarted.future;
          now = DateTime.utc(2024, 1, 1, 10, 0, 9);
          plan.complete([]);
          await operation;
        });
        final entry = reportedEntries.single;
        expect(entry.startedAt, DateTime.utc(2024, 1, 1, 10));
        expect(entry.completedAt, DateTime.utc(2024, 1, 1, 10, 0, 3));
        expect(entry.inFlightAtStart, 1);
      },
    );

    test(
      'counts overlapping executor calls and releases failed calls',
      () async {
        SlowQueryLoggingGate.isEnabled = true;
        final first = Completer<List<Map<String, Object?>>>();
        when(
          () => mockExecutor.runSelect('SELECT 1', any()),
        ).thenAnswer((_) => first.future);
        when(
          () => mockExecutor.runSelect('SELECT 2', any()),
        ).thenAnswer((_) async => []);
        interceptor = createInterceptor();
        final pending = interceptor.runSelect(mockExecutor, 'SELECT 1', []);
        final failure = expectLater(pending, throwsStateError);
        await interceptor.runSelect(mockExecutor, 'SELECT 2', []);
        first.completeError(StateError('synthetic failure'));
        await failure;
        await interceptor.runSelect(mockExecutor, 'SELECT 2', []);
        expect(reportedEntries.map((entry) => entry.inFlightAtStart), [
          2,
          1,
          1,
        ]);
      },
    );

    group('error propagation', () {
      test('propagates executor exception and still does not report when gate '
          'is disabled', () async {
        when(
          () => mockExecutor.runSelect(any(), any()),
        ).thenThrow(Exception('db error'));

        interceptor = createInterceptor();

        await expectLater(
          () => interceptor.runSelect(
            mockExecutor,
            'SELECT 1',
            <Object?>[],
          ),
          throwsA(isA<Exception>()),
        );

        expect(reportedEntries, isEmpty);
      });

      test('propagates executor exception and still reports when gate is '
          'enabled', () async {
        SlowQueryLoggingGate.isEnabled = true;
        addTearDown(resetSlowQueryLoggingGate);

        when(
          () => mockExecutor.runSelect(any(), any()),
        ).thenThrow(Exception('db error'));

        interceptor = createInterceptor();

        await expectLater(
          () => interceptor.runSelect(
            mockExecutor,
            'SELECT 1',
            <Object?>[],
          ),
          throwsA(isA<Exception>()),
        );

        // The finally block still runs, so report should be called
        expect(reportedEntries, hasLength(1));
      });
    });

    group('super-slow query plan capture', () {
      setUp(() {
        SlowQueryLoggingGate.isEnabled = true;
        addTearDown(resetSlowQueryLoggingGate);
      });

      test('select crossing super threshold captures EXPLAIN QUERY PLAN '
          'and marks entry isSuperSlow', () async {
        // Force every reported query down the super-slow path so the test
        // is deterministic regardless of how fast the mock returns.
        interceptor = SlowQueryInterceptor(
          databaseName: 'test_db',
          threshold: Duration.zero,
          superSlowThreshold: Duration.zero,
          reporter: reportedEntries.add,
        );

        // First mock answer: actual select. Second mock answer: EXPLAIN.
        var callCount = 0;
        when(() => mockExecutor.runSelect(any(), any())).thenAnswer((
          invocation,
        ) async {
          callCount++;
          if (callCount == 1) return <Map<String, Object?>>[];
          return <Map<String, Object?>>[
            {'id': 2, 'parent': 0, 'detail': 'SEARCH journal USING IDX'},
            {'id': 3, 'parent': 0, 'detail': 'SCAN linked_entries'},
          ];
        });

        await interceptor.runSelect(
          mockExecutor,
          'SELECT * FROM journal WHERE id = ?',
          <Object?>['x'],
        );

        expect(reportedEntries, hasLength(1));
        expect(reportedEntries.first.isSuperSlow, isTrue);
        expect(reportedEntries.first.queryPlan, <String>[
          '2|0|SEARCH journal USING IDX',
          '3|0|SCAN linked_entries',
        ]);

        // Original statement + EXPLAIN-prefixed statement both ran.
        verify(
          () => mockExecutor.runSelect(
            'SELECT * FROM journal WHERE id = ?',
            <Object?>['x'],
          ),
        ).called(1);
        verify(
          () => mockExecutor.runSelect(
            'EXPLAIN QUERY PLAN SELECT * FROM journal WHERE id = ?',
            <Object?>['x'],
          ),
        ).called(1);
      });

      test('select below super threshold does not run EXPLAIN', () async {
        // Default 200ms super threshold; mock returns immediately.
        interceptor = createInterceptor();

        when(
          () => mockExecutor.runSelect(any(), any()),
        ).thenAnswer((_) async => <Map<String, Object?>>[]);

        await interceptor.runSelect(
          mockExecutor,
          'SELECT 1',
          <Object?>[],
        );

        expect(reportedEntries, hasLength(1));
        expect(reportedEntries.first.isSuperSlow, isFalse);
        expect(reportedEntries.first.queryPlan, isNull);
        // Only the actual select; no EXPLAIN-prefixed call.
        verify(
          () => mockExecutor.runSelect('SELECT 1', <Object?>[]),
        ).called(1);
        verifyNoMoreInteractions(mockExecutor);
      });

      test('non-select operations never capture a plan', () async {
        // Force reporter to fire on every call. Non-select paths should not
        // call runSelect at all (no EXPLAIN), and queryPlan stays null.
        interceptor = SlowQueryInterceptor(
          databaseName: 'test_db',
          threshold: Duration.zero,
          superSlowThreshold: Duration.zero,
          reporter: reportedEntries.add,
        );

        when(
          () => mockExecutor.runUpdate(any(), any()),
        ).thenAnswer((_) async => 1);

        await interceptor.runUpdate(
          mockExecutor,
          'UPDATE journal SET deleted = TRUE',
          <Object?>[],
        );

        expect(reportedEntries, hasLength(1));
        expect(reportedEntries.first.isSuperSlow, isTrue);
        expect(reportedEntries.first.queryPlan, isNull);
        verifyNever(() => mockExecutor.runSelect(any(), any()));
      });

      test(
        'first-call stack capture: gate off → no callerStack',
        () async {
          interceptor = SlowQueryInterceptor(
            databaseName: 'test_db',
            threshold: Duration.zero,
            superSlowThreshold: Duration.zero,
            reporter: reportedEntries.add,
          );
          when(
            () => mockExecutor.runSelect(any(), any()),
          ).thenAnswer((_) async => <Map<String, Object?>>[]);

          await interceptor.runSelect(
            mockExecutor,
            'SELECT 1 -- gate-off-no-stack',
            <Object?>[],
          );

          expect(reportedEntries, hasLength(1));
          expect(reportedEntries.first.callerStack, isNull);
        },
      );

      test(
        'first-call stack capture: gate on → exactly one capture per '
        'unique statement, subsequent fires of the same statement reuse '
        'the seen-set so the boot wave produces one trace per shape, not '
        'thousands of duplicates',
        () async {
          SlowQueryLoggingGate.captureFirstCallStack = true;
          addTearDown(resetSlowQueryLoggingGate);

          interceptor = SlowQueryInterceptor(
            databaseName: 'test_db',
            threshold: Duration.zero,
            superSlowThreshold: Duration.zero,
            reporter: reportedEntries.add,
          );
          when(
            () => mockExecutor.runSelect(any(), any()),
          ).thenAnswer((_) async => <Map<String, Object?>>[]);

          await interceptor.runSelect(
            mockExecutor,
            'SELECT * FROM unique_stmt_first',
            <Object?>[],
          );
          await interceptor.runSelect(
            mockExecutor,
            'SELECT * FROM unique_stmt_first',
            <Object?>[],
          );
          await interceptor.runSelect(
            mockExecutor,
            'SELECT * FROM unique_stmt_second',
            <Object?>[],
          );

          expect(reportedEntries, hasLength(3));
          expect(
            reportedEntries[0].callerStack,
            isNotNull,
            reason: 'first occurrence captures stack',
          );
          expect(
            reportedEntries[1].callerStack,
            isNull,
            reason: 'duplicate statement skips capture',
          );
          expect(
            reportedEntries[2].callerStack,
            isNotNull,
            reason: 'a different statement is its own first occurrence',
          );
        },
      );

      test(
        'markStatementSeenAndIsFirst returns true exactly once per statement',
        () {
          expect(
            SlowQueryLoggingGate.markStatementSeenAndIsFirst('SELECT a'),
            isTrue,
          );
          expect(
            SlowQueryLoggingGate.markStatementSeenAndIsFirst('SELECT a'),
            isFalse,
          );
          expect(
            SlowQueryLoggingGate.markStatementSeenAndIsFirst('SELECT b'),
            isTrue,
          );
        },
      );

      test(
        'EXPLAIN failure does not break the original result or report',
        () async {
          interceptor = SlowQueryInterceptor(
            databaseName: 'test_db',
            threshold: Duration.zero,
            superSlowThreshold: Duration.zero,
            reporter: reportedEntries.add,
          );

          // First call succeeds (the real query); second call (EXPLAIN) blows up.
          var callCount = 0;
          when(() => mockExecutor.runSelect(any(), any())).thenAnswer((
            invocation,
          ) async {
            callCount++;
            if (callCount == 1) {
              return <Map<String, Object?>>[
                {'id': 1, 'name': 'Alice'},
              ];
            }
            throw Exception('explain failed');
          });

          final result = await interceptor.runSelect(
            mockExecutor,
            'SELECT * FROM users',
            <Object?>[],
          );

          expect(result, [
            {'id': 1, 'name': 'Alice'},
          ]);
          expect(reportedEntries, hasLength(1));
          expect(reportedEntries.first.isSuperSlow, isTrue);
          // EXPLAIN failure leaves queryPlan null but the entry is still reported.
          expect(reportedEntries.first.queryPlan, isNull);
        },
      );
    });
  });

  group('fileReporter', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('slow_query_test_');
    });

    tearDown(() async {
      resetSlowQueryLoggingGate();
      await SlowQueryInterceptor.flushPendingFileWrites();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('writes log line to a dated file in logs subdirectory', () async {
      final reporter = SlowQueryInterceptor.fileReporter(
        documentsDirectoryPath: tempDir.path,
      );

      const entry = SlowQueryLogEntry(
        databaseName: 'test_db',
        operation: 'select',
        statement: 'SELECT  *\n  FROM  users',
        arguments: <Object?>[1, 'hello'],
        elapsed: Duration(milliseconds: 123),
      );

      reporter(entry);
      await SlowQueryInterceptor.flushPendingFileWrites();

      final logsDir = Directory('${tempDir.path}/logs');
      expect(logsDir.existsSync(), isTrue);

      final logFiles = logsDir.listSync().whereType<File>().toList(
        growable: false,
      );
      expect(logFiles, hasLength(1));

      final logFile = logFiles.first;
      // Verify file name matches pattern slow_queries-YYYY-MM-DD.log
      expect(
        logFile.path,
        matches(RegExp(r'slow_queries-\d{4}-\d{2}-\d{2}\.log$')),
      );

      final content = logFile.readAsStringSync();
      // Verify log line contains expected parts
      expect(content, contains('[test_db]'));
      expect(content, contains('select'));
      expect(content, contains('123.000ms'));
      expect(content, contains('args=2'));
      expect(content, contains('SELECT * FROM users'));
      // Line should end with newline
      expect(content, endsWith('\n'));
    });

    test(
      'writes executor timing bounds without claiming native SQL time',
      () async {
        final reporter = SlowQueryInterceptor.fileReporter(
          documentsDirectoryPath: tempDir.path,
        );
        reporter(
          SlowQueryLogEntry(
            databaseName: 'test_db',
            operation: 'select',
            statement: 'SELECT 1',
            arguments: const [],
            elapsed: const Duration(seconds: 3),
            startedAt: DateTime.utc(2024, 1, 1, 10),
            completedAt: DateTime.utc(2024, 1, 1, 10, 0, 3),
            inFlightAtStart: 4,
          ),
        );
        await SlowQueryInterceptor.flushPendingFileWrites();
        final content = Directory(
          '${tempDir.path}/logs',
        ).listSync().whereType<File>().single.readAsStringSync();
        expect(
          content,
          contains(
            'TIMING: scope=executorAwait started=2024-01-01T10:00:00.000Z completed=2024-01-01T10:00:03.000Z inFlightAtStart=4',
          ),
        );
      },
    );

    test('uses custom fileStem', () async {
      final reporter = SlowQueryInterceptor.fileReporter(
        documentsDirectoryPath: tempDir.path,
        fileStem: 'custom_queries',
      );

      const entry = SlowQueryLogEntry(
        databaseName: 'db',
        operation: 'select',
        statement: 'SELECT 1',
        arguments: <Object?>[],
        elapsed: Duration(milliseconds: 10),
      );

      reporter(entry);
      await SlowQueryInterceptor.flushPendingFileWrites();

      final logsDir = Directory('${tempDir.path}/logs');
      final logFiles = logsDir.listSync().whereType<File>().toList(
        growable: false,
      );
      expect(logFiles, hasLength(1));
      expect(
        logFiles.first.path,
        matches(RegExp(r'custom_queries-\d{4}-\d{2}-\d{2}\.log$')),
      );
    });

    test('appends multiple entries to the same file', () async {
      final reporter = SlowQueryInterceptor.fileReporter(
        documentsDirectoryPath: tempDir.path,
      );

      for (var i = 0; i < 3; i++) {
        reporter(
          SlowQueryLogEntry(
            databaseName: 'db',
            operation: 'select',
            statement: 'SELECT $i',
            arguments: <Object?>[],
            elapsed: const Duration(milliseconds: 50),
          ),
        );
      }

      await SlowQueryInterceptor.flushPendingFileWrites();

      final logsDir = Directory('${tempDir.path}/logs');
      final logFiles = logsDir.listSync().whereType<File>().toList(
        growable: false,
      );
      expect(logFiles, hasLength(1));

      final lines = logFiles.first
          .readAsStringSync()
          .split('\n')
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
      expect(lines, hasLength(3));
      expect(lines[0], contains('SELECT 0'));
      expect(lines[1], contains('SELECT 1'));
      expect(lines[2], contains('SELECT 2'));
    });

    test('serializes concurrent writes via _SlowQueryFileSink', () async {
      final reporter = SlowQueryInterceptor.fileReporter(
        documentsDirectoryPath: tempDir.path,
      );

      // Fire many entries rapidly to exercise serialization
      for (var i = 0; i < 10; i++) {
        reporter(
          SlowQueryLogEntry(
            databaseName: 'db',
            operation: 'insert',
            statement: 'INSERT $i',
            arguments: <Object?>[],
            elapsed: const Duration(milliseconds: 1),
          ),
        );
      }

      await SlowQueryInterceptor.flushPendingFileWrites();

      final logsDir = Directory('${tempDir.path}/logs');
      final logFiles = logsDir.listSync().whereType<File>().toList(
        growable: false,
      );
      expect(logFiles, hasLength(1));

      final lines = logFiles.first
          .readAsStringSync()
          .split('\n')
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
      expect(lines, hasLength(10));

      // All 10 entries should be present (order preserved by serialization)
      for (var i = 0; i < 10; i++) {
        expect(lines[i], contains('INSERT $i'));
      }
    });

    test('super-slow entry is duplicated to super_slow_queries log with '
        'indented PLAN rows', () async {
      final reporter = SlowQueryInterceptor.fileReporter(
        documentsDirectoryPath: tempDir.path,
      );

      const entry = SlowQueryLogEntry(
        databaseName: 'test_db',
        operation: 'select',
        statement: 'SELECT * FROM journal WHERE id = ?',
        arguments: <Object?>['x'],
        elapsed: Duration(milliseconds: 250),
        isSuperSlow: true,
        queryPlan: <String>[
          '2|0|SEARCH journal USING IDX',
          '3|0|SCAN linked_entries',
        ],
      );

      reporter(entry);
      await SlowQueryInterceptor.flushPendingFileWrites();

      final logsDir = Directory('${tempDir.path}/logs');
      final files = logsDir.listSync().whereType<File>().toList(
        growable: false,
      );
      // One slow_queries file + one super_slow_queries file for the same day.
      expect(files, hasLength(2));

      final slowFile = files.firstWhere(
        (f) => p.basename(f.path).startsWith('slow_queries-'),
      );
      final superFile = files.firstWhere(
        (f) => p.basename(f.path).startsWith('super_slow_queries-'),
      );

      // The slow_queries file holds just the bare query line (no plan rows).
      final slowContent = slowFile.readAsStringSync();
      expect(slowContent, contains('250.000ms'));
      expect(slowContent, isNot(contains('PLAN:')));

      // The super file repeats the query line and appends indented plan rows.
      final superContent = superFile.readAsStringSync();
      expect(superContent, contains('250.000ms'));
      expect(superContent, contains('  PLAN: 2|0|SEARCH journal USING IDX'));
      expect(superContent, contains('  PLAN: 3|0|SCAN linked_entries'));
    });

    test('non-super-slow entry only writes to slow_queries log', () async {
      final reporter = SlowQueryInterceptor.fileReporter(
        documentsDirectoryPath: tempDir.path,
      );

      const entry = SlowQueryLogEntry(
        databaseName: 'db',
        operation: 'select',
        statement: 'SELECT 1',
        arguments: <Object?>[],
        elapsed: Duration(milliseconds: 50),
      );

      reporter(entry);
      await SlowQueryInterceptor.flushPendingFileWrites();

      final logsDir = Directory('${tempDir.path}/logs');
      final files = logsDir.listSync().whereType<File>().toList(
        growable: false,
      );
      expect(files, hasLength(1));
      expect(
        p.basename(files.first.path),
        startsWith('slow_queries-'),
      );
    });

    test(
      'super-slow entry with callerStack writes only app-code STACK lines '
      'and drops drift / dart-runtime / interceptor frames so the log is '
      'readable instead of buried in identical boilerplate',
      () async {
        final reporter = SlowQueryInterceptor.fileReporter(
          documentsDirectoryPath: tempDir.path,
        );

        // Synthetic stack covers every filter branch:
        // - drift/dart-runtime frames that should be dropped
        // - the slow-query plumbing self-frame that should be dropped
        // - one application frame that should be kept
        // - blank lines (separators) that should be dropped
        const stackLines = <String>[
          '#0      SlowQueryInterceptor._measure (package:lotti/database/slow_query_logging.dart:200:12)',
          '#1      _InterceptedExecutor.runSelect (package:drift/src/runtime/executor/interceptor.dart:163:25)',
          '#2      _rootRunUnary (dart:async/zone_root.dart:48:47)',
          '<asynchronous suspension>',
          '#3      JournalDb.getAllDashboards (package:lotti/database/database.dart:3056:34)',
          '',
          '#4      DashboardsController.build (package:lotti/features/dashboards/state/dashboards_page_controller.dart:20:14)',
        ];
        final stack = StackTrace.fromString(stackLines.join('\n'));

        final entry = SlowQueryLogEntry(
          databaseName: 'test_db',
          operation: 'select',
          statement: 'SELECT * FROM dashboard_definitions',
          arguments: const <Object?>[],
          elapsed: const Duration(milliseconds: 500),
          isSuperSlow: true,
          callerStack: stack,
        );

        reporter(entry);
        await SlowQueryInterceptor.flushPendingFileWrites();

        final logsDir = Directory('${tempDir.path}/logs');
        final superFile = logsDir.listSync().whereType<File>().firstWhere(
          (f) => p.basename(f.path).startsWith('super_slow_queries-'),
        );
        final superContent = superFile.readAsStringSync();

        // App-code frames are kept and prefixed with `STACK: `.
        expect(
          superContent,
          contains('STACK: #3      JournalDb.getAllDashboards '),
        );
        expect(
          superContent,
          contains(
            'STACK: #4      DashboardsController.build ',
          ),
        );
        // Drift / dart runtime frames are dropped.
        expect(superContent, isNot(contains('package:drift/')));
        expect(superContent, isNot(contains('dart:async/')));
        expect(superContent, isNot(contains('asynchronous suspension')));
        // The slow-query plumbing self-frame is dropped even though it
        // technically points at `package:lotti/...` — otherwise every
        // entry would carry a constant boilerplate line.
        expect(superContent, isNot(contains('slow_query_logging.dart')));
      },
    );

    test(
      'super-slow entry without plan rows still duplicates the query line',
      () async {
        final reporter = SlowQueryInterceptor.fileReporter(
          documentsDirectoryPath: tempDir.path,
        );

        // Models the EXPLAIN-failure path where queryPlan stays null.
        const entry = SlowQueryLogEntry(
          databaseName: 'db',
          operation: 'select',
          statement: 'SELECT 1',
          arguments: <Object?>[],
          elapsed: Duration(milliseconds: 250),
          isSuperSlow: true,
        );

        reporter(entry);
        await SlowQueryInterceptor.flushPendingFileWrites();

        final logsDir = Directory('${tempDir.path}/logs');
        final files = logsDir.listSync().whereType<File>().toList(
          growable: false,
        );
        expect(files, hasLength(2));

        final superFile = files.firstWhere(
          (f) => p.basename(f.path).startsWith('super_slow_queries-'),
        );
        final superContent = superFile.readAsStringSync();
        expect(superContent, contains('SELECT 1'));
        expect(superContent, isNot(contains('PLAN:')));
      },
    );

    test('log line starts with ISO-8601 timestamp', () async {
      final reporter = SlowQueryInterceptor.fileReporter(
        documentsDirectoryPath: tempDir.path,
      );

      const entry = SlowQueryLogEntry(
        databaseName: 'db',
        operation: 'select',
        statement: 'SELECT 1',
        arguments: <Object?>[],
        elapsed: Duration(milliseconds: 5),
      );

      reporter(entry);
      await SlowQueryInterceptor.flushPendingFileWrites();

      final logsDir = Directory('${tempDir.path}/logs');
      final logFiles = logsDir.listSync().whereType<File>().toList(
        growable: false,
      );
      final content = logFiles.first.readAsStringSync().trim();

      // ISO-8601 timestamp at the start of the line
      expect(
        content,
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}')),
      );
    });

    test(
      'append failure is swallowed and logged via DevLogger.error instead of '
      'propagating to the caller',
      () async {
        DevLogger.clear();
        addTearDown(DevLogger.clear);

        // Place a regular FILE where the reporter expects a `logs/`
        // directory. `file.parent.create(recursive: true)` then fails because
        // a file cannot host a child directory, driving the append() catch
        // block instead of crashing the (fire-and-forget) reporter.
        File('${tempDir.path}/logs').writeAsStringSync('not a directory');

        final reporter = SlowQueryInterceptor.fileReporter(
          documentsDirectoryPath: tempDir.path,
        );

        const entry = SlowQueryLogEntry(
          databaseName: 'db',
          operation: 'select',
          statement: 'SELECT 1',
          arguments: <Object?>[],
          elapsed: Duration(milliseconds: 5),
        );

        // Must not throw even though the underlying write is impossible.
        reporter(entry);
        await SlowQueryInterceptor.flushPendingFileWrites();

        // The failure surfaces only through DevLogger, not as an exception.
        expect(
          DevLogger.capturedLogs,
          contains(
            allOf(
              contains('[DB_SLOW_QUERY]'),
              contains('Failed to append slow query log line'),
              contains('FileSystemException'),
            ),
          ),
        );

        // The `logs` path is still the file we created; no log file written.
        expect(
          FileSystemEntity.isDirectorySync('${tempDir.path}/logs'),
          isFalse,
        );
      },
    );
  });

  group('devLoggerReporter', () {
    setUp(DevLogger.clear);
    tearDown(DevLogger.clear);

    test('logs a single warning line with database, operation, elapsed ms, '
        'arg count and the formatted statement', () {
      final reporter = SlowQueryInterceptor.devLoggerReporter();

      const entry = SlowQueryLogEntry(
        databaseName: 'journal_db',
        operation: 'select',
        statement: 'SELECT  *\n  FROM   journal\n  WHERE id = ?',
        arguments: <Object?>[1, 'x'],
        elapsed: Duration(milliseconds: 250),
      );

      reporter(entry);

      // elapsed renders as inMicroseconds / 1000 == 250000 / 1000 == 250.0.
      expect(DevLogger.capturedLogs, hasLength(1));
      expect(
        DevLogger.capturedLogs.single,
        allOf(
          contains('[DB_SLOW_QUERY]'),
          contains('WARNING:'),
          contains('[journal_db]'),
          contains('select'),
          contains('250.0ms'),
          contains('args=2'),
          contains('SELECT * FROM journal WHERE id = ?'),
        ),
      );
    });

    test('renders sub-millisecond elapsed durations from microseconds', () {
      final reporter = SlowQueryInterceptor.devLoggerReporter();

      const entry = SlowQueryLogEntry(
        databaseName: 'db',
        operation: 'insert',
        statement: 'INSERT INTO t VALUES (?)',
        arguments: <Object?>['a'],
        // 1500 microseconds -> 1.5ms.
        elapsed: Duration(microseconds: 1500),
      );

      reporter(entry);

      expect(DevLogger.capturedLogs.single, contains('1.5ms'));
      expect(DevLogger.capturedLogs.single, contains('args=1'));
    });
  });

  group('transaction diagnostics', () {
    late MockQueryExecutor parent;
    late MockTransactionExecutor inner;
    late MockQueryExecutorUser user;
    late List<SlowQueryLogEntry> entries;
    late QueryExecutor connection;

    setUp(() {
      SlowQueryLoggingGate.isEnabled = true;
      parent = MockQueryExecutor();
      inner = MockTransactionExecutor();
      user = MockQueryExecutorUser();
      entries = [];
      when(parent.beginTransaction).thenReturn(inner);
      when(() => inner.ensureOpen(user)).thenAnswer((_) async => true);
      when(inner.send).thenAnswer((_) async {});
      when(inner.rollback).thenAnswer((_) async {});
      when(() => inner.runCustom('INSIDE', const [])).thenAnswer((_) async {});
      when(
        () => parent.runCustom('OUTSIDE', const []),
      ).thenAnswer((_) async {});
      connection = parent.interceptWith(
        SlowQueryInterceptor(
          databaseName: 'transactions',
          threshold: Duration.zero,
          reporter: entries.add,
        ),
      );
    });

    tearDown(resetSlowQueryLoggingGate);

    test(
      'reports acquisition and lifetime around a successful transaction',
      () async {
        final tx = connection.beginTransaction();
        expect(await tx.ensureOpen(user), isTrue);
        await tx.runCustom('INSIDE');
        await connection.runCustom('OUTSIDE');
        await tx.send();
        await connection.runCustom('OUTSIDE');

        expect(entries.map((entry) => entry.operation), [
          'transaction.open',
          'custom',
          'custom',
          'transaction.commit',
          'transaction',
          'custom',
        ]);
        expect(entries[1].transactionId, 1);
        expect(entries[1].activeTransactionIdsAtStart, [1]);
        expect(entries[2].transactionId, isNull);
        expect(entries[2].activeTransactionIdsAtStart, [1]);
        expect(entries[4].scope, 'transactionLifetime');
        expect(entries.last.activeTransactionIdsAtStart, isEmpty);
        expect(
          entries
              .where((entry) => entry.operation == 'transaction')
              .single
              .statement,
          'COMMIT',
        );
        verify(() => inner.ensureOpen(user)).called(1);
        verify(inner.send).called(1);
      },
    );

    test('failed commit preserves the transaction until rollback', () async {
      final failure = StateError('synthetic commit failure');
      when(inner.send).thenAnswer((_) async => throw failure);
      final tx = connection.beginTransaction();
      await tx.ensureOpen(user);
      await expectLater(tx.send(), throwsA(same(failure)));
      await connection.runCustom('OUTSIDE');
      await tx.rollback();
      await connection.runCustom('OUTSIDE');

      expect(entries.map((entry) => entry.operation), [
        'transaction.open',
        'transaction.commit',
        'custom',
        'transaction.rollback',
        'transaction',
        'custom',
      ]);
      expect(entries[2].activeTransactionIdsAtStart, [1]);
      expect(entries.last.activeTransactionIdsAtStart, isEmpty);
      expect(
        entries
            .where((entry) => entry.operation == 'transaction')
            .single
            .statement,
        'ROLLBACK',
      );
      verify(inner.rollback).called(1);
    });

    test(
      'reporter failures cannot alter transaction results or mask SQL errors',
      () async {
        final sqlFailure = StateError('original SQL failure');
        connection = parent.interceptWith(
          SlowQueryInterceptor(
            databaseName: 'throwing_reporter',
            threshold: Duration.zero,
            reporter: (_) => throw StateError('synthetic reporting failure'),
          ),
        );
        final tx = connection.beginTransaction();
        expect(await tx.ensureOpen(user), isTrue);
        await tx.runCustom('INSIDE');
        await tx.send();
        verify(inner.send).called(1);
        verifyNever(inner.rollback);

        when(
          () => parent.runCustom('OUTSIDE', const []),
        ).thenAnswer((_) async => throw sqlFailure);
        await expectLater(
          connection.runCustom('OUTSIDE'),
          throwsA(same(sqlFailure)),
        );
      },
    );

    test('nested transaction IDs preserve the still-active parent', () async {
      final nested = MockTransactionExecutor();
      when(inner.beginTransaction).thenReturn(nested);
      when(() => nested.ensureOpen(user)).thenAnswer((_) async => true);
      when(nested.send).thenAnswer((_) async {});
      final tx = connection.beginTransaction();
      await tx.ensureOpen(user);
      final child = tx.beginTransaction();
      await child.ensureOpen(user);
      await child.send();
      await tx.runCustom('INSIDE');
      await tx.rollback();
      await connection.runCustom('OUTSIDE');
      final childSpan = entries.firstWhere(
        (entry) => entry.operation == 'transaction' && entry.transactionId == 2,
      );
      expect(childSpan.parentTransactionId, 1);
      expect(childSpan.activeTransactionIdsAtStart, [1, 2]);
      final parentQuery = entries.firstWhere(
        (entry) => entry.statement == 'INSIDE',
      );
      expect(parentQuery.transactionId, 1);
      expect(parentQuery.activeTransactionIdsAtStart, [1]);
      expect(entries.last.activeTransactionIdsAtStart, isEmpty);
    });

    test(
      'acquisition is reported once and pending opens are not active',
      () async {
        final opened = Completer<bool>();
        when(() => inner.ensureOpen(user)).thenAnswer((_) => opened.future);
        final tx = connection.beginTransaction();
        final first = tx.ensureOpen(user);
        final second = tx.ensureOpen(user);
        await connection.runCustom('OUTSIDE');
        expect(entries.single.activeTransactionIdsAtStart, isEmpty);
        opened.complete(true);
        expect(await first, isTrue);
        expect(await second, isTrue);
        await connection.runCustom('OUTSIDE');
        expect(entries.last.activeTransactionIdsAtStart, [1]);
        expect(
          entries.where((entry) => entry.operation == 'transaction.open'),
          hasLength(1),
        );
        await tx.rollback();
      },
    );

    test('failed opening and rollback release their observations', () async {
      final failure = StateError('synthetic open failure');
      when(() => inner.ensureOpen(user)).thenAnswer((_) async => throw failure);
      final failed = connection.beginTransaction();
      await expectLater(failed.ensureOpen(user), throwsA(same(failure)));
      await failed.rollback();
      expect(
        entries.where((entry) => entry.operation == 'transaction'),
        isEmpty,
      );
      when(() => inner.ensureOpen(user)).thenAnswer((_) async => true);
      final tx = connection.beginTransaction();
      await tx.ensureOpen(user);
      when(inner.rollback).thenAnswer((_) async => throw failure);
      await expectLater(tx.rollback(), throwsA(same(failure)));
      await connection.runCustom('OUTSIDE');
      expect(entries.last.activeTransactionIdsAtStart, isEmpty);
      expect(
        entries
            .firstWhere((entry) => entry.operation == 'transaction')
            .statement,
        'ROLLBACK_FAILED',
      );
    });

    test(
      'native transaction delays an unrelated indexed read until commit',
      () async {
        final native = NativeDatabase.memory().interceptWith(
          SlowQueryInterceptor(
            databaseName: 'native_transaction',
            threshold: Duration.zero,
            reporter: entries.add,
          ),
        );
        addTearDown(native.close);
        await native.ensureOpen(user);
        await native.runCustom(
          'CREATE TABLE markers (id INTEGER PRIMARY KEY, value TEXT)',
        );
        final tx = native.beginTransaction();
        await tx.ensureOpen(user);
        await tx.runInsert('INSERT INTO markers VALUES (?, ?)', [
          1,
          'synthetic',
        ]);
        var completed = false;
        final read = native
            .runSelect('SELECT value FROM markers WHERE id = ?', [1])
            .then((rows) {
              completed = true;
              return rows;
            });
        await Future<void>.value();
        expect(completed, isFalse);
        await tx.send();
        expect(await read, [
          {'value': 'synthetic'},
        ]);
        final query = entries.firstWhere(
          (entry) => entry.operation == 'select',
        );
        expect(query.transactionId, isNull);
        expect(query.activeTransactionIdsAtStart, [1]);
        final span = entries.firstWhere(
          (entry) => entry.operation == 'transaction',
        );
        expect(span.scope, 'transactionLifetime');
        expect(span.transactionId, 1);
      },
    );

    test('disabled diagnostics preserve transaction delegation', () async {
      SlowQueryLoggingGate.isEnabled = false;
      final tx = connection.beginTransaction();
      expect(await tx.ensureOpen(user), isTrue);
      await tx.runCustom('INSIDE');
      await tx.send();
      expect(entries, isEmpty);
      verify(() => inner.runCustom('INSIDE', const [])).called(1);
      verify(inner.send).called(1);
    });

    test(
      'completed lifetimes retain their own origin and timing bounds',
      () async {
        SlowQueryLoggingGate.captureFirstCallStack = true;
        var now = DateTime.utc(2026, 9, 5, 12);
        final start = now;
        await withClock(Clock(() => now), () async {
          final tx = connection.beginTransaction();
          await tx.ensureOpen(user);
          now = now.add(const Duration(seconds: 4));
          await tx.send();
          final next = connection.beginTransaction();
          await next.ensureOpen(user);
          now = now.add(const Duration(seconds: 2));
          await next.rollback();
        });
        final spans = entries
            .where((entry) => entry.operation == 'transaction')
            .toList();
        expect(spans.map((entry) => entry.transactionId), [1, 2]);
        expect(spans.first.startedAt, start);
        expect(spans.first.completedAt, start.add(const Duration(seconds: 4)));
        expect(spans.last.startedAt, spans.first.completedAt);
        expect(spans.last.completedAt, now);
        final openings = entries
            .where((entry) => entry.operation == 'transaction.open')
            .toList();
        expect(spans.first.callerStack, same(openings.first.callerStack));
        expect(spans.last.callerStack, same(openings.last.callerStack));
        expect(
          spans.first.callerStack.toString(),
          isNot(spans.last.callerStack.toString()),
        );
        for (final span in spans) {
          expect(span.scope, 'transactionLifetime');
          expect(
            span.callerStack.toString(),
            contains('slow_query_logging_test.dart'),
          );
        }
      },
    );

    test(
      'turning logging off during a transaction still releases its observation',
      () async {
        final tx = connection.beginTransaction();
        await tx.ensureOpen(user);
        SlowQueryLoggingGate.isEnabled = false;
        await tx.send();
        SlowQueryLoggingGate.isEnabled = true;
        await connection.runCustom('OUTSIDE');
        expect(
          entries.where((entry) => entry.operation == 'transaction'),
          isEmpty,
        );
        expect(entries.last.activeTransactionIdsAtStart, isEmpty);
      },
    );

    test(
      'a lifetime reporter failure cannot undo a successful commit',
      () async {
        connection = parent.interceptWith(
          SlowQueryInterceptor(
            databaseName: 'lifetime_reporter',
            threshold: Duration.zero,
            reporter: (entry) {
              if (entry.operation == 'transaction') {
                throw StateError('lifetime report failed');
              }
              entries.add(entry);
            },
          ),
        );
        final tx = connection.beginTransaction();
        await tx.ensureOpen(user);
        await tx.send();
        await connection.runCustom('OUTSIDE');
        verify(inner.send).called(1);
        verifyNever(inner.rollback);
        expect(entries.last.activeTransactionIdsAtStart, isEmpty);
      },
    );
  });

  group('integration: interceptor + fileReporter end-to-end', () {
    late Directory tempDir;
    late MockQueryExecutor mockExecutor;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('slow_query_e2e_');
      mockExecutor = MockQueryExecutor();
    });

    tearDown(() async {
      resetSlowQueryLoggingGate();
      await SlowQueryInterceptor.flushPendingFileWrites();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('interceptor with fileReporter writes log on slow query', () async {
      SlowQueryLoggingGate.isEnabled = true;
      addTearDown(resetSlowQueryLoggingGate);

      final interceptor = SlowQueryInterceptor(
        databaseName: 'e2e_db',
        threshold: Duration.zero,
        reporter: SlowQueryInterceptor.fileReporter(
          documentsDirectoryPath: tempDir.path,
        ),
      );

      when(
        () => mockExecutor.runSelect(any(), any()),
      ).thenAnswer((_) async => <Map<String, Object?>>[]);

      await interceptor.runSelect(
        mockExecutor,
        'SELECT * FROM items WHERE id = ?',
        <Object?>[42],
      );

      await SlowQueryInterceptor.flushPendingFileWrites();

      final logsDir = Directory('${tempDir.path}/logs');
      expect(logsDir.existsSync(), isTrue);

      final logFiles = logsDir.listSync().whereType<File>().toList(
        growable: false,
      );
      expect(logFiles, hasLength(1));

      final content = logFiles.first.readAsStringSync();
      expect(content, contains('[e2e_db]'));
      expect(content, contains('select'));
      expect(content, contains('args=1'));
      expect(content, contains('SELECT * FROM items WHERE id = ?'));
    });

    test(
      'transaction file records distinguish lifetime from SQL and identify overlap',
      () async {
        final report = SlowQueryInterceptor.fileReporter(
          documentsDirectoryPath: tempDir.path,
        );
        report(
          SlowQueryLogEntry(
            databaseName: 'sync.sqlite',
            operation: 'transaction',
            statement: 'COMMIT',
            arguments: const [],
            elapsed: const Duration(seconds: 3),
            startedAt: DateTime.utc(2026, 9, 5, 12),
            completedAt: DateTime.utc(2026, 9, 5, 12, 0, 3),
            scope: 'transactionLifetime',
            transactionId: 2,
            parentTransactionId: 1,
            activeTransactionIdsAtStart: const [1, 2],
            isSuperSlow: true,
          ),
        );
        await SlowQueryInterceptor.flushPendingFileWrites();
        final files = Directory(
          '${tempDir.path}/logs',
        ).listSync().whereType<File>().toList();
        expect(files, hasLength(2));
        for (final file in files) {
          final text = file.readAsStringSync();
          expect(text, contains('transaction 3000.000ms'));
          expect(text, contains('TIMING: scope=transactionLifetime'));
          expect(
            text,
            contains('TRANSACTION: id=2 parent=1 activeAtStart=[1, 2]'),
          );
          expect(text, isNot(contains('scope=executorAwait')));
        }
      },
    );
  });
}
