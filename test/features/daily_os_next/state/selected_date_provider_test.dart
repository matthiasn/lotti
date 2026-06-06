import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/state/selected_date_provider.dart';

void main() {
  group('dailyOsNextSelectedDateProvider', () {
    test('builds with the local midnight of today', () {
      withClock(Clock.fixed(DateTime(2026, 5, 26, 16, 45)), () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(
          container.read(dailyOsNextSelectedDateProvider),
          DateTime(2026, 5, 26),
        );
      });
    });

    test('select normalizes to the local calendar day', () {
      withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container
            .read(dailyOsNextSelectedDateProvider.notifier)
            .select(DateTime(2026, 6, 2, 18, 30));

        expect(
          container.read(dailyOsNextSelectedDateProvider),
          DateTime(2026, 6, 2),
        );
      });
    });

    test('shiftDays moves across month boundaries DST-safely', () {
      withClock(Clock.fixed(DateTime(2026, 5, 31, 9)), () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container.read(dailyOsNextSelectedDateProvider.notifier).shiftDays(1);
        expect(
          container.read(dailyOsNextSelectedDateProvider),
          // ignore: avoid_redundant_argument_values
          DateTime(2026, 6, 1),
        );

        container.read(dailyOsNextSelectedDateProvider.notifier).shiftDays(-2);
        expect(
          container.read(dailyOsNextSelectedDateProvider),
          DateTime(2026, 5, 30),
        );
      });
    });

    test('goToToday returns to the current local day', () {
      withClock(Clock.fixed(DateTime(2026, 5, 26, 9)), () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container
            .read(dailyOsNextSelectedDateProvider.notifier)
            // ignore: avoid_redundant_argument_values
            .select(DateTime(2026, 1, 1));
        container.read(dailyOsNextSelectedDateProvider.notifier).goToToday();

        expect(
          container.read(dailyOsNextSelectedDateProvider),
          DateTime(2026, 5, 26),
        );
      });
    });
  });
}
