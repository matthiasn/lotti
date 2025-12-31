import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/cache_extension.dart';

final Provider<DateTime> testProvider = Provider.autoDispose<DateTime>((ref) {
  ref.cacheFor(const Duration(milliseconds: 100));
  return DateTime.now();
});

void main() {
  group('cacheFor', () {
    test('should keep the provider alive for the specified duration', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Read the provider to activate it
      final initialTime = container.read(testProvider);

      // Wait for a short time, less than the cache duration
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // The provider should still be active and return the same time
      expect(container.read(testProvider), initialTime);

      // Wait for the cache duration to expire
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // The provider should now be re-initialized and return a new time
      final newTime = container.read(testProvider);
      expect(newTime, isNot(initialTime));
    });
  });
}
