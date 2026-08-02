import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/state/plan_view_provider.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/plan_view_toggle.dart';

void main() {
  group('dailyOsNextPlanViewProvider', () {
    test('starts unset so the page can apply its per-day default', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(dailyOsNextPlanViewProvider), isNull);
    });

    test('keeps the last explicit pick, including a switch back', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(dailyOsNextPlanViewProvider.notifier);

      // Reading between the two picks is the point of the test.
      // ignore: cascade_invocations
      notifier.select(PlanView.day);
      expect(container.read(dailyOsNextPlanViewProvider), PlanView.day);

      notifier.select(PlanView.activity);
      expect(container.read(dailyOsNextPlanViewProvider), PlanView.activity);
    });

    test('a fresh container (app restart) is back to unset', () {
      final first = ProviderContainer();
      addTearDown(first.dispose);
      first.read(dailyOsNextPlanViewProvider.notifier).select(PlanView.day);

      final second = ProviderContainer();
      addTearDown(second.dispose);

      expect(second.read(dailyOsNextPlanViewProvider), isNull);
    });
  });
}
