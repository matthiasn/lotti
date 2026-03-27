import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/state/tasks_count_controller.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  group('TasksCountController', () {
    late MockJournalDb mockJournalDb;
    late MockUpdateNotifications mockNotifications;
    late StreamController<Set<String>> updateStreamController;

    setUp(() async {
      final mocks = await setUpTestGetIt();
      mockJournalDb = mocks.journalDb;
      mockNotifications = mocks.updateNotifications;
      updateStreamController = StreamController<Set<String>>.broadcast();

      when(
        () => mockNotifications.updateStream,
      ).thenAnswer((_) => updateStreamController.stream);
    });

    tearDown(() async {
      await updateStreamController.close();
      await tearDownTestGetIt();
    });

    test('initial build returns correct count from JournalDb', () async {
      when(mockJournalDb.getTasksCount).thenAnswer((_) async => 5);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final count = await container.read(
        tasksCountControllerProvider.future,
      );

      expect(count, 5);
      verify(mockJournalDb.getTasksCount).called(1);
    });

    test(
      'updates state when update stream emits with taskNotification',
      () async {
        var callCount = 0;

        when(mockJournalDb.getTasksCount).thenAnswer((_) async {
          callCount++;
          return callCount == 1 ? 3 : 7;
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

        final firstCount = await container.read(
          tasksCountControllerProvider.future,
        );
        expect(firstCount, 3);

        // Emit a notification with taskNotification ID
        updateStreamController.add({taskNotification});

        // Allow microtasks to process
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final secondCount = await container.read(
          tasksCountControllerProvider.future,
        );
        expect(secondCount, 7);
        verify(mockJournalDb.getTasksCount).called(2);
      },
    );

    test(
      'does not update state when update stream emits without relevant IDs',
      () async {
        when(mockJournalDb.getTasksCount).thenAnswer((_) async => 10);

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await container.read(tasksCountControllerProvider.future);

        // Emit a notification with an unrelated ID
        updateStreamController.add({'some-unrelated-id'});

        // Allow microtasks to process
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Should only have been called once during initial build
        verify(mockJournalDb.getTasksCount).called(1);
      },
    );
  });
}
