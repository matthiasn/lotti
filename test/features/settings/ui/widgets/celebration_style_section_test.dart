import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';
import 'package:lotti/features/settings/state/celebration_preferences_controller.dart';
import 'package:lotti/features/settings/ui/widgets/celebration_style_section.dart';
import 'package:lotti/features/settings/ui/widgets/celebration_variant_picker.dart';
import 'package:lotti/get_it.dart';
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

  // Distinct variant per surface so we can prove the single picker binds to the
  // active surface rather than a shared value.
  const prefs = CelebrationPreferences(
    enabled: true,
    haptics: true,
    habits: true,
    checklistItems: true,
    tasks: true,
    tasksVariant: CelebrationVariant.sparks,
    habitsVariant: CelebrationVariant.confetti,
    checklistItemsVariant: CelebrationVariant.bubbles,
  );

  Future<void> pump(WidgetTester tester, {bool enabled = true}) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        CelebrationStyleSection(enabled: enabled),
        overrides: [
          celebrationPreferencesProvider.overrideWithValue(prefs),
        ],
      ),
    );
    await tester.pump();
  }

  CelebrationVariantPicker picker(WidgetTester tester) =>
      tester.widget<CelebrationVariantPicker>(
        find.byType(CelebrationVariantPicker),
      );

  Finder cardLabel(String label) => find.descendant(
    of: find.byType(CelebrationVariantCard),
    matching: find.text(label),
  );

  // DsSegmentedToggle renders each label twice — an invisible width-ghost plus
  // the visible Text (the Stack's last child) — so a plain find.text matches
  // two. Tap / read the visible one.
  Finder segment(String label) => find.text(label).last;

  testWidgets('shows one picker, not one per surface', (tester) async {
    await pump(tester);
    // The whole point of the redesign: a single picker, re-bound by surface.
    expect(find.byType(CelebrationVariantPicker), findsOneWidget);
    // Five style cards exist exactly once (not 15).
    expect(find.byType(CelebrationVariantCard), findsNWidgets(5));
  });

  testWidgets('lists the three surfaces without echoing assigned styles', (
    tester,
  ) async {
    await pump(tester);

    // All three surfaces are listed as single-line segments.
    for (final label in const ['Tasks', 'Habits', 'Checklist items']) {
      expect(segment(label), findsOneWidget, reason: label);
    }
    // The assigned style names appear only as picker cards now (one each), not
    // duplicated as a segment subtitle — that summary was dropped when the
    // selector moved to the shared single-line segmented control.
    for (final variant in const ['Sparks', 'Confetti', 'Bubbles']) {
      expect(find.text(variant), findsOneWidget, reason: variant);
    }
  });

  testWidgets('the picker binds to the active surface (tasks by default)', (
    tester,
  ) async {
    await pump(tester);
    expect(picker(tester).selected, CelebrationVariant.sparks);
  });

  testWidgets('selecting a surface re-binds the picker to its variant', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(segment('Habits'));
    await tester.pump();
    expect(picker(tester).selected, CelebrationVariant.confetti);

    await tester.tap(segment('Checklist items'));
    await tester.pump();
    expect(picker(tester).selected, CelebrationVariant.bubbles);
  });

  testWidgets('tapping a style card persists it for the active surface', (
    tester,
  ) async {
    await pump(tester);

    // Switch to Habits, then pick Embers from the single picker.
    await tester.tap(segment('Habits'));
    await tester.pump();
    await tester.tap(cardLabel('Embers'));
    await tester.pump();

    verify(
      () => getIt<SettingsDb>().saveSettingsItem(
        'CELEBRATE_VARIANT_HABITS',
        'embers',
      ),
    ).called(1);

    await tester.pumpAndSettle();
  });

  testWidgets('greys out and ignores taps when disabled', (tester) async {
    await pump(tester, enabled: false);

    expect(picker(tester).enabled, isFalse);
    // The surface selector is also inert: tapping a segment does not change the
    // bound variant (still the default-active tasks → sparks).
    await tester.tap(segment('Habits'), warnIfMissed: false);
    await tester.pump();
    expect(picker(tester).selected, CelebrationVariant.sparks);
  });
}
