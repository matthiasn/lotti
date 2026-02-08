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
      timeEntryId: 'time-entry-1',
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
    testWidgets('renders dimension labels', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(RatingSummary)),
      )!;

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

    testWidgets('renders progress indicators for each dimension',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
    });

    testWidgets('renders challenge-skill text', (tester) async {
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

    testWidgets('renders challenge-skill "Too easy"', (tester) async {
      final entry = RatingEntry(
        meta: Metadata(
          id: 'rating-2',
          createdAt: DateTime(2024, 6, 15),
          updatedAt: DateTime(2024, 6, 15),
          dateFrom: DateTime(2024, 6, 15),
          dateTo: DateTime(2024, 6, 15),
        ),
        data: const RatingData(
          timeEntryId: 'time-entry-2',
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

    testWidgets('renders challenge-skill "Too challenging"', (tester) async {
      final entry = RatingEntry(
        meta: Metadata(
          id: 'rating-3',
          createdAt: DateTime(2024, 6, 15),
          updatedAt: DateTime(2024, 6, 15),
          dateFrom: DateTime(2024, 6, 15),
          dateTo: DateTime(2024, 6, 15),
        ),
        data: const RatingData(
          timeEntryId: 'time-entry-3',
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
          timeEntryId: 'time-entry-4',
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
}
