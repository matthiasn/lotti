import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';
import 'package:lotti/features/design_system/components/celebration/completion_burst.dart';
import 'package:lotti/features/settings/ui/widgets/celebration_variant_picker.dart';

import '../../../../widget_test_utils.dart';

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });
  tearDown(tearDownTestGetIt);

  CelebrationVariantCard cardFor(WidgetTester tester, String label) =>
      tester.widget<CelebrationVariantCard>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(CelebrationVariantCard),
        ),
      );

  /// Pumps a picker, capturing every [CelebrationVariantPicker.onSelect] call
  /// into [selections] so a tap's reported variant can be asserted directly —
  /// the picker is presentational, so the selection is the callback, not a write.
  Future<void> pump(
    WidgetTester tester, {
    required List<CelebrationVariant> selections,
    CelebrationVariant selected = CelebrationVariant.sparks,
    bool enabled = true,
    bool reduceMotion = false,
  }) async {
    final picker = CelebrationVariantPicker(
      enabled: enabled,
      selected: selected,
      onSelect: selections.add,
    );
    final child = reduceMotion
        ? Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: picker,
            ),
          )
        : picker;
    await tester.pumpWidget(makeTestableWidgetWithScaffold(child));
    await tester.pump();
  }

  testWidgets('renders one card per variant, each with its localized label', (
    tester,
  ) async {
    await pump(tester, selections: []);

    expect(find.byType(CelebrationVariantCard), findsNWidgets(5));
    for (final label in const [
      'Sparks',
      'Fireworks',
      'Confetti',
      'Embers',
      'Bubbles',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('marks the passed selected variant as selected', (tester) async {
    await pump(
      tester,
      selections: [],
      selected: CelebrationVariant.confetti,
    );

    expect(cardFor(tester, 'Confetti').selected, isTrue);
    expect(cardFor(tester, 'Sparks').selected, isFalse);
  });

  testWidgets('tapping a card reports it through onSelect', (tester) async {
    final selections = <CelebrationVariant>[];
    await pump(tester, selections: selections);

    await tester.tap(find.text('Embers'));
    await tester.pump();

    expect(selections, [CelebrationVariant.embers]);

    await tester.pumpAndSettle();
  });

  testWidgets('tapping a card plays its contained preview burst', (
    tester,
  ) async {
    await pump(tester, selections: []);
    // No burst at rest — the cards show a resting dot + play hint.
    expect(find.byType(CompletionBurst), findsNothing);

    await tester.tap(find.text('Confetti'));
    // Drive into the card's 1200ms preview window.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final burst = tester.widget<CompletionBurst>(find.byType(CompletionBurst));
    expect(burst.variant, CelebrationVariant.confetti);

    await tester.pumpAndSettle();
  });

  testWidgets('under reduce motion, a tap selects but plays no preview burst', (
    tester,
  ) async {
    final selections = <CelebrationVariant>[];
    await pump(tester, selections: selections, reduceMotion: true);

    await tester.tap(find.text('Bubbles'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Selection still reported …
    expect(selections, [CelebrationVariant.bubbles]);
    // … but the preview animation is suppressed, like the live surfaces.
    expect(find.byType(CompletionBurst), findsNothing);
  });

  testWidgets('greys out and ignores taps when disabled', (tester) async {
    final selections = <CelebrationVariant>[];
    await pump(tester, selections: selections, enabled: false);

    // The whole picker is dimmed and non-interactive.
    final opacity = tester.widget<Opacity>(
      find
          .ancestor(
            of: find.byType(CelebrationVariantCard).first,
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(opacity.opacity, lessThan(1));
    final ignore = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byType(CelebrationVariantCard).first,
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(ignore.ignoring, isTrue);

    // A tap on a card does nothing — onSelect is never called.
    await tester.tap(find.text('Embers'), warnIfMissed: false);
    await tester.pump();
    expect(selections, isEmpty);
  });
}
