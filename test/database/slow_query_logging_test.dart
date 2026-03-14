import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/slow_query_logging.dart';
import 'package:mocktail/mocktail.dart';

class MockQueryExecutor extends Mock implements QueryExecutor {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      BatchedStatements(<String>[], <ArgumentsForBatchedStatement>[]),
    );
  });

  group('SlowQueryLoggingGate', () {
    tearDown(SlowQueryLoggingGate.resetForTest);

    test('defaults to disabled', () {
      expect(SlowQueryLoggingGate.isEnabled, isFalse);
    });

    test('can be enabled', () {
      SlowQueryLoggingGate.isEnabled = true;
      addTearDown(SlowQueryLoggingGate.resetForTest);

      expect(SlowQueryLoggingGate.isEnabled, isTrue);
    });

    test('resetForTest sets isEnabled back to false', () {
      SlowQueryLoggingGate.isEnabled = true;
      SlowQueryLoggingGate.resetForTest();

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

    tearDown(SlowQueryLoggingGate.resetForTest);

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
        addTearDown(SlowQueryLoggingGate.resetForTest);
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
        addTearDown(SlowQueryLoggingGate.resetForTest);

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
        addTearDown(SlowQueryLoggingGate.resetForTest);

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
        addTearDown(SlowQueryLoggingGate.resetForTest);

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
  });

  group('fileReporter', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('slow_query_test_');
    });

    tearDown(() async {
      SlowQueryLoggingGate.resetForTest();
      await SlowQueryInterceptor.flushFileSinkForTest();
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
      await SlowQueryInterceptor.flushFileSinkForTest();

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
      await SlowQueryInterceptor.flushFileSinkForTest();

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

      await SlowQueryInterceptor.flushFileSinkForTest();

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

      await SlowQueryInterceptor.flushFileSinkForTest();

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
      await SlowQueryInterceptor.flushFileSinkForTest();

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
  });

  group('integration: interceptor + fileReporter end-to-end', () {
    late Directory tempDir;
    late MockQueryExecutor mockExecutor;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('slow_query_e2e_');
      mockExecutor = MockQueryExecutor();
    });

    tearDown(() async {
      SlowQueryLoggingGate.resetForTest();
      await SlowQueryInterceptor.flushFileSinkForTest();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('interceptor with fileReporter writes log on slow query', () async {
      SlowQueryLoggingGate.isEnabled = true;
      addTearDown(SlowQueryLoggingGate.resetForTest);

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

      await SlowQueryInterceptor.flushFileSinkForTest();

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
  });
}
