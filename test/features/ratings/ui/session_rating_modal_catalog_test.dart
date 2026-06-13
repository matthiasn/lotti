import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/features/ratings/data/rating_catalogs.dart';
import 'package:lotti/features/ratings/repository/rating_repository.dart';
import 'package:lotti/features/ratings/ui/session_rating_modal.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  late MockRatingRepository mockRepository;

  const testTimeEntryId = 'time-entry-1';

  setUpAll(() {
    registerFallbackValue(
      const <RatingDimension>[
        RatingDimension(key: 'fallback', value: 0),
      ],
    );
  });

  setUp(() async {
    await setUpTestGetIt();
    mockRepository = MockRatingRepository();

    when(
      () => mockRepository.getRatingForTargetEntry(testTimeEntryId),
    ).thenAnswer((_) async => null);
  });

  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    String catalogId = 'session',
    List<Override> overrides = const [],
  }) {
    return makeTestableWidgetWithScaffold(
      RatingModal(targetId: testTimeEntryId, catalogId: catalogId),
      overrides: [
        ratingRepositoryProvider.overrideWithValue(mockRepository),
        ...overrides,
      ],
    );
  }

  group('RatingModal empty catalog', () {
    testWidgets(
      'Save stays disabled for a registered catalog with zero questions',
      (tester) async {
        // _canSubmit guards the empty catalog explicitly: catalog.every()
        // over zero questions is vacuously true, so without the guard an
        // empty catalog would allow submitting an empty rating.
        ratingCatalogRegistry['empty_catalog'] = (_) => [];
        addTearDown(() => ratingCatalogRegistry.remove('empty_catalog'));

        when(
          () => mockRepository.getRatingForTargetEntry(
            testTimeEntryId,
            catalogId: 'empty_catalog',
          ),
        ).thenAnswer((_) async => null);

        await tester.pumpWidget(buildSubject(catalogId: 'empty_catalog'));
        await tester.pump();

        final saveButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Save'),
        );
        expect(saveButton.onPressed, isNull);
      },
    );
  });

  group('RatingModal unknown catalog', () {
    testWidgets('renders read-only view for unregistered catalogId', (
      tester,
    ) async {
      final existingRating = RatingEntry(
        meta: Metadata(
          id: 'rating-1',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
        data: const RatingData(
          targetId: testTimeEntryId,
          catalogId: 'day_morning',
          dimensions: [
            RatingDimension(
              key: 'mood',
              value: 0.8,
              question: 'How are you feeling?',
              inputType: 'tapBar',
            ),
            RatingDimension(
              key: 'readiness',
              value: 0.5,
              question: 'How ready are you?',
              inputType: 'segmented',
              optionLabels: ['Not ready', 'Somewhat', 'Very ready'],
            ),
          ],
        ),
      );

      when(
        () => mockRepository.getRatingForTargetEntry(
          testTimeEntryId,
          catalogId: 'day_morning',
        ),
      ).thenAnswer((_) async => existingRating);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const RatingModal(
            targetId: testTimeEntryId,
            catalogId: 'day_morning',
          ),
          overrides: [
            ratingRepositoryProvider.overrideWithValue(mockRepository),
          ],
        ),
      );
      await tester.pump();

      // Should show the catalogId as title
      expect(find.text('day_morning'), findsOneWidget);

      // Should show stored dimension labels
      expect(find.text('How are you feeling?'), findsOneWidget);
      expect(find.text('How ready are you?'), findsOneWidget);

      // Should show segmented value text
      expect(find.text('Somewhat'), findsOneWidget);

      // Should NOT have a Save button
      expect(find.widgetWithText(FilledButton, 'Save'), findsNothing);

      // Should have a Close/Skip button
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('renders read-only with no stored metadata falls back to key', (
      tester,
    ) async {
      final existingRating = RatingEntry(
        meta: Metadata(
          id: 'rating-2',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
        data: const RatingData(
          targetId: testTimeEntryId,
          catalogId: 'future_catalog',
          dimensions: [
            RatingDimension(key: 'some_dimension', value: 0.6),
          ],
        ),
      );

      when(
        () => mockRepository.getRatingForTargetEntry(
          testTimeEntryId,
          catalogId: 'future_catalog',
        ),
      ).thenAnswer((_) async => existingRating);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const RatingModal(
            targetId: testTimeEntryId,
            catalogId: 'future_catalog',
          ),
          overrides: [
            ratingRepositoryProvider.overrideWithValue(mockRepository),
          ],
        ),
      );
      await tester.pump();

      // Falls back to dimension key as label
      expect(find.text('some_dimension'), findsOneWidget);

      // Shows progress bar (LinearProgressIndicator) for the dimension
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('read-only view renders the stored note when non-empty', (
      tester,
    ) async {
      final existingRating = RatingEntry(
        meta: Metadata(
          id: 'rating-3',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
        data: const RatingData(
          targetId: testTimeEntryId,
          catalogId: 'future_catalog',
          dimensions: [
            RatingDimension(key: 'some_dimension', value: 0.6),
          ],
          note: 'A stored read-only note',
        ),
      );

      when(
        () => mockRepository.getRatingForTargetEntry(
          testTimeEntryId,
          catalogId: 'future_catalog',
        ),
      ).thenAnswer((_) async => existingRating);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const RatingModal(
            targetId: testTimeEntryId,
            catalogId: 'future_catalog',
          ),
          overrides: [
            ratingRepositoryProvider.overrideWithValue(mockRepository),
          ],
        ),
      );
      await tester.pump();

      // The stored note is rendered (read-only branch, lines 325-330).
      expect(find.text('A stored read-only note'), findsOneWidget);
      // No editable note field in read-only mode.
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('read-only view omits note section when note is empty', (
      tester,
    ) async {
      final existingRating = RatingEntry(
        meta: Metadata(
          id: 'rating-4',
          createdAt: DateTime(2024, 3, 15),
          updatedAt: DateTime(2024, 3, 15),
          dateFrom: DateTime(2024, 3, 15),
          dateTo: DateTime(2024, 3, 15),
        ),
        data: const RatingData(
          targetId: testTimeEntryId,
          catalogId: 'future_catalog',
          dimensions: [
            RatingDimension(key: 'some_dimension', value: 0.6),
          ],
          note: '',
        ),
      );

      when(
        () => mockRepository.getRatingForTargetEntry(
          testTimeEntryId,
          catalogId: 'future_catalog',
        ),
      ).thenAnswer((_) async => existingRating);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const RatingModal(
            targetId: testTimeEntryId,
            catalogId: 'future_catalog',
          ),
          overrides: [
            ratingRepositoryProvider.overrideWithValue(mockRepository),
          ],
        ),
      );
      await tester.pump();

      // Empty note -> note section is not rendered, only the dimension + Skip.
      expect(find.text('some_dimension'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Skip'), findsOneWidget);

      // The read-only note section (a Padding wrapping a Text, lines 322-332)
      // is conditional on a non-empty note, so it must be absent entirely.
      // Prove it disappeared: the note text from the populated sibling test is
      // gone, and no note Text widget renders the empty string.
      expect(find.text('A stored read-only note'), findsNothing);
      expect(find.text(''), findsNothing);
    });
  });
}
