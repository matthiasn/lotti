import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
  });
}
