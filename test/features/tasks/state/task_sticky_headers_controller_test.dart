import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/state/task_sticky_headers_controller.dart';

void main() {
  group('TaskStickyHeadersController', () {
    late ProviderContainer container;
    late TaskStickyHeadersController controller;
    const testTaskId = 'test-task-123';

    setUp(() {
      container = ProviderContainer();
      controller = container.read(
        taskStickyHeadersControllerProvider(testTaskId).notifier,
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state should have all headers invisible', () {
      final state = container.read(
        taskStickyHeadersControllerProvider(testTaskId),
      );

      expect(state.isTaskHeaderVisible, false);
      expect(state.isAiSummaryVisible, false);
      expect(state.isChecklistsVisible, false);
      expect(state.scrollOffset, 0.0);
    });

    test('updateScrollOffset should update visibility based on thresholds', () {
      // Test task header threshold (100.0)
      controller.updateScrollOffset(50.0);
      var state = container.read(
        taskStickyHeadersControllerProvider(testTaskId),
      );
      expect(state.isTaskHeaderVisible, false);
      expect(state.isAiSummaryVisible, false);
      expect(state.isChecklistsVisible, false);
      expect(state.scrollOffset, 50.0);

      // Cross task header threshold
      controller.updateScrollOffset(150.0);
      state = container.read(
        taskStickyHeadersControllerProvider(testTaskId),
      );
      expect(state.isTaskHeaderVisible, true);
      expect(state.isAiSummaryVisible, false);
      expect(state.isChecklistsVisible, false);
      expect(state.scrollOffset, 150.0);

      // Cross AI summary threshold (300.0)
      controller.updateScrollOffset(350.0);
      state = container.read(
        taskStickyHeadersControllerProvider(testTaskId),
      );
      expect(state.isTaskHeaderVisible, true);
      expect(state.isAiSummaryVisible, true);
      expect(state.isChecklistsVisible, false);
      expect(state.scrollOffset, 350.0);

      // Cross checklists threshold (500.0)
      controller.updateScrollOffset(550.0);
      state = container.read(
        taskStickyHeadersControllerProvider(testTaskId),
      );
      expect(state.isTaskHeaderVisible, true);
      expect(state.isAiSummaryVisible, true);
      expect(state.isChecklistsVisible, true);
      expect(state.scrollOffset, 550.0);

      // Scroll back up
      controller.updateScrollOffset(250.0);
      state = container.read(
        taskStickyHeadersControllerProvider(testTaskId),
      );
      expect(state.isTaskHeaderVisible, true);
      expect(state.isAiSummaryVisible, false);
      expect(state.isChecklistsVisible, false);
      expect(state.scrollOffset, 250.0);
    });

    test('should not notify if visibility states remain the same', () {
      var notificationCount = 0;
      container.listen<TaskStickyHeadersState>(
        taskStickyHeadersControllerProvider(testTaskId),
        (_, __) => notificationCount++,
      );

      // Initial update
      controller.updateScrollOffset(150.0);
      expect(notificationCount, 1);

      // Same visibility state, different offset
      controller.updateScrollOffset(160.0);
      expect(notificationCount, 2);

      // Same visibility state, same offset
      controller.updateScrollOffset(160.0);
      expect(notificationCount, 2); // Should not increase
    });

    test('resetVisibility should reset to initial state', () {
      // Set some visibility
      controller.updateScrollOffset(600.0);
      var state = container.read(
        taskStickyHeadersControllerProvider(testTaskId),
      );
      expect(state.isTaskHeaderVisible, true);
      expect(state.isAiSummaryVisible, true);
      expect(state.isChecklistsVisible, true);

      // Reset
      controller.resetVisibility();
      state = container.read(
        taskStickyHeadersControllerProvider(testTaskId),
      );
      expect(state.isTaskHeaderVisible, false);
      expect(state.isAiSummaryVisible, false);
      expect(state.isChecklistsVisible, false);
      expect(state.scrollOffset, 0.0);
    });

    test('individual setters should update only specific visibility', () {
      // Set task header visible
      controller.setTaskHeaderVisible(true);
      var state = container.read(
        taskStickyHeadersControllerProvider(testTaskId),
      );
      expect(state.isTaskHeaderVisible, true);
      expect(state.isAiSummaryVisible, false);
      expect(state.isChecklistsVisible, false);

      // Set AI summary visible
      controller.setAiSummaryVisible(true);
      state = container.read(
        taskStickyHeadersControllerProvider(testTaskId),
      );
      expect(state.isTaskHeaderVisible, true);
      expect(state.isAiSummaryVisible, true);
      expect(state.isChecklistsVisible, false);

      // Set checklists visible
      controller.setChecklistsVisible(true);
      state = container.read(
        taskStickyHeadersControllerProvider(testTaskId),
      );
      expect(state.isTaskHeaderVisible, true);
      expect(state.isAiSummaryVisible, true);
      expect(state.isChecklistsVisible, true);

      // Set task header invisible
      controller.setTaskHeaderVisible(false);
      state = container.read(
        taskStickyHeadersControllerProvider(testTaskId),
      );
      expect(state.isTaskHeaderVisible, false);
      expect(state.isAiSummaryVisible, true);
      expect(state.isChecklistsVisible, true);
    });

    test('setters should not notify if value is the same', () {
      var notificationCount = 0;
      container.listen<TaskStickyHeadersState>(
        taskStickyHeadersControllerProvider(testTaskId),
        (_, __) => notificationCount++,
      );

      controller.setTaskHeaderVisible(true);
      expect(notificationCount, 1);

      // Setting the same value should not trigger notification
      controller.setTaskHeaderVisible(true);
      expect(notificationCount, 1);

      controller.setTaskHeaderVisible(false);
      expect(notificationCount, 2);
    });
  });
}