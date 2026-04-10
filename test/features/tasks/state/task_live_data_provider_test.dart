import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/tasks/state/task_live_data_provider.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/entity_factories.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  group('taskLiveDataProvider', () {
    late MockJournalDb mockDb;
    late StreamController<Set<String>> updateController;

    setUp(() async {
      updateController = StreamController<Set<String>>.broadcast();
      addTearDown(updateController.close);

      final mockNotifications = MockUpdateNotifications();
      when(() => mockNotifications.updateStream).thenAnswer(
        (_) => updateController.stream,
      );

      await setUpTestGetIt(
        additionalSetup: () {
          // setUpTestGetIt already registers JournalDb and UpdateNotifications,
          // but we need to re-register with our custom mocks.
        },
      );

      // Grab the mock JournalDb that setUpTestGetIt registered.
      mockDb = getIt<JournalDb>() as MockJournalDb;

      // Replace UpdateNotifications with our stream-backed mock.
      getIt
        ..unregister<UpdateNotifications>()
        ..registerSingleton<UpdateNotifications>(mockNotifications);
    });

    tearDown(tearDownTestGetIt);

    test('returns task when DB has a Task entity', () async {
      const taskId = 'task-exists';
      final task = TestTaskFactory.create(
        id: taskId,
        title: 'Existing Task',
        dateFrom: DateTime(2024, 3, 15),
      );

      when(() => mockDb.journalEntityById(taskId)).thenAnswer(
        (_) async => task,
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        taskLiveDataProvider(taskId).future,
      );

      expect(result, task);
      expect(result?.data.title, 'Existing Task');
    });

    test('returns null when DB returns null', () async {
      const taskId = 'missing-entity';

      when(() => mockDb.journalEntityById(taskId)).thenAnswer(
        (_) async => null,
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        taskLiveDataProvider(taskId).future,
      );

      expect(result, isNull);
    });

    test('returns null when DB entity is not a Task', () async {
      const taskId = 'journal-entry';
      final nonTaskEntity = JournalEntity.journalEntry(
        meta: TestMetadataFactory.create(id: taskId),
      );

      when(() => mockDb.journalEntityById(taskId)).thenAnswer(
        (_) async => nonTaskEntity,
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = await container.read(
        taskLiveDataProvider(taskId).future,
      );

      expect(result, isNull);
    });

    test(
      'invalidates and re-fetches when update notification arrives',
      () async {
        const taskId = 'task-updated';
        final originalTask = TestTaskFactory.create(
          id: taskId,
          title: 'Original Title',
          dateFrom: DateTime(2024, 3, 15),
        );
        final updatedTask = TestTaskFactory.create(
          id: taskId,
          title: 'Updated Title',
          dateFrom: DateTime(2024, 3, 15),
        );

        var callCount = 0;
        when(() => mockDb.journalEntityById(taskId)).thenAnswer((_) async {
          callCount++;
          return callCount == 1 ? originalTask : updatedTask;
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

        // First read: returns original.
        final first = await container.read(
          taskLiveDataProvider(taskId).future,
        );
        expect(first?.data.title, 'Original Title');

        // Keep the provider alive so the stream listener stays active.
        final sub = container.listen(
          taskLiveDataProvider(taskId),
          (_, _) {},
        );
        addTearDown(sub.close);

        // Emit an update notification containing the task ID.
        updateController.add({taskId});

        // Riverpod provider revalidation via invalidateSelf() inside a real
        // stream listener cannot be driven by fakeAsync — the stream
        // subscription and provider rebuild cross microtask boundaries that
        // require real async scheduling (same pattern as
        // wake_orchestrator_test.dart for real async stream operations).
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final second = await container.read(
          taskLiveDataProvider(taskId).future,
        );
        expect(second?.data.title, 'Updated Title');
        expect(callCount, 2);
      },
    );

    test('ignores update notifications for other task IDs', () async {
      const taskId = 'task-mine';
      final task = TestTaskFactory.create(
        id: taskId,
        title: 'My Task',
        dateFrom: DateTime(2024, 3, 15),
      );

      var callCount = 0;
      when(() => mockDb.journalEntityById(taskId)).thenAnswer((_) async {
        callCount++;
        return task;
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(taskLiveDataProvider(taskId).future);
      expect(callCount, 1);

      final sub = container.listen(
        taskLiveDataProvider(taskId),
        (_, _) {},
      );
      addTearDown(sub.close);

      // Emit notification for a different task — should NOT trigger re-fetch.
      updateController.add({'other-task-id'});
      // See comment above re: real async requirement for stream-driven
      // provider revalidation.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(callCount, 1);
    });
  });
}
