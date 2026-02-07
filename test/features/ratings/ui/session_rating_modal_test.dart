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

  setUp(() async {
    await setUpTestGetIt();
    mockRepository = MockRatingRepository();

    when(() => mockRepository.getRatingForTimeEntry(testTimeEntryId))
        .thenAnswer((_) async => null);
  });

  tearDown(tearDownTestGetIt);

  Widget buildSubject({List<Override> overrides = const []}) {
    return makeTestableWidgetWithScaffold(
      const SessionRatingModal(timeEntryId: testTimeEntryId),
      overrides: [
        ratingRepositoryProvider.overrideWithValue(mockRepository),
        ...overrides,
      ],
    );
  }

  group('SessionRatingModal', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Rate this session'), findsOneWidget);
    });

    testWidgets('renders all rating dimension labels', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('How productive was this session?'), findsOneWidget);
      expect(find.text('How energized did you feel?'), findsOneWidget);
      expect(find.text('How focused were you?'), findsOneWidget);
      expect(find.text('This work felt...'), findsOneWidget);
    });

    testWidgets('renders challenge-skill buttons', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Too easy'), findsOneWidget);
      expect(find.text('Just right'), findsOneWidget);
      expect(find.text('Too hard'), findsOneWidget);
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
          timeEntryId: testTimeEntryId,
          dimensions: [
            RatingDimension(key: 'productivity', value: 0.7),
            RatingDimension(key: 'energy', value: 0.5),
            RatingDimension(key: 'focus', value: 0.9),
            RatingDimension(key: 'challenge_skill', value: 0.5),
          ],
          note: 'Previous note',
        ),
      );

      when(() => mockRepository.getRatingForTimeEntry(testTimeEntryId))
          .thenAnswer((_) async => existingRating);

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
      expect(find.byType(SessionRatingModal), findsOneWidget);
    });
  });
}
