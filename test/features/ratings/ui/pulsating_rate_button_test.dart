import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/ratings/repository/rating_repository.dart';
import 'package:lotti/features/ratings/ui/pulsating_rate_button.dart';
import 'package:lotti/features/ratings/ui/session_rating_modal.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  const testEntryId = 'entry-1';

  late MockRatingRepository mockRepository;

  setUp(() async {
    await setUpTestGetIt();
    mockRepository = MockRatingRepository();
    when(
      () => mockRepository.getRatingForTargetEntry(testEntryId),
    ).thenAnswer((_) async => null);
  });

  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    bool sessionJustEnded = true,
    bool ratingsEnabled = true,
    List<Override> extraOverrides = const [],
  }) {
    return makeTestableWidgetWithScaffold(
      PulsatingRateButton(
        entryId: testEntryId,
        sessionJustEnded: sessionJustEnded,
      ),
      overrides: [
        configFlagProvider(
          enableSessionRatingsFlag,
        ).overrideWith((_) => Stream.value(ratingsEnabled)),
        ratingRepositoryProvider.overrideWithValue(mockRepository),
        ...extraOverrides,
      ],
    );
  }

  /// Pumps enough frames to complete all 5 pulse cycles
  /// (each cycle = 2 seconds: 1s forward + 1s reverse).
  Future<void> drainPulseAnimation(WidgetTester tester) async {
    // 5 cycles × 2 seconds = 10 seconds, plus a small buffer
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    // One extra pump to settle
    await tester.pump();
  }

  group('PulsatingRateButton', () {
    testWidgets('hidden when ratings flag is disabled', (tester) async {
      await tester.pumpWidget(
        buildSubject(ratingsEnabled: false),
      );
      await tester.pump();

      expect(find.text('Rate Session'), findsNothing);
    });

    testWidgets('visible when ratings enabled and session just ended', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text('Rate Session'), findsOneWidget);
      expect(find.byIcon(Icons.star_rate_outlined), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);

      // Drain animation to avoid pending timer errors
      await drainPulseAnimation(tester);
    });

    testWidgets('hidden when session has not just ended and no rating', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(sessionJustEnded: false),
      );
      await tester.pump();

      expect(find.text('Rate Session'), findsNothing);
    });

    testWidgets('button remains visible after pulse animation completes', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text('Rate Session'), findsOneWidget);

      // Drain all pulse cycles
      await drainPulseAnimation(tester);

      // Button should still be visible (just not pulsing anymore)
      expect(find.text('Rate Session'), findsOneWidget);
    });

    testWidgets('tapping button opens rating modal', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Drain pulse animation first so tap target is stable
      await drainPulseAnimation(tester);

      await tester.tap(find.byType(OutlinedButton));
      // Use pump with duration instead of pumpAndSettle — the modal
      // may contain animations that never fully settle.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verify the RatingModal was shown as a modal bottom sheet
      expect(find.byType(RatingModal), findsOneWidget);
    });
  });
}
