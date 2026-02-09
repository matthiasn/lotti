import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/rating_data.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/action_menu_list_item.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/modern_action_items.dart';
import 'package:lotti/features/ratings/state/rating_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../../../test_helper.dart';

/// Fake RatingController that returns null (no existing rating).
class _FakeNoRatingController extends RatingController {
  @override
  Future<JournalEntity?> build({required String targetId}) async {
    state = const AsyncData(null);
    return null;
  }
}

/// Fake RatingController that returns an existing rating.
class _FakeHasRatingController extends RatingController {
  @override
  Future<JournalEntity?> build({required String targetId}) async {
    final testDate = DateTime(2025, 12, 31, 12);
    final entity = RatingEntry(
      meta: Metadata(
        id: 'rating-1',
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate,
      ),
      data: RatingData(
        targetId: targetId,
        dimensions: const [
          RatingDimension(key: 'productivity', value: 0.8),
          RatingDimension(key: 'energy', value: 0.6),
          RatingDimension(key: 'focus', value: 0.9),
          RatingDimension(key: 'challenge_skill', value: 0.5),
        ],
      ),
    );
    state = AsyncData(entity);
    return entity;
  }
}

void main() {
  const entryId = 'time-entry-1';

  group('ModernRateSessionItem', () {
    testWidgets('shows "Rate Session" with outline icon when no rating exists',
        (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(true),
            ),
            ratingControllerProvider(targetId: entryId)
                .overrideWith(_FakeNoRatingController.new),
          ],
          child: const ModernRateSessionItem(entryId: entryId),
        ),
      );

      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ModernRateSessionItem));
      expect(find.byType(ActionMenuListItem), findsOneWidget);
      expect(find.byIcon(Icons.star_rate_outlined), findsOneWidget);
      expect(
        find.text(context.messages.sessionRatingRateAction),
        findsOneWidget,
      );
    });

    testWidgets('hidden when feature flag is disabled', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(false),
            ),
            ratingControllerProvider(targetId: entryId)
                .overrideWith(_FakeNoRatingController.new),
          ],
          child: const ModernRateSessionItem(entryId: entryId),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(ActionMenuListItem), findsNothing);
    });

    testWidgets('shows "View Rating" with filled icon when rating exists',
        (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            configFlagProvider.overrideWith(
              (ref, flagName) => Stream.value(true),
            ),
            ratingControllerProvider(targetId: entryId)
                .overrideWith(_FakeHasRatingController.new),
          ],
          child: const ModernRateSessionItem(entryId: entryId),
        ),
      );

      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ModernRateSessionItem));
      expect(find.byType(ActionMenuListItem), findsOneWidget);
      expect(find.byIcon(Icons.star_rate_rounded), findsOneWidget);
      expect(
        find.text(context.messages.sessionRatingViewAction),
        findsOneWidget,
      );
    });
  });
}
