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
    test('initial state is null', () async {
      final provider = taskFocusControllerProvider(id: testTaskId);
      final state = await container.read(provider.future);

      expect(state, isNull);
    });

    test('publishTaskFocus sets intent', () async {
      final provider = taskFocusControllerProvider(id: testTaskId);

      container.read(provider.notifier).publishTaskFocus(
            taskId: testTaskId,
            entryId: testEntryId,
          );

      final state = container.read(provider);
      expect(state.value, isNotNull);
      expect(state.value!.taskId, equals(testTaskId));
      expect(state.value!.entryId, equals(testEntryId));
      expect(state.value!.alignment, equals(0.0));
    });

    test('publishTaskFocus with custom alignment', () async {
      final provider = taskFocusControllerProvider(id: testTaskId);

      container.read(provider.notifier).publishTaskFocus(
            taskId: testTaskId,
            entryId: testEntryId,
            alignment: 0.5,
          );

      final state = container.read(provider);
      expect(state.value!.alignment, equals(0.5));
    });

    test('clearIntent resets state to null', () async {
      final provider = taskFocusControllerProvider(id: testTaskId);
      final notifier = container.read(provider.notifier)
        ..publishTaskFocus(
          taskId: testTaskId,
          entryId: testEntryId,
        );

      // Verify intent was set
      expect(container.read(provider).value, isNotNull);

      // Clear intent
      notifier.clearIntent();

      // Verify intent is cleared
      final state = container.read(provider);
      expect(state.value, isNull);
    });

    test('multiple publish calls update the intent', () async {
      final provider = taskFocusControllerProvider(id: testTaskId);
      final notifier = container.read(provider.notifier)
        ..publishTaskFocus(
          taskId: testTaskId,
          entryId: 'entry1',
        );

      expect(container.read(provider).value!.entryId, equals('entry1'));

      // Second publish
      notifier.publishTaskFocus(
        taskId: testTaskId,
        entryId: 'entry2',
      );

      expect(container.read(provider).value!.entryId, equals('entry2'));
    });

    test('re-trigger after clearIntent works', () async {
      final provider = taskFocusControllerProvider(id: testTaskId);
      final notifier = container.read(provider.notifier)
        ..publishTaskFocus(
          taskId: testTaskId,
          entryId: testEntryId,
        );

      expect(container.read(provider).value, isNotNull);

      // Clear intent
      notifier.clearIntent();
      expect(container.read(provider).value, isNull);

      // Re-trigger with same values should work
      notifier.publishTaskFocus(
        taskId: testTaskId,
        entryId: testEntryId,
      );

      final state = container.read(provider);
      expect(state.value, isNotNull);
      expect(state.value!.entryId, equals(testEntryId));
    });

    test('different task IDs have independent state', () async {
      const taskId1 = 'task-1';
      const taskId2 = 'task-2';

      final provider1 = taskFocusControllerProvider(id: taskId1);
      final provider2 = taskFocusControllerProvider(id: taskId2);

      container.read(provider1.notifier).publishTaskFocus(
            taskId: taskId1,
            entryId: 'entry1',
          );

      container.read(provider2.notifier).publishTaskFocus(
            taskId: taskId2,
            entryId: 'entry2',
          );

      // Verify each has its own state
      expect(container.read(provider1).value!.entryId, equals('entry1'));
      expect(container.read(provider2).value!.entryId, equals('entry2'));

      // Clear task1
      container.read(provider1.notifier).clearIntent();

      // Verify only task1 is cleared
      expect(container.read(provider1).value, isNull);
      expect(container.read(provider2).value!.entryId, equals('entry2'));
    });
  });
}
