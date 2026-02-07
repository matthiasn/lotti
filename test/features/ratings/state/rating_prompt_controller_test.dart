import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ratings/state/rating_prompt_controller.dart';

void main() {
  group('RatingPromptController', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() => container.dispose());

    test('initializes with null state', () {
      final state = container.read(ratingPromptControllerProvider);
      expect(state, isNull);
    });

    test('requestRating sets state to the time entry ID', () {
      container
          .read(ratingPromptControllerProvider.notifier)
          .requestRating('entry-123');

      final state = container.read(ratingPromptControllerProvider);
      expect(state, equals('entry-123'));
    });

    test('dismiss sets state back to null', () {
      container
          .read(ratingPromptControllerProvider.notifier)
          .requestRating('entry-456');
      expect(
        container.read(ratingPromptControllerProvider),
        equals('entry-456'),
      );

      container.read(ratingPromptControllerProvider.notifier).dismiss();
      expect(container.read(ratingPromptControllerProvider), isNull);
    });

    test('requesting a different entry replaces the current one', () {
      container
          .read(ratingPromptControllerProvider.notifier)
          .requestRating('entry-1');
      expect(container.read(ratingPromptControllerProvider), equals('entry-1'));

      container
          .read(ratingPromptControllerProvider.notifier)
          .requestRating('entry-2');
      expect(container.read(ratingPromptControllerProvider), equals('entry-2'));
    });

    test('dismiss when already null is a no-op', () {
      // Should not throw
      container.read(ratingPromptControllerProvider.notifier).dismiss();
      expect(container.read(ratingPromptControllerProvider), isNull);
    });
  });
}
