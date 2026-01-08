import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/state/linked_tasks_controller.dart';

void main() {
  group('LinkedTasksController', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state has manageMode as false', () {
      final state = container.read(
        linkedTasksControllerProvider(taskId: 'task-1'),
      );

      expect(state.manageMode, isFalse);
    });

    test('toggleManageMode toggles manageMode state', () {
      final notifier = container.read(
        linkedTasksControllerProvider(taskId: 'task-1').notifier,
      );

      // Initially false
      expect(
        container
            .read(linkedTasksControllerProvider(taskId: 'task-1'))
            .manageMode,
        isFalse,
      );

      // Toggle to true
      notifier.toggleManageMode();
      expect(
        container
            .read(linkedTasksControllerProvider(taskId: 'task-1'))
            .manageMode,
        isTrue,
      );

      // Toggle back to false
      notifier.toggleManageMode();
      expect(
        container
            .read(linkedTasksControllerProvider(taskId: 'task-1'))
            .manageMode,
        isFalse,
      );
    });

    test('exitManageMode sets manageMode to false', () {
      final notifier = container.read(
        linkedTasksControllerProvider(taskId: 'task-1').notifier,
      )

        // Enable manage mode first
        ..toggleManageMode();
      expect(
        container
            .read(linkedTasksControllerProvider(taskId: 'task-1'))
            .manageMode,
        isTrue,
      );

      // Exit manage mode
      notifier.exitManageMode();
      expect(
        container
            .read(linkedTasksControllerProvider(taskId: 'task-1'))
            .manageMode,
        isFalse,
      );
    });

    test('exitManageMode does nothing when manageMode is already false', () {
      final notifier = container.read(
        linkedTasksControllerProvider(taskId: 'task-1').notifier,
      );

      // Initially false
      expect(
        container
            .read(linkedTasksControllerProvider(taskId: 'task-1'))
            .manageMode,
        isFalse,
      );

      // Exit manage mode (no-op)
      notifier.exitManageMode();
      expect(
        container
            .read(linkedTasksControllerProvider(taskId: 'task-1'))
            .manageMode,
        isFalse,
      );
    });

    test('different taskIds have independent state', () {
      final notifier1 = container.read(
        linkedTasksControllerProvider(taskId: 'task-1').notifier,
      );
      final notifier2 = container.read(
        linkedTasksControllerProvider(taskId: 'task-2').notifier,
      );

      // Toggle manageMode on task-1
      notifier1.toggleManageMode();

      // task-2 should remain unaffected
      final state1 = container.read(
        linkedTasksControllerProvider(taskId: 'task-1'),
      );
      final state2 = container.read(
        linkedTasksControllerProvider(taskId: 'task-2'),
      );

      expect(state1.manageMode, isTrue);
      expect(state2.manageMode, isFalse);

      // Now toggle task-2
      notifier2.toggleManageMode();

      final state1After = container.read(
        linkedTasksControllerProvider(taskId: 'task-1'),
      );
      final state2After = container.read(
        linkedTasksControllerProvider(taskId: 'task-2'),
      );

      expect(state1After.manageMode, isTrue);
      expect(state2After.manageMode, isTrue);
    });
  });

  group('LinkedTasksState', () {
    test('copyWith creates new instance with updated values', () {
      const state = LinkedTasksState();

      final updated = state.copyWith(manageMode: true);

      expect(updated.manageMode, isTrue);
      expect(state.manageMode, isFalse); // Original unchanged
    });

    test('default factory creates state with all defaults', () {
      const state = LinkedTasksState();

      expect(state.manageMode, isFalse);
    });

    test('equality works correctly', () {
      const state1 = LinkedTasksState();
      const state2 = LinkedTasksState();
      const state3 = LinkedTasksState(manageMode: true);

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });
  });
}
