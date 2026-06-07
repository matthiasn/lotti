import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/tasks/ui/model/task_list_detail_state.dart';
import 'package:lotti/features/tasks/widgetbook/task_list_detail_mock_controller.dart';

void main() {
  group('TaskListDetailShowcaseController', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('build selects payment confirmation by default', () {
      final state = container.read(taskListDetailShowcaseControllerProvider);

      expect(state.selectedTask?.task.meta.id, 'payment-confirmation');
    });

    test('updateSearchQuery moves selection to the first visible task', () {
      container
          .read(taskListDetailShowcaseControllerProvider.notifier)
          .updateSearchQuery('marketing');

      final state = container.read(taskListDetailShowcaseControllerProvider);
      expect(state.visibleTasks.map((task) => task.task.meta.id), [
        'marketing-campaign',
      ]);
      expect(state.selectedTask?.task.meta.id, 'marketing-campaign');
      // Selection/visibility consistency: the selected object IS the first
      // visible record, not merely an id that happens to match.
      expect(
        identical(state.selectedTask, state.visibleTasks.first),
        isTrue,
      );
    });

    test('selectTask ignores unknown ids', () {
      container
          .read(taskListDetailShowcaseControllerProvider.notifier)
          .selectTask('missing-task');

      final state = container.read(taskListDetailShowcaseControllerProvider);
      expect(state.selectedTask?.task.meta.id, 'payment-confirmation');
    });

    DesignSystemTaskFilterState filterWithStatuses(Set<String> ids) {
      final base = container
          .read(taskListDetailShowcaseControllerProvider)
          .filterState;
      return base.copyWith(
        statusField: DesignSystemTaskFilterFieldState(
          label: base.statusField?.label ?? 'Status',
          options: base.statusField?.options ?? const [],
          selectedIds: ids,
        ),
      );
    }

    test(
      'updateFilterState keeps the selection when it stays visible',
      () {
        // The default selection (payment-confirmation) is an open task, so
        // an open-only filter keeps it visible — selection must not move.
        container
            .read(taskListDetailShowcaseControllerProvider.notifier)
            .updateFilterState(
              filterWithStatuses({TaskStatusFilterIds.open}),
            );

        final state = container.read(taskListDetailShowcaseControllerProvider);
        expect(
          state.visibleTasks.map((t) => t.task.meta.id),
          contains('payment-confirmation'),
        );
        expect(state.selectedTask?.task.meta.id, 'payment-confirmation');
      },
    );

    test(
      'updateFilterState moves the selection to the first visible task '
      'when the current selection is filtered out',
      () {
        // Blocked-only hides the open payment-confirmation task.
        container
            .read(taskListDetailShowcaseControllerProvider.notifier)
            .updateFilterState(
              filterWithStatuses({TaskStatusFilterIds.blocked}),
            );

        final state = container.read(taskListDetailShowcaseControllerProvider);
        expect(state.visibleTasks, isNotEmpty);
        expect(
          state.visibleTasks.map((t) => t.task.meta.id),
          isNot(contains('payment-confirmation')),
        );
        expect(
          state.selectedTask?.task.meta.id,
          state.visibleTasks.first.task.meta.id,
        );
      },
    );
  });
}
