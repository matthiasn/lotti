import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/utils/cache_extension.dart';

void main() {
  group('cacheFor', () {
    test('should keep the provider alive for the specified duration', () {
      fakeAsync((async) {
        var buildCount = 0;
        final testProvider = Provider.autoDispose<int>((ref) {
          ref.cacheFor(const Duration(milliseconds: 100));
          return ++buildCount;
        });

        final container = ProviderContainer();
        addTearDown(container.dispose);

        // Read the provider to activate it
        final initialValue = container.read(testProvider);
        expect(initialValue, 1);

        // Advance less than cache duration — provider should still be cached
        async.elapse(const Duration(milliseconds: 50));
        expect(container.read(testProvider), initialValue);
        expect(buildCount, 1);

        // Advance past cache duration — keepAlive link is closed and the
        // autoDispose provider is allowed to dispose naturally.
        async
          ..elapse(const Duration(milliseconds: 60))
          ..flushMicrotasks();
        final newValue = container.read(testProvider);
        expect(newValue, 2);
        expect(buildCount, 2);
      });
    });

    glados.Glados(
      glados.any.generatedCacheDuration,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'keeps generated autoDispose providers alive for the requested duration',
      (scenario) {
        fakeAsync((async) {
          var buildCount = 0;
          final testProvider = Provider.autoDispose<int>((ref) {
            ref.cacheFor(scenario.duration);
            return ++buildCount;
          });

          final container = ProviderContainer();
          try {
            final initialValue = container.read(testProvider);
            expect(initialValue, 1, reason: '$scenario');

            async.elapse(scenario.beforeExpiry);
            expect(
              container.read(testProvider),
              initialValue,
              reason: '$scenario',
            );
            expect(buildCount, 1, reason: '$scenario');

            async
              ..elapse(scenario.untilAfterExpiry)
              ..flushMicrotasks();
            expect(container.read(testProvider), 2, reason: '$scenario');
            expect(buildCount, 2, reason: '$scenario');
          } finally {
            container.dispose();
          }
        });
      },
      tags: 'glados',
    );
  });

  // ---------------------------------------------------------------------------
  // Duration constants — regression protection
  //
  // These tests pin the exported Duration constants so that accidental changes
  // (e.g., during a rebase or bulk find-replace) are caught immediately.
  // ---------------------------------------------------------------------------
  group('exported Duration constants', () {
    test('dashboardCacheDuration is 5 minutes', () {
      expect(
        dashboardCacheDuration,
        const Duration(minutes: 5),
        reason: 'dashboardCacheDuration changed — update consumers first',
      );
    });

    test('entryCacheDuration is 1 minute', () {
      expect(
        entryCacheDuration,
        const Duration(minutes: 1),
        reason: 'entryCacheDuration changed — update consumers first',
      );
    });

    test('inferenceStateCacheDuration is 2 minutes', () {
      expect(
        inferenceStateCacheDuration,
        const Duration(minutes: 2),
        reason: 'inferenceStateCacheDuration changed — update consumers first',
      );
    });

    test('entry cache is shorter than dashboard cache', () {
      expect(
        entryCacheDuration,
        lessThan(dashboardCacheDuration),
        reason:
            'entry cache should expire sooner than the dashboard aggregate',
      );
    });

    test('inference-state cache is between entry and dashboard durations', () {
      expect(
        inferenceStateCacheDuration,
        greaterThan(entryCacheDuration),
        reason: 'inference-state cache should outlive per-entry cache',
      );
      expect(
        inferenceStateCacheDuration,
        lessThan(dashboardCacheDuration),
        reason: 'inference-state cache should expire before dashboard cache',
      );
    });
  });
}

class _GeneratedCacheDuration {
  const _GeneratedCacheDuration(this.milliseconds);

  final int milliseconds;

  Duration get duration => Duration(milliseconds: milliseconds);

  Duration get beforeExpiry => Duration(milliseconds: milliseconds - 1);

  Duration get untilAfterExpiry => const Duration(milliseconds: 1);

  @override
  String toString() => '_GeneratedCacheDuration(milliseconds: $milliseconds)';
}

extension _AnyCacheExtension on glados.Any {
  glados.Generator<_GeneratedCacheDuration> get generatedCacheDuration =>
      glados.IntAnys(this).intInRange(1, 500).map(_GeneratedCacheDuration.new);
}
