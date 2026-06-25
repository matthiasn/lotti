import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_selection.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';
import 'package:lotti/features/design_system/components/celebration/completion_burst.dart';
import 'package:lotti/features/settings/state/celebration_preferences_controller.dart';
import 'package:lotti/features/settings/ui/widgets/celebration_preview_stage.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';

void main() {
  setUp(() async {
    final mocks = await setUpTestGetIt();
    when(
      () => mocks.settingsDb.saveSettingsItem(any(), any()),
    ).thenAnswer((_) async => 1);
  });
  tearDown(tearDownTestGetIt);

  Future<void> pump(
    WidgetTester tester, {
    bool enabled = true,
    CelebrationVariant tasksVariant = CelebrationVariant.sparks,
    CelebrationVariant habitsVariant = CelebrationVariant.sparks,
    CelebrationVariant checklistItemsVariant = CelebrationVariant.sparks,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        CelebrationPreviewStage(enabled: enabled),
        overrides: [
          celebrationPreferencesProvider.overrideWithValue(
            const CelebrationPreferences.allEnabled().copyWith(
              tasksSelection: FixedSelection(tasksVariant),
              habitsSelection: FixedSelection(habitsVariant),
              checklistItemsSelection: FixedSelection(checklistItemsVariant),
            ),
          ),
        ],
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the three dummy completion controls', (tester) async {
    await pump(tester);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Check me'), findsOneWidget);
    expect(find.text('Habit'), findsOneWidget);
  });

  testWidgets('tapping a control fires a burst of the selected variant', (
    tester,
  ) async {
    await pump(tester, tasksVariant: CelebrationVariant.fireworks);
    expect(find.byType(CompletionBurst), findsNothing);

    await tester.tap(find.text('Done'));
    await tester.pump(); // schedule the overlay burst
    await tester.pump(const Duration(milliseconds: 100)); // build + start
    await tester.pump(const Duration(milliseconds: 300)); // into its window

    final burst = tester.widget<CompletionBurst>(find.byType(CompletionBurst));
    expect(burst.params?.variant, CelebrationVariant.fireworks);

    await tester.pumpAndSettle();
  });

  testWidgets('each control previews its own content type variant', (
    tester,
  ) async {
    await pump(
      tester,
      tasksVariant: CelebrationVariant.fireworks,
      habitsVariant: CelebrationVariant.confetti,
      checklistItemsVariant: CelebrationVariant.bubbles,
    );

    Future<CelebrationVariant> burstVariantFor(String label) async {
      await tester.tap(find.text(label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      final burst = tester.widget<CompletionBurst>(
        find.byType(CompletionBurst),
      );
      final variant = burst.params?.variant;
      await tester.pumpAndSettle();
      return variant!;
    }

    expect(await burstVariantFor('Done'), CelebrationVariant.fireworks);
    expect(await burstVariantFor('Habit'), CelebrationVariant.confetti);
    expect(await burstVariantFor('Check me'), CelebrationVariant.bubbles);
  });

  testWidgets('each control can be played independently', (tester) async {
    await pump(tester);

    for (final label in const ['Done', 'Check me', 'Habit']) {
      await tester.tap(find.text(label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CompletionBurst), findsOneWidget, reason: label);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('a combine selection fires a layered (two-variant) burst', (
    tester,
  ) async {
    debugResetCelebrationSeed();
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const CelebrationPreviewStage(),
        overrides: [
          celebrationPreferencesProvider.overrideWithValue(
            const CelebrationPreferences.allEnabled().copyWith(
              tasksSelection: const CombineSelection(),
            ),
          ),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Done'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));

    final burst = tester.widget<CompletionBurst>(find.byType(CompletionBurst));
    expect(burst.secondParams, isNotNull);
    expect(burst.secondParams!.variant, isNot(burst.params!.variant));

    await tester.pumpAndSettle();
  });

  testWidgets('greys out and ignores taps when disabled', (tester) async {
    await pump(tester, enabled: false);

    final opacity = tester.widget<Opacity>(
      find
          .ancestor(of: find.text('Done'), matching: find.byType(Opacity))
          .first,
    );
    expect(opacity.opacity, lessThan(1));

    await tester.tap(find.text('Done'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Disabled → the tap is swallowed, no burst plays.
    expect(find.byType(CompletionBurst), findsNothing);

    await tester.pumpAndSettle();
  });
}
