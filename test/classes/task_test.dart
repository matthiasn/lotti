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
}
