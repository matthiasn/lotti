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

    test('requestRating sets state to RatingPrompt record', () {
      container
          .read(ratingPromptControllerProvider.notifier)
          .requestRating(targetId: 'entry-123');

      final state = container.read(ratingPromptControllerProvider);
      expect(state, isNotNull);
      expect(state!.targetId, equals('entry-123'));
      expect(state.catalogId, equals('session'));
    });

    test('requestRating with custom catalogId', () {
      container
          .read(ratingPromptControllerProvider.notifier)
          .requestRating(targetId: 'entry-123', catalogId: 'day_morning');

      final state = container.read(ratingPromptControllerProvider);
      expect(state, isNotNull);
      expect(state!.targetId, equals('entry-123'));
      expect(state.catalogId, equals('day_morning'));
    });

    test('dismiss sets state back to null', () {
      container
          .read(ratingPromptControllerProvider.notifier)
          .requestRating(targetId: 'entry-456');
      expect(
        container.read(ratingPromptControllerProvider),
        isNotNull,
      );

      container.read(ratingPromptControllerProvider.notifier).dismiss();
      expect(container.read(ratingPromptControllerProvider), isNull);
    });

    test('requesting a different entry replaces the current one', () {
      container
          .read(ratingPromptControllerProvider.notifier)
          .requestRating(targetId: 'entry-1');
      expect(
        container.read(ratingPromptControllerProvider)?.targetId,
        equals('entry-1'),
      );

      container
          .read(ratingPromptControllerProvider.notifier)
          .requestRating(targetId: 'entry-2');
      expect(
        container.read(ratingPromptControllerProvider)?.targetId,
        equals('entry-2'),
      );
    });

    test('dismiss when already null is a no-op', () {
      // Should not throw
      container.read(ratingPromptControllerProvider.notifier).dismiss();
      expect(container.read(ratingPromptControllerProvider), isNull);
    });
  });
}
