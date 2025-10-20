import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    test('copyWith supports language code', () {
      final taskData = TaskData(
        status: testStatus,
        dateFrom: testDate,
        dateTo: testDate,
        statusHistory: [],
        title: 'Test Task',
        languageCode: 'es',
      );

      // Test that languageCode is preserved
      final copiedTaskData = taskData.copyWith();
      expect(copiedTaskData.languageCode, equals('es'));
    });

    test('equality with language code', () {
      final taskData1 = TaskData(
        status: testStatus,
        dateFrom: testDate,
        dateTo: testDate,
        statusHistory: [],
        title: 'Test Task',
        languageCode: 'fr',
      );

      final taskData2 = TaskData(
        status: testStatus,
        dateFrom: testDate,
        dateTo: testDate,
        statusHistory: [],
        title: 'Test Task',
        languageCode: 'fr',
      );

      expect(taskData1, equals(taskData2));
    });

    test('copyWith preserves language code', () {
      final taskData = TaskData(
        status: testStatus,
        dateFrom: testDate,
        dateTo: testDate,
        statusHistory: [],
        title: 'Test Task',
        languageCode: 'fr',
      );

      final copiedTaskData = taskData.copyWith(
        title: 'Updated Task',
      );

      expect(copiedTaskData.languageCode, equals('fr'));
      expect(copiedTaskData.title, equals('Updated Task'));
    });

    test('copyWith can update language code', () {
      final taskData = TaskData(
        status: testStatus,
        dateFrom: testDate,
        dateTo: testDate,
        statusHistory: [],
        title: 'Test Task',
        languageCode: 'en',
      );

      final copiedTaskData = taskData.copyWith(
        languageCode: 'de',
      );

      expect(copiedTaskData.languageCode, equals('de'));
      expect(copiedTaskData.title, equals('Test Task'));
    });

    test('copyWith can clear language code', () {
      final taskData = TaskData(
        status: testStatus,
        dateFrom: testDate,
        dateTo: testDate,
        statusHistory: [],
        title: 'Test Task',
        languageCode: 'en',
      );

      // Note: In freezed, to set a nullable field to null in copyWith,
      // you need to use a special syntax
      final copiedTaskData = taskData.copyWith(
        languageCode: null,
      );

      expect(copiedTaskData.languageCode, isNull);
    });
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

  group('TaskStatusExtension - colorForBrightness', () {
    late DateTime testDate;

    setUp(() {
      testDate = DateTime(2024);
    });

    group('Light mode colors', () {
      test('Open status returns dark orange in light mode', () {
        final status = TaskStatus.open(
          id: 'test',
          createdAt: testDate,
          utcOffset: 0,
        );
        expect(
          status.colorForBrightness(Brightness.light),
          equals(const Color(0xFFE65100)),
        );
      });

      test('Groomed status returns dark green in light mode', () {
        final status = TaskStatus.groomed(
          id: 'test',
          createdAt: testDate,
          utcOffset: 0,
        );
        expect(
          status.colorForBrightness(Brightness.light),
          equals(const Color(0xFF2E7D32)),
        );
      });

      test('InProgress status returns dark blue in light mode', () {
        final status = TaskStatus.inProgress(
          id: 'test',
          createdAt: testDate,
          utcOffset: 0,
        );
        expect(
          status.colorForBrightness(Brightness.light),
          equals(const Color(0xFF1565C0)),
        );
      });

      test('Blocked status returns dark red in light mode', () {
        final status = TaskStatus.blocked(
          id: 'test',
          createdAt: testDate,
          utcOffset: 0,
          reason: 'test reason',
        );
        expect(
          status.colorForBrightness(Brightness.light),
          equals(const Color(0xFFC62828)),
        );
      });

      test('OnHold status returns dark red in light mode', () {
        final status = TaskStatus.onHold(
          id: 'test',
          createdAt: testDate,
          utcOffset: 0,
          reason: 'test reason',
        );
        expect(
          status.colorForBrightness(Brightness.light),
          equals(const Color(0xFFC62828)),
        );
      });

      test('Done status returns dark green in light mode', () {
        final status = TaskStatus.done(
          id: 'test',
          createdAt: testDate,
          utcOffset: 0,
        );
        expect(
          status.colorForBrightness(Brightness.light),
          equals(const Color(0xFF2E7D32)),
        );
      });

      test('Rejected status returns dark red in light mode', () {
        final status = TaskStatus.rejected(
          id: 'test',
          createdAt: testDate,
          utcOffset: 0,
        );
        expect(
          status.colorForBrightness(Brightness.light),
          equals(const Color(0xFFC62828)),
        );
      });
    });

    group('Dark mode colors', () {
      test('Open status returns bright orange in dark mode', () {
        final status = TaskStatus.open(
          id: 'test',
          createdAt: testDate,
          utcOffset: 0,
        );
        expect(
          status.colorForBrightness(Brightness.dark),
          equals(Colors.orange),
        );
      });

      test('Groomed status returns light green accent in dark mode', () {
        final status = TaskStatus.groomed(
          id: 'test',
          createdAt: testDate,
          utcOffset: 0,
        );
        expect(
          status.colorForBrightness(Brightness.dark),
          equals(Colors.lightGreenAccent),
        );
      });

      test('InProgress status returns blue in dark mode', () {
        final status = TaskStatus.inProgress(
          id: 'test',
          createdAt: testDate,
          utcOffset: 0,
        );
        expect(
          status.colorForBrightness(Brightness.dark),
          equals(Colors.blue),
        );
      });

      test('Blocked status returns red in dark mode', () {
        final status = TaskStatus.blocked(
          id: 'test',
          createdAt: testDate,
          utcOffset: 0,
          reason: 'test reason',
        );
        expect(
          status.colorForBrightness(Brightness.dark),
          equals(Colors.red),
        );
      });

      test('OnHold status returns red in dark mode', () {
        final status = TaskStatus.onHold(
          id: 'test',
          createdAt: testDate,
          utcOffset: 0,
          reason: 'test reason',
        );
        expect(
          status.colorForBrightness(Brightness.dark),
          equals(Colors.red),
        );
      });

      test('Done status returns green in dark mode', () {
        final status = TaskStatus.done(
          id: 'test',
          createdAt: testDate,
          utcOffset: 0,
        );
        expect(
          status.colorForBrightness(Brightness.dark),
          equals(Colors.green),
        );
      });

      test('Rejected status returns red in dark mode', () {
        final status = TaskStatus.rejected(
          id: 'test',
          createdAt: testDate,
          utcOffset: 0,
        );
        expect(
          status.colorForBrightness(Brightness.dark),
          equals(Colors.red),
        );
      });
    });

    group('Backward compatibility', () {
      test('color getter defaults to dark mode colors', () {
        final status = TaskStatus.groomed(
          id: 'test',
          createdAt: testDate,
          utcOffset: 0,
        );
        expect(status.color, equals(Colors.lightGreenAccent));
      });

      test('color getter returns dark mode orange for open status', () {
        final status = TaskStatus.open(
          id: 'test',
          createdAt: testDate,
          utcOffset: 0,
        );
        expect(status.color, equals(Colors.orange));
      });

      test('color getter returns dark mode blue for in progress status', () {
        final status = TaskStatus.inProgress(
          id: 'test',
          createdAt: testDate,
          utcOffset: 0,
        );
        expect(status.color, equals(Colors.blue));
      });
    });
  });
}
