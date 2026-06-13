import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:glados/glados.dart' show AnyUtils, ExploreConfig, Glados, any;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';

void main() {
  group('TaskData', () {
    late DateTime testDate;
    late TaskStatus testStatus;

    setUp(() {
      testDate = DateTime(2024);
      testStatus = TaskStatus.open(
        id: 'status-1',
        createdAt: testDate,
        utcOffset: 0,
      );
    });

    test('creates TaskData with language code', () {
      final taskData = TaskData(
        status: testStatus,
        dateFrom: testDate,
        dateTo: testDate,
        statusHistory: [],
        title: 'Test Task',
        languageCode: 'de',
      );

      expect(taskData.languageCode, equals('de'));
      expect(taskData.title, equals('Test Task'));
      expect(taskData.status, equals(testStatus));
    });

    test('creates TaskData without language code', () {
      final taskData = TaskData(
        status: testStatus,
        dateFrom: testDate,
        dateTo: testDate,
        statusHistory: [],
        title: 'Test Task',
      );

      expect(taskData.languageCode, isNull);
      expect(taskData.title, equals('Test Task'));
    });

    TaskData makeTask({String? languageCode}) => TaskData(
      status: testStatus,
      dateFrom: testDate,
      dateTo: testDate,
      statusHistory: [],
      title: 'Test Task',
      languageCode: languageCode,
    );

    // The copyWith languageCode contract, parameterized over (initial code,
    // copyWith arguments, expected code after the copy).
    for (final (description, initial, copy, expectedCode) in [
      (
        'copyWith() preserves the language code',
        'es',
        (TaskData d) => d.copyWith(),
        'es',
      ),
      (
        'copyWith(title: ...) leaves the language code untouched',
        'fr',
        (TaskData d) => d.copyWith(title: 'Updated Task'),
        'fr',
      ),
      (
        'copyWith(languageCode: ...) updates the language code',
        'en',
        (TaskData d) => d.copyWith(languageCode: 'de'),
        'de',
      ),
      (
        'copyWith(languageCode: null) clears the language code',
        'en',
        (TaskData d) => d.copyWith(languageCode: null),
        null,
      ),
    ]) {
      test(description, () {
        final copied = copy(makeTask(languageCode: initial));
        expect(copied.languageCode, expectedCode);
        // Untouched fields survive every copy.
        expect(copied.status, testStatus);
        expect(copied.dateFrom, testDate);
      });
    }

    test('equality with language code', () {
      expect(makeTask(languageCode: 'fr'), makeTask(languageCode: 'fr'));
      expect(
        makeTask(languageCode: 'fr'),
        isNot(makeTask(languageCode: 'de')),
      );
    });
  });

  group('TaskStatus.colorForBrightness', () {
    // Dark-mode status colors (moved from test/utils/task_utils_test.dart —
    // colorForBrightness lives on TaskStatus in lib/classes/task.dart).
    for (final (status, expected) in [
      (
        TaskStatus.open(
          id: 'id',
          createdAt: DateTime(2024, 3, 15),
          utcOffset: 120,
        ),
        Colors.orange,
      ),
      (
        TaskStatus.groomed(
          id: 'id',
          createdAt: DateTime(2024, 3, 15),
          utcOffset: 120,
        ),
        Colors.lightGreenAccent,
      ),
      (
        TaskStatus.inProgress(
          id: 'id',
          createdAt: DateTime(2024, 3, 15),
          utcOffset: 120,
        ),
        Colors.blue,
      ),
      (
        TaskStatus.blocked(
          id: 'id',
          createdAt: DateTime(2024, 3, 15),
          utcOffset: 120,
          reason: '',
        ),
        Colors.red,
      ),
      (
        TaskStatus.onHold(
          id: 'id',
          createdAt: DateTime(2024, 3, 15),
          utcOffset: 120,
          reason: '',
        ),
        Colors.red,
      ),
      (
        TaskStatus.done(
          id: 'id',
          createdAt: DateTime(2024, 3, 15),
          utcOffset: 120,
        ),
        Colors.green,
      ),
      (
        TaskStatus.rejected(
          id: 'id',
          createdAt: DateTime(2024, 3, 15),
          utcOffset: 120,
        ),
        Colors.red,
      ),
    ]) {
      test('${status.runtimeType} maps to its dark-mode color', () {
        expect(status.colorForBrightness(Brightness.dark), expected);
      });
    }
  });

  group('Task entity', () {
    late DateTime testDate;
    late Metadata testMetadata;
    late TaskStatus testStatus;

    setUp(() {
      testDate = DateTime(2024);
      testMetadata = Metadata(
        id: 'task-1',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
      );
      testStatus = TaskStatus.open(
        id: 'status-1',
        createdAt: testDate,
        utcOffset: 0,
      );
    });

    test('creates Task with language code in data', () {
      final task = Task(
        meta: testMetadata,
        data: TaskData(
          status: testStatus,
          dateFrom: testDate,
          dateTo: testDate,
          statusHistory: [],
          title: 'Test Task',
          languageCode: 'ja',
        ),
      );

      expect(task.data.languageCode, equals('ja'));
      expect(task.meta.id, equals('task-1'));
    });

    test('copyWith preserves language code in task data', () {
      final task = Task(
        meta: testMetadata,
        data: TaskData(
          status: testStatus,
          dateFrom: testDate,
          dateTo: testDate,
          statusHistory: [],
          title: 'Test Task',
          languageCode: 'ko',
        ),
      );

      final updatedTask = task.copyWith(
        data: task.data.copyWith(
          title: 'Updated Title',
        ),
      );

      expect(updatedTask.data.languageCode, equals('ko'));
      expect(updatedTask.data.title, equals('Updated Title'));
    });
  });

  group('taskStatusFromString', () {
    // Each branch maps a string to the correct TaskStatus subtype and the
    // toDbString round-trip returns the canonical DB string.
    final cases = <(String, Type, String)>[
      ('DONE', TaskDone, 'DONE'),
      ('GROOMED', TaskGroomed, 'GROOMED'),
      ('IN PROGRESS', TaskInProgress, 'IN PROGRESS'),
      ('BLOCKED', TaskBlocked, 'BLOCKED'),
      ('ON HOLD', TaskOnHold, 'ON HOLD'),
      ('REJECTED', TaskRejected, 'REJECTED'),
      ('OPEN', TaskOpen, 'OPEN'),
      ('anything else', TaskOpen, 'OPEN'),
    ];

    for (final (input, expectedType, expectedDb) in cases) {
      test('parses "$input" → $expectedType, toDbString == "$expectedDb"', () {
        final status = taskStatusFromString(input);
        expect(status.runtimeType, equals(expectedType));
        expect(status.toDbString, equals(expectedDb));
      });
    }

    test('BLOCKED result carries default reason', () {
      final status = taskStatusFromString('BLOCKED') as TaskBlocked;
      expect(status.reason, equals('needs a reason'));
    });

    test('ON HOLD result carries default reason', () {
      final status = taskStatusFromString('ON HOLD') as TaskOnHold;
      expect(status.reason, equals('needs a reason'));
    });
  });

  group('taskStatusFromString / toDbString round-trip (glados)', () {
    final knownInputs = [
      'DONE',
      'GROOMED',
      'IN PROGRESS',
      'BLOCKED',
      'ON HOLD',
      'REJECTED',
      'OPEN',
    ];

    Glados(any.choose(knownInputs), ExploreConfig(numRuns: 50)).test(
      'toDbString is the canonical form for known statuses',
      (input) {
        final status = taskStatusFromString(input);
        // The DB string must equal the input for the canonical set.
        expect(status.toDbString, equals(input));
      },
      tags: 'glados',
    );
  });
}
