import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/features/ratings/repository/rating_repository.dart';
import 'package:lotti/features/ratings/state/rating_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockRatingRepository mockRepository;

  const testTimeEntryId = 'time-entry-1';
  final testDate = DateTime(2024, 3, 15);

  const testDimensions = [
    RatingDimension(key: 'productivity', value: 0.8),
    RatingDimension(key: 'energy', value: 0.6),
    RatingDimension(key: 'focus', value: 0.9),
    RatingDimension(key: 'challenge_skill', value: 0.5),
  ];

  final testRatingEntry = RatingEntry(
    meta: Metadata(
      id: 'rating-1',
      createdAt: testDate,
      updatedAt: testDate,
      dateFrom: testDate,
      dateTo: testDate,
    ),
    data: const RatingData(
      targetId: testTimeEntryId,
      dimensions: testDimensions,
      note: 'Good session',
    ),
  );

  setUp(() {
    mockRepository = MockRatingRepository();
  });

  group('RatingController', () {
    test('build returns null when no existing rating', () async {
      when(() => mockRepository.getRatingForTargetEntry(testTimeEntryId))
          .thenAnswer((_) async => null);

      final container = ProviderContainer(
        overrides: [
          ratingRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );

      final result = await container.read(
        ratingControllerProvider(targetId: testTimeEntryId).future,
      );

      expect(result, isNull);
      verify(() => mockRepository.getRatingForTargetEntry(testTimeEntryId))
          .called(1);

      container.dispose();
    });

    test('build returns existing rating', () async {
      when(() => mockRepository.getRatingForTargetEntry(testTimeEntryId))
          .thenAnswer((_) async => testRatingEntry);

      final container = ProviderContainer(
        overrides: [
          ratingRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );

      final result = await container.read(
        ratingControllerProvider(targetId: testTimeEntryId).future,
      );

      expect(result, equals(testRatingEntry));
      verify(() => mockRepository.getRatingForTargetEntry(testTimeEntryId))
          .called(1);

      container.dispose();
    });

    test('build passes catalogId to repository', () async {
      when(
        () => mockRepository.getRatingForTargetEntry(
          testTimeEntryId,
          catalogId: 'day_morning',
        ),
      ).thenAnswer((_) async => null);

      final container = ProviderContainer(
        overrides: [
          ratingRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );

      await container.read(
        ratingControllerProvider(
          targetId: testTimeEntryId,
          catalogId: 'day_morning',
        ).future,
      );

      verify(
        () => mockRepository.getRatingForTargetEntry(
          testTimeEntryId,
          catalogId: 'day_morning',
        ),
      ).called(1);

      container.dispose();
    });

    test('submitRating calls repository and updates state', () async {
      when(() => mockRepository.getRatingForTargetEntry(testTimeEntryId))
          .thenAnswer((_) async => null);
      when(
        () => mockRepository.createOrUpdateRating(
          targetId: testTimeEntryId,
          dimensions: testDimensions,
          note: 'Great session',
        ),
      ).thenAnswer((_) async => testRatingEntry);

      final container = ProviderContainer(
        overrides: [
          ratingRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );

      // Wait for initial load
      await container.read(
        ratingControllerProvider(targetId: testTimeEntryId).future,
      );

      // Submit rating
      await container
          .read(
            ratingControllerProvider(targetId: testTimeEntryId).notifier,
          )
          .submitRating(testDimensions, note: 'Great session');

      // Verify state was updated
      final state = await container.read(
        ratingControllerProvider(targetId: testTimeEntryId).future,
      );
      expect(state, equals(testRatingEntry));

      verify(
        () => mockRepository.createOrUpdateRating(
          targetId: testTimeEntryId,
          dimensions: testDimensions,
          note: 'Great session',
        ),
      ).called(1);

      container.dispose();
    });

    test('submitRating without note', () async {
      when(() => mockRepository.getRatingForTargetEntry(testTimeEntryId))
          .thenAnswer((_) async => null);
      when(
        () => mockRepository.createOrUpdateRating(
          targetId: testTimeEntryId,
          dimensions: testDimensions,
        ),
      ).thenAnswer((_) async => testRatingEntry);

      final container = ProviderContainer(
        overrides: [
          ratingRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );

      await container.read(
        ratingControllerProvider(targetId: testTimeEntryId).future,
      );

      await container
          .read(
            ratingControllerProvider(targetId: testTimeEntryId).notifier,
          )
          .submitRating(testDimensions);

      verify(
        () => mockRepository.createOrUpdateRating(
          targetId: testTimeEntryId,
          dimensions: testDimensions,
        ),
      ).called(1);

      container.dispose();
    });

    test('submitRating handles repository returning null', () async {
      when(() => mockRepository.getRatingForTargetEntry(testTimeEntryId))
          .thenAnswer((_) async => null);
      when(
        () => mockRepository.createOrUpdateRating(
          targetId: testTimeEntryId,
          dimensions: testDimensions,
        ),
      ).thenAnswer((_) async => null);

      final container = ProviderContainer(
        overrides: [
          ratingRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );

      await container.read(
        ratingControllerProvider(targetId: testTimeEntryId).future,
      );

      await container
          .read(
            ratingControllerProvider(targetId: testTimeEntryId).notifier,
          )
          .submitRating(testDimensions);

      final state = await container.read(
        ratingControllerProvider(targetId: testTimeEntryId).future,
      );
      expect(state, isNull);

      container.dispose();
    });
  });
}
