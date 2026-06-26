import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/state/task_app_bar_controller.dart';

void main() {
  group('TaskAppBarController', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    /// Keeps the autoDispose family instance alive and resolves its initial
    /// build before the test interacts with the notifier.
    Future<TaskAppBarController> bootstrap(String id) async {
      final provider = taskAppBarControllerProvider(id);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(provider.future);
      return container.read(provider.notifier);
    }

    test('initial offset is 0.0', () async {
      await bootstrap('task-1');

      expect(
        container.read(taskAppBarControllerProvider('task-1')).value,
        0.0,
      );
    });

    test('updateOffset replaces the state with the new offset', () async {
      final notifier = await bootstrap('task-1');

      notifier.updateOffset(142.5);

      expect(
        container.read(taskAppBarControllerProvider('task-1')).value,
        142.5,
      );

      // Subsequent updates overwrite, they do not accumulate.
      notifier.updateOffset(7);
      expect(
        container.read(taskAppBarControllerProvider('task-1')).value,
        7.0,
      );
    });

    test('offsets are tracked independently per task id', () async {
      final notifierA = await bootstrap('task-a');
      await bootstrap('task-b');

      notifierA.updateOffset(33);

      expect(
        container.read(taskAppBarControllerProvider('task-a')).value,
        33.0,
      );
      expect(
        container.read(taskAppBarControllerProvider('task-b')).value,
        0.0,
      );
    });
  });
}
