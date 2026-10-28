import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/state/task_due_day_provider.dart';

void main() {
  test('is the local date, without a time of day', () {
    fakeAsync((async) {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(taskDueDayProvider), DateTime(2024, 7, 3));
    }, initialTime: DateTime(2024, 7, 3, 15, 42));
  });

  test('re-emits the new date at local midnight, and only then', () {
    fakeAsync((async) {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final seen = <DateTime>[];
      container.listen(
        taskDueDayProvider,
        (_, next) => seen.add(next),
        fireImmediately: true,
      );

      async.elapse(const Duration(minutes: 9));
      expect(seen, [DateTime(2024, 7, 3)]);

      async.elapse(const Duration(minutes: 2));
      expect(seen, [DateTime(2024, 7, 3), DateTime(2024, 7, 4)]);

      // The next tick is a whole day out, not a minute.
      async.elapse(const Duration(hours: 23));
      expect(seen, hasLength(2));
      async.elapse(const Duration(hours: 1));
      expect(seen.last, DateTime(2024, 7, 5));
    }, initialTime: DateTime(2024, 7, 3, 23, 50));
  });

  test('cancels its timer when nobody listens any more', () {
    fakeAsync((async) {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sub = container.listen(taskDueDayProvider, (_, _) {});
      expect(async.pendingTimers, hasLength(1));

      sub.close();
      // Auto-dispose itself runs on a zero-length timer.
      async.elapse(Duration.zero);

      expect(async.pendingTimers, isEmpty);
    }, initialTime: DateTime(2024, 7, 3, 12));
  });
}
