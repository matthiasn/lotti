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

        // Advance past cache duration — keepAlive link is closed,
        // but provider stays alive as long as something reads it
        async.elapse(const Duration(milliseconds: 60));

        // Invalidate to force re-evaluation now that keepAlive expired
        container.invalidate(testProvider);
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

            async.elapse(scenario.untilAfterExpiry);
            container.invalidate(testProvider);
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
