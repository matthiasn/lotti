import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_toggle_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

DsTokens _tokens(WidgetTester tester) =>
    tester.element(find.byType(DsActionToggleChip).first).designTokens;

BoxDecoration _decoration(WidgetTester tester) {
  final container = tester.widget<AnimatedContainer>(
    find.descendant(
      of: find.byType(DsActionToggleChip),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return container.decoration! as BoxDecoration;
}

Widget _chip({
  required bool selected,
  VoidCallback? onToggle,
}) {
  return DsActionToggleChip(
    label: 'Favorite',
    icon: selected ? LottiIconsFilled.star : LottiIcons.star,
    selected: selected,
    onToggle: onToggle ?? () {},
  );
}

void main() {
  group('DsActionToggleChip', () {
    testWidgets('off is an outline on nothing', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(_chip(selected: false)),
      );

      final tokens = _tokens(tester);
      final decoration = _decoration(tester);
      expect(decoration.color, Colors.transparent);
      expect(
        (decoration.border! as Border).top.color,
        tokens.colors.decorative.level01,
      );
      expect(
        tester.widget<Icon>(find.byIcon(LottiIcons.star)).color,
        tokens.colors.text.mediumEmphasis,
      );
      expect(
        tester.widget<Text>(find.text('Favorite')).style?.color,
        tokens.colors.text.mediumEmphasis,
      );
    });

    testWidgets('on tints fill, border, glyph and label in one accent', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(_chip(selected: true)),
      );

      final tokens = _tokens(tester);
      final accent = tokens.colors.interactive.enabled;
      final decoration = _decoration(tester);
      expect(decoration.color, tokens.colors.surface.selected);
      expect(
        (decoration.border! as Border).top.color,
        accent.withValues(alpha: DsActionToggleChip.selectedBorderAlpha),
      );
      expect(
        tester.widget<Icon>(find.byIcon(LottiIconsFilled.star)).color,
        accent,
      );
      expect(tester.widget<Text>(find.text('Favorite')).style?.color, accent);
    });

    testWidgets('the pill stands 36 high — a 20pt line box in step3 padding', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Align(child: _chip(selected: false)),
        ),
      );

      final tokens = _tokens(tester);
      expect(
        tester.getSize(find.byType(DsActionToggleChip)).height,
        tokens.typography.lineHeight.bodySmall + tokens.spacing.step3 * 2,
      );
    });

    testWidgets('tapping reports the toggle without rebuilding state itself', (
      tester,
    ) async {
      var toggles = 0;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          _chip(selected: false, onToggle: () => toggles++),
        ),
      );

      await tester.tap(find.byType(DsActionToggleChip));
      await tester.pump();

      expect(toggles, 1);
      // The chip is controlled: it does not flip its own look on tap, so a
      // failed write can never leave the sheet lying about the entry.
      expect(_decoration(tester).color, Colors.transparent);
    });

    testWidgets('announces itself as a toggle in its current state', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(_chip(selected: true)),
      );

      final semantics = tester.getSemantics(
        find.byType(DsActionToggleChip),
      );
      expect(semantics.label, 'Favorite');
      expect(semantics.flagsCollection.isToggled, Tristate.isTrue);
      expect(semantics.flagsCollection.isButton, isTrue);
      // The node must carry the tap itself: `excludeSemantics` drops the
      // InkWell's, so without this a screen reader announces a toggle it
      // cannot activate.
      expect(
        semantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
    });

    testWidgets('assistive activation reaches onToggle', (tester) async {
      var toggles = 0;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          _chip(selected: false, onToggle: () => toggles++),
        ),
      );

      final handle = tester.ensureSemantics();
      // ignore: deprecated_member_use
      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        tester.getSemantics(find.byType(DsActionToggleChip)).id,
        SemanticsAction.tap,
      );
      await tester.pump();
      handle.dispose();

      expect(toggles, 1);
    });
  });
}
