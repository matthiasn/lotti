import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    });

    test('selectTask ignores unknown ids', () {
      container
          .read(taskListDetailShowcaseControllerProvider.notifier)
          .selectTask('missing-task');

      final state = container.read(taskListDetailShowcaseControllerProvider);
      expect(state.selectedTask?.task.meta.id, 'payment-confirmation');
    });
  });
}
