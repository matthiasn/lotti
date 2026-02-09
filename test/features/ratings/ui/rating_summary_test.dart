import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/features/ratings/ui/rating_summary.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../widget_test_utils.dart';

void main() {
  final testRatingEntry = RatingEntry(
    meta: Metadata(
      id: 'rating-1',
      createdAt: DateTime(2024, 6, 15),
      updatedAt: DateTime(2024, 6, 15),
      dateFrom: DateTime(2024, 6, 15),
      dateTo: DateTime(2024, 6, 15),
    ),
    data: const RatingData(
      targetId: 'time-entry-1',
      dimensions: [
        RatingDimension(key: 'productivity', value: 0.7),
        RatingDimension(key: 'energy', value: 0.5),
        RatingDimension(key: 'focus', value: 0.9),
        RatingDimension(key: 'challenge_skill', value: 0.5),
      ],
      note: 'Great session!',
    ),
  );

  Widget buildSubject({RatingEntry? entry}) {
    return makeTestableWidget(
      RatingSummary(entry ?? testRatingEntry),
    );
  }

  group('RatingSummary', () {
    testWidgets('renders dimension labels from catalog fallback',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(RatingSummary)),
      )!;

      // Without stored question metadata, falls back to catalog lookup
      expect(
        find.text(l10n.sessionRatingProductivityQuestion),
        findsOneWidget,
      );
      expect(
        find.text(l10n.sessionRatingEnergyQuestion),
        findsOneWidget,
      );
      expect(
        find.text(l10n.sessionRatingFocusQuestion),
        findsOneWidget,
      );
    });

    testWidgets('renders progress indicators for tapBar dimensions',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
    });

    testWidgets('renders challenge-skill text from catalog', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(RatingSummary)),
      )!;

      expect(find.text(l10n.sessionRatingDifficultyLabel), findsOneWidget);
      expect(
        find.text(l10n.sessionRatingChallengeJustRight),
        findsOneWidget,
      );
    });

    testWidgets('renders challenge-skill "Too easy" from catalog',
        (tester) async {
      final entry = RatingEntry(
        meta: Metadata(
          id: 'rating-2',
          createdAt: DateTime(2024, 6, 15),
          updatedAt: DateTime(2024, 6, 15),
          dateFrom: DateTime(2024, 6, 15),
          dateTo: DateTime(2024, 6, 15),
        ),
        data: const RatingData(
          targetId: 'time-entry-2',
          dimensions: [
            RatingDimension(key: 'productivity', value: 0.7),
            RatingDimension(key: 'energy', value: 0.5),
            RatingDimension(key: 'focus', value: 0.9),
            RatingDimension(key: 'challenge_skill', value: 0),
          ],
        ),
      );

      await tester.pumpWidget(buildSubject(entry: entry));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(RatingSummary)),
      )!;

      expect(find.text(l10n.sessionRatingChallengeTooEasy), findsOneWidget);
    });

    testWidgets('renders challenge-skill "Too challenging" from catalog',
        (tester) async {
      final entry = RatingEntry(
        meta: Metadata(
          id: 'rating-3',
          createdAt: DateTime(2024, 6, 15),
          updatedAt: DateTime(2024, 6, 15),
          dateFrom: DateTime(2024, 6, 15),
          dateTo: DateTime(2024, 6, 15),
        ),
        data: const RatingData(
          targetId: 'time-entry-3',
          dimensions: [
            RatingDimension(key: 'productivity', value: 0.7),
            RatingDimension(key: 'energy', value: 0.5),
            RatingDimension(key: 'focus', value: 0.9),
            RatingDimension(key: 'challenge_skill', value: 1),
          ],
        ),
      );

      await tester.pumpWidget(buildSubject(entry: entry));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(RatingSummary)),
      )!;

      expect(
        find.text(l10n.sessionRatingChallengeTooHard),
        findsOneWidget,
      );
    });

    testWidgets('renders note text when present', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Great session!'), findsOneWidget);
    });

    testWidgets('does not render note when absent', (tester) async {
      final entryWithoutNote = RatingEntry(
        meta: Metadata(
          id: 'rating-4',
          createdAt: DateTime(2024, 6, 15),
          updatedAt: DateTime(2024, 6, 15),
          dateFrom: DateTime(2024, 6, 15),
          dateTo: DateTime(2024, 6, 15),
        ),
        data: const RatingData(
          targetId: 'time-entry-4',
          dimensions: [
            RatingDimension(key: 'productivity', value: 0.7),
            RatingDimension(key: 'energy', value: 0.5),
            RatingDimension(key: 'focus', value: 0.9),
            RatingDimension(key: 'challenge_skill', value: 0.5),
          ],
        ),
      );

      await tester.pumpWidget(buildSubject(entry: entryWithoutNote));
      await tester.pumpAndSettle();

      expect(find.text('Great session!'), findsNothing);
    });

    testWidgets('renders edit button with icon', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
    });

    testWidgets('edit button has correct tooltip', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(RatingSummary)),
      )!;

      final iconButton = tester.widget<IconButton>(
        find.byType(IconButton),
      );
      expect(iconButton.tooltip, l10n.sessionRatingEditButton);
    });
  });

  group('RatingSummary with stored metadata', () {
    testWidgets('uses stored question as label (fallback chain step 1)',
        (tester) async {
      final entry = RatingEntry(
        meta: Metadata(
          id: 'rating-meta',
          createdAt: DateTime(2024, 6, 15),
          updatedAt: DateTime(2024, 6, 15),
          dateFrom: DateTime(2024, 6, 15),
          dateTo: DateTime(2024, 6, 15),
        ),
        data: const RatingData(
          targetId: 'time-entry-5',
          dimensions: [
            RatingDimension(
              key: 'productivity',
              value: 0.8,
              question: 'Custom stored question',
              inputType: 'tapBar',
            ),
          ],
        ),
      );

      await tester.pumpWidget(buildSubject(entry: entry));
      await tester.pumpAndSettle();

      // Should use stored question, not catalog fallback
      expect(find.text('Custom stored question'), findsOneWidget);
    });

    testWidgets('uses stored optionLabels for segmented display',
        (tester) async {
      final entry = RatingEntry(
        meta: Metadata(
          id: 'rating-seg',
          createdAt: DateTime(2024, 6, 15),
          updatedAt: DateTime(2024, 6, 15),
          dateFrom: DateTime(2024, 6, 15),
          dateTo: DateTime(2024, 6, 15),
        ),
        data: const RatingData(
          targetId: 'time-entry-6',
          dimensions: [
            RatingDimension(
              key: 'challenge_skill',
              value: 0.5,
              question: 'How did the work feel?',
              inputType: 'segmented',
              optionLabels: ['Too simple', 'Perfect', 'Too complex'],
            ),
          ],
        ),
      );

      await tester.pumpWidget(buildSubject(entry: entry));
      await tester.pumpAndSettle();

      // Should use stored optionLabels
      expect(find.text('Perfect'), findsOneWidget);
      expect(find.text('How did the work feel?'), findsOneWidget);
    });
  });

  group('RatingSummary unknown catalog fallback', () {
    testWidgets(
        'falls back to dimension key when no stored question '
        'and unknown catalog', (tester) async {
      final entry = RatingEntry(
        meta: Metadata(
          id: 'rating-unknown',
          createdAt: DateTime(2024, 6, 15),
          updatedAt: DateTime(2024, 6, 15),
          dateFrom: DateTime(2024, 6, 15),
          dateTo: DateTime(2024, 6, 15),
        ),
        data: const RatingData(
          targetId: 'time-entry-7',
          catalogId: 'unknown_future_catalog',
          dimensions: [
            RatingDimension(key: 'unknown_dimension', value: 0.6),
          ],
        ),
      );

      await tester.pumpWidget(buildSubject(entry: entry));
      await tester.pumpAndSettle();

      // Falls back to dimension key as label
      expect(find.text('unknown_dimension'), findsOneWidget);

      // Still renders a progress bar
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('renders all dimensions even for unknown catalog',
        (tester) async {
      final entry = RatingEntry(
        meta: Metadata(
          id: 'rating-unknown-2',
          createdAt: DateTime(2024, 6, 15),
          updatedAt: DateTime(2024, 6, 15),
          dateFrom: DateTime(2024, 6, 15),
          dateTo: DateTime(2024, 6, 15),
        ),
        data: const RatingData(
          targetId: 'time-entry-8',
          catalogId: 'day_evening',
          dimensions: [
            RatingDimension(
              key: 'gratitude',
              value: 0.9,
              question: 'How grateful do you feel?',
            ),
            RatingDimension(
              key: 'accomplishment',
              value: 0.7,
              question: 'How much did you accomplish?',
            ),
          ],
          note: 'Good day overall',
        ),
      );

      await tester.pumpWidget(buildSubject(entry: entry));
      await tester.pumpAndSettle();

      // Stored questions are displayed
      expect(find.text('How grateful do you feel?'), findsOneWidget);
      expect(find.text('How much did you accomplish?'), findsOneWidget);

      // Both rendered as progress bars
      expect(find.byType(LinearProgressIndicator), findsNWidgets(2));

      // Note is displayed
      expect(find.text('Good day overall'), findsOneWidget);
    });

    testWidgets(
        'segmented dimension with stored optionLabels shows '
        'percentage fallback for unmatched value', (tester) async {
      final entry = RatingEntry(
        meta: Metadata(
          id: 'rating-pct',
          createdAt: DateTime(2024, 6, 15),
          updatedAt: DateTime(2024, 6, 15),
          dateFrom: DateTime(2024, 6, 15),
          dateTo: DateTime(2024, 6, 15),
        ),
        data: const RatingData(
          targetId: 'time-entry-9',
          catalogId: 'unknown_catalog',
          dimensions: [
            RatingDimension(
              key: 'custom',
              value: 0.37,
              question: 'Some question',
              inputType: 'segmented',
              optionLabels: ['Low', 'Medium', 'High'],
            ),
          ],
        ),
      );

      await tester.pumpWidget(buildSubject(entry: entry));
      await tester.pumpAndSettle();

      // Value 0.37 doesn't match any of [0.0, 0.5, 1.0], falls back to %
      expect(find.text('37%'), findsOneWidget);
    });

    testWidgets(
        'segmented dimension without options falls back to '
        'progress bar', (tester) async {
      final entry = RatingEntry(
        meta: Metadata(
          id: 'rating-seg-no-opts',
          createdAt: DateTime(2024, 6, 15),
          updatedAt: DateTime(2024, 6, 15),
          dateFrom: DateTime(2024, 6, 15),
          dateTo: DateTime(2024, 6, 15),
        ),
        data: const RatingData(
          targetId: 'time-entry-10',
          catalogId: 'unknown_catalog',
          dimensions: [
            RatingDimension(
              key: 'ambiguous',
              value: 0.5,
              question: 'Ambiguous dimension',
              inputType: 'segmented',
              // No optionLabels and no catalog → _resolveSegmentedLabel
              // returns null → falls back to progress bar
            ),
          ],
        ),
      );

      await tester.pumpWidget(buildSubject(entry: entry));
      await tester.pumpAndSettle();

      // Falls back to progress bar rendering
      expect(find.text('Ambiguous dimension'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('uses stored optionValues for non-linear scales',
        (tester) async {
      final entry = RatingEntry(
        meta: Metadata(
          id: 'rating-nonlinear',
          createdAt: DateTime(2024, 6, 15),
          updatedAt: DateTime(2024, 6, 15),
          dateFrom: DateTime(2024, 6, 15),
          dateTo: DateTime(2024, 6, 15),
        ),
        data: const RatingData(
          targetId: 'time-entry-11',
          catalogId: 'unknown_catalog',
          dimensions: [
            RatingDimension(
              key: 'severity',
              value: 0.2,
              question: 'How severe?',
              inputType: 'segmented',
              // Non-linear scale: without optionValues, 0.2 would not match
              // any evenly-spaced value [0.0, 0.5, 1.0] and fall back to "20%"
              optionLabels: ['Mild', 'Moderate', 'Severe'],
              optionValues: [0.0, 0.2, 1.0],
            ),
          ],
        ),
      );

      await tester.pumpWidget(buildSubject(entry: entry));
      await tester.pumpAndSettle();

      // With stored optionValues, 0.2 matches index 1 → "Moderate"
      expect(find.text('Moderate'), findsOneWidget);
      expect(find.text('How severe?'), findsOneWidget);
    });
  });
}
