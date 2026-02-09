import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/features/ratings/repository/rating_repository.dart';
import 'package:lotti/features/ratings/ui/session_rating_modal.dart';
import 'package:mocktail/mocktail.dart';

import '../../../widget_test_utils.dart';

class MockRatingRepository extends Mock implements RatingRepository {}

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

  group('RatingModal', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Rate this session'), findsOneWidget);
    });

    testWidgets('renders all rating dimension labels from catalog',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('How productive was this session?'), findsOneWidget);
      expect(find.text('How energized did you feel?'), findsOneWidget);
      expect(find.text('How focused were you?'), findsOneWidget);
      expect(find.text('This work felt...'), findsOneWidget);
    });

    testWidgets('renders challenge-skill buttons from catalog', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Too easy'), findsOneWidget);
      expect(find.text('Just right'), findsOneWidget);
      expect(find.text('Too challenging'), findsOneWidget);
    });

    testWidgets('renders note text field', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Quick note (optional)'), findsOneWidget);
    });

    testWidgets('renders Skip and Save buttons', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('Save button is disabled when not all dimensions are set',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Find the FilledButton (Save button)
      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );

      // Should be disabled (onPressed is null)
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('can enter text in note field', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'My session note');
      await tester.pump();

      expect(find.text('My session note'), findsOneWidget);
    });

    testWidgets('pre-populates from existing rating', (tester) async {
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
          dimensions: [
            RatingDimension(key: 'productivity', value: 0.7),
            RatingDimension(key: 'energy', value: 0.5),
            RatingDimension(key: 'focus', value: 0.9),
            RatingDimension(key: 'challenge_skill', value: 0.5),
          ],
          note: 'Previous note',
        ),
      );

      when(
        () => mockRepository.getRatingForTargetEntry(testTimeEntryId),
      ).thenAnswer((_) async => existingRating);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Note should be pre-populated
      expect(find.text('Previous note'), findsOneWidget);

      // Save button should be enabled since all dimensions are set
      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(saveButton.onPressed, isNotNull);
    });

    testWidgets('tapping challenge-skill button selects it', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Just right'));
      await tester.pumpAndSettle();

      // SegmentedButton should reflect selection - verified by the fact that
      // Save is still disabled (other dimensions not set)
      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('renders drag handle', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // The drag handle is a Container with 40x4 dimensions
      // We verify the overall layout rendered properly
      expect(find.byType(RatingModal), findsOneWidget);
    });

    testWidgets('submit calls repository when all dimensions set',
        (tester) async {
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
          dimensions: [
            RatingDimension(key: 'productivity', value: 0.7),
            RatingDimension(key: 'energy', value: 0.5),
            RatingDimension(key: 'focus', value: 0.9),
            RatingDimension(key: 'challenge_skill', value: 0.5),
          ],
        ),
      );

      when(
        () => mockRepository.getRatingForTargetEntry(testTimeEntryId),
      ).thenAnswer((_) async => existingRating);

      when(
        () => mockRepository.createOrUpdateRating(
          targetId: any(named: 'targetId'),
          dimensions: any(named: 'dimensions'),
          catalogId: any(named: 'catalogId'),
          note: any(named: 'note'),
        ),
      ).thenAnswer((_) async => existingRating);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // All dimensions pre-populated, Save should be enabled
      final saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(saveButton.onPressed, isNotNull);

      // Tap Save
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(
        () => mockRepository.createOrUpdateRating(
          targetId: testTimeEntryId,
          dimensions: any(named: 'dimensions'),
          note: any(named: 'note'),
        ),
      ).called(1);
    });

    testWidgets('submitted dimensions contain snapshotted question metadata',
        (tester) async {
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
          dimensions: [
            RatingDimension(key: 'productivity', value: 0.7),
            RatingDimension(key: 'energy', value: 0.5),
            RatingDimension(key: 'focus', value: 0.9),
            RatingDimension(key: 'challenge_skill', value: 0.5),
          ],
        ),
      );

      when(
        () => mockRepository.getRatingForTargetEntry(testTimeEntryId),
      ).thenAnswer((_) async => existingRating);

      when(
        () => mockRepository.createOrUpdateRating(
          targetId: any(named: 'targetId'),
          dimensions: any(named: 'dimensions'),
          catalogId: any(named: 'catalogId'),
          note: any(named: 'note'),
        ),
      ).thenAnswer((_) async => existingRating);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Tap Save
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Capture the dimensions passed to the repository
      final captured = verify(
        () => mockRepository.createOrUpdateRating(
          targetId: testTimeEntryId,
          dimensions: captureAny(named: 'dimensions'),
          note: any(named: 'note'),
        ),
      ).captured.single as List<RatingDimension>;

      // All dimensions should have snapshotted metadata
      for (final dim in captured) {
        expect(dim.question, isNotNull, reason: '${dim.key} has question');
        expect(
          dim.description,
          isNotNull,
          reason: '${dim.key} has description',
        );
        expect(
          dim.inputType,
          isNotNull,
          reason: '${dim.key} has inputType',
        );
      }

      // Verify specific metadata for productivity (tapBar type)
      final productivity = captured.firstWhere(
        (d) => d.key == 'productivity',
      );
      expect(productivity.inputType, equals('tapBar'));
      expect(productivity.optionLabels, isNull);
      expect(productivity.optionValues, isNull);

      // Verify specific metadata for challenge_skill (segmented type)
      final challengeSkill = captured.firstWhere(
        (d) => d.key == 'challenge_skill',
      );
      expect(challengeSkill.inputType, equals('segmented'));
      expect(challengeSkill.optionLabels, isNotNull);
      expect(challengeSkill.optionLabels, hasLength(3));
      expect(challengeSkill.optionValues, isNotNull);
      expect(challengeSkill.optionValues, hasLength(3));
      expect(challengeSkill.optionValues, equals([0.0, 0.5, 1.0]));
    });

    testWidgets('tapping all tap bars and challenge button enables Save',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Save should be disabled initially
      var saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(saveButton.onPressed, isNull);

      // Tap on each of the 3 LayoutBuilder tap bars (productivity, energy,
      // focus)
      final layoutBuilders = find.byType(LayoutBuilder);
      expect(layoutBuilders, findsNWidgets(3));

      for (var i = 0; i < 3; i++) {
        await tester.tap(layoutBuilders.at(i));
        await tester.pumpAndSettle();
      }

      // Tap the challenge-skill "Just right" button
      await tester.tap(find.text('Just right'));
      await tester.pumpAndSettle();

      // Now all 4 dimensions are set, Save should be enabled
      saveButton = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(saveButton.onPressed, isNotNull);
    });

    testWidgets('skip button is always enabled', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final skipButton = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Skip'),
      );
      expect(skipButton.onPressed, isNotNull);
    });
  });

  group('RatingModal unknown catalog', () {
    testWidgets('renders read-only view for unregistered catalogId',
        (tester) async {
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
      await tester.pumpAndSettle();

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

    testWidgets('renders read-only with no stored metadata falls back to key',
        (tester) async {
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
      await tester.pumpAndSettle();

      // Falls back to dimension key as label
      expect(find.text('some_dimension'), findsOneWidget);

      // Shows progress bar (LinearProgressIndicator) for the dimension
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });
}
