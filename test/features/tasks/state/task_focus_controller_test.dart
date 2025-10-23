import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/state/task_focus_controller.dart';

void main() {
  late ProviderContainer container;

  const testTaskId = 'test-task-id';
  const testEntryId = 'test-entry-id';

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('TaskFocusIntent', () {
    test('creates intent with required fields', () {
      final intent = TaskFocusIntent(
        taskId: testTaskId,
        entryId: testEntryId,
      );

      expect(intent.taskId, equals(testTaskId));
      expect(intent.entryId, equals(testEntryId));
      expect(intent.alignment, equals(0.0));
    });

    test('creates intent with custom alignment', () {
      final intent = TaskFocusIntent(
        taskId: testTaskId,
        entryId: testEntryId,
        alignment: 0.5,
      );

      expect(intent.alignment, equals(0.5));
    });

    test('toString returns formatted string', () {
      final intent = TaskFocusIntent(
        taskId: testTaskId,
        entryId: testEntryId,
        alignment: 0.25,
      );

      expect(
        intent.toString(),
        equals(
          'TaskFocusIntent(taskId: $testTaskId, entryId: $testEntryId, alignment: 0.25)',
        ),
      );
    });
  });

  group('TaskFocusController', () {
    test('initial state is null', () {
      final provider = taskFocusControllerProvider(id: testTaskId);
      final state = container.read(provider);

      expect(state, isNull);
    });

    test('publishTaskFocus sets intent', () {
      final provider = taskFocusControllerProvider(id: testTaskId);

      container.read(provider.notifier).publishTaskFocus(
            entryId: testEntryId,
          );

      final state = container.read(provider);
      expect(state, isNotNull);
      expect(state!.taskId, equals(testTaskId));
      expect(state.entryId, equals(testEntryId));
      expect(state.alignment, equals(0.0));
    });

    test('publishTaskFocus with custom alignment', () {
      final provider = taskFocusControllerProvider(id: testTaskId);

      container.read(provider.notifier).publishTaskFocus(
            entryId: testEntryId,
            alignment: 0.5,
          );

      final state = container.read(provider);
      expect(state!.alignment, equals(0.5));
    });

    test('clearIntent resets state to null', () {
      final provider = taskFocusControllerProvider(id: testTaskId);
      final notifier = container.read(provider.notifier)
        ..publishTaskFocus(
          entryId: testEntryId,
        );

      // Verify intent was set
      expect(container.read(provider), isNotNull);

      // Clear intent
      notifier.clearIntent();

      // Verify intent is cleared
      final state = container.read(provider);
      expect(state, isNull);
    });

    test('multiple publish calls update the intent', () {
      final provider = taskFocusControllerProvider(id: testTaskId);
      final notifier = container.read(provider.notifier)
        ..publishTaskFocus(
          entryId: 'entry1',
        );

      expect(container.read(provider)!.entryId, equals('entry1'));

      // Second publish
      notifier.publishTaskFocus(
        entryId: 'entry2',
      );

      expect(container.read(provider)!.entryId, equals('entry2'));
    });

    test('re-trigger after clearIntent works', () {
      final provider = taskFocusControllerProvider(id: testTaskId);
      final notifier = container.read(provider.notifier)
        ..publishTaskFocus(
          entryId: testEntryId,
        );

      expect(container.read(provider), isNotNull);

      // Clear intent
      notifier.clearIntent();
      expect(container.read(provider), isNull);

      // Re-trigger with same values should work
      notifier.publishTaskFocus(
        entryId: testEntryId,
      );

      final state = container.read(provider);
      expect(state, isNotNull);
      expect(state!.entryId, equals(testEntryId));
    });

    test('different task IDs have independent state', () {
      const taskId1 = 'task-1';
      const taskId2 = 'task-2';

      final provider1 = taskFocusControllerProvider(id: taskId1);
      final provider2 = taskFocusControllerProvider(id: taskId2);

      container.read(provider1.notifier).publishTaskFocus(
            entryId: 'entry1',
          );

      container.read(provider2.notifier).publishTaskFocus(
            entryId: 'entry2',
          );

      // Verify each has its own state
      expect(container.read(provider1)!.entryId, equals('entry1'));
      expect(container.read(provider2)!.entryId, equals('entry2'));

      // Clear task1
      container.read(provider1.notifier).clearIntent();

      // Verify only task1 is cleared
      expect(container.read(provider1), isNull);
      expect(container.read(provider2)!.entryId, equals('entry2'));
    });
  });
}
