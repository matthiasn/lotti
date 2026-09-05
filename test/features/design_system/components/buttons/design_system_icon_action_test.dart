import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

// Promoted out of `backfill_settings_page.dart`, where it sat as
// `IconActionButton` — a design-system control declared in a feature page. The
// diagnostics panel, needing the same thing, had reached for a Material
// `IconButton` instead, so two refresh controls on neighbouring sync screens
// carried different ergonomics. These tests pin the behaviour both of them
// should have had.

void main() {
  const actionKey = Key('icon-action');

  Future<DsTokens> pump(
    WidgetTester tester, {
    VoidCallback? onPressed,
    bool isBusy = false,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        DesignSystemIconAction(
          key: actionKey,
          icon: LottiIcons.refresh,
          tooltip: 'Refresh',
          onPressed: onPressed,
          isBusy: isBusy,
        ),
      ),
    );
    await tester.pump();
    return tester.element(find.byType(DesignSystemIconAction)).designTokens;
  }

  group('DesignSystemIconAction', () {
    testWidgets('invokes its callback once per tap', (tester) async {
      var taps = 0;
      await pump(tester, onPressed: () => taps++);

      await tester.tap(find.byType(DesignSystemIconAction));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('a null callback makes the control inert, not just faded', (
      tester,
    ) async {
      final tokens = await pump(tester);

      final ink = tester.widget<InkWell>(find.byType(InkWell));
      expect(ink.onTap, isNull);

      final icon = tester.widget<Icon>(find.byIcon(LottiIcons.refresh));
      expect(icon.color, tokens.colors.text.lowEmphasis);
    });

    testWidgets('an enabled glyph sits a step above the disabled one', (
      tester,
    ) async {
      final tokens = await pump(tester, onPressed: () {});

      final icon = tester.widget<Icon>(find.byIcon(LottiIcons.refresh));
      expect(icon.color, tokens.colors.text.mediumEmphasis);
      expect(icon.color, isNot(tokens.colors.text.lowEmphasis));
    });

    testWidgets('busy swaps the glyph for a spinner of the same size', (
      tester,
    ) async {
      // The predecessor drew a 14px indicator behind a 16px glyph, so the
      // button changed size the moment it went busy — under the pointer that
      // had just pressed it.
      await pump(tester, onPressed: () {}, isBusy: true);

      expect(find.byIcon(LottiIcons.refresh), findsNothing);
      final spinner = tester.widget<DesignSystemSpinner>(
        find.byType(DesignSystemSpinner),
      );
      expect(spinner.size, IconSizes.s);
    });

    testWidgets('a busy control does not re-fire the action already running', (
      tester,
    ) async {
      // `isBusy` alone must make the control inert: the only action a busy
      // refresh button could re-trigger is the refresh already in flight.
      // `backfill_settings_stats.dart` also nulls `onPressed` while loading,
      // but a caller that forgets must not get double submits.
      var taps = 0;
      await pump(tester, onPressed: () => taps++, isBusy: true);

      final ink = tester.widget<InkWell>(find.byType(InkWell));
      expect(ink.onTap, isNull);

      await tester.tap(find.byKey(actionKey), warnIfMissed: false);
      await tester.pump();

      expect(taps, 0);
    });

    testWidgets('a busy control announces as disabled', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, onPressed: () {}, isBusy: true);

      final node = tester.getSemantics(find.byKey(actionKey));
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);

      handle.dispose();
    });

    testWidgets('the busy control keeps a stable footprint', (tester) async {
      await pump(tester, onPressed: () {});
      final idle = tester.getSize(find.byType(DesignSystemIconAction));

      await pump(tester, onPressed: () {}, isBusy: true);
      final busy = tester.getSize(find.byType(DesignSystemIconAction));

      expect(busy, idle);
    });

    testWidgets('a compact glyph still gets the full pointer target', (
      tester,
    ) async {
      // The glyph plus its inset is 16dp; a finger aiming at the top edge of
      // the control has to land on the callback, not beside it.
      var taps = 0;
      await pump(tester, onPressed: () => taps++);

      final target = tester.getRect(find.byKey(actionKey));
      expect(target.size, const Size(TapTargets.minimum, TapTargets.minimum));

      final glyph = tester.getRect(find.byIcon(LottiIcons.refresh));
      expect(glyph.size, const Size(IconSizes.s, IconSizes.s));
      expect(glyph.center, target.center);

      await tester.tapAt(Offset(target.center.dx, target.top + 1));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('announces one enabled button node carrying the tooltip', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester, onPressed: () {});

      final node = tester.getSemantics(find.byKey(actionKey));
      expect(node.label, 'Refresh');
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isEnabled, Tristate.isTrue);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(
        node.rect.size,
        const Size(TapTargets.minimum, TapTargets.minimum),
      );
      // The tooltip would otherwise contribute a second, unlabelled-as-button
      // node saying the same thing.
      expect(node.childrenCount, 0);

      handle.dispose();
    });

    testWidgets('a null callback announces the button as disabled', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      final node = tester.getSemantics(find.byKey(actionKey));
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isEnabled, Tristate.isFalse);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);

      handle.dispose();
    });

    testWidgets('the busy control keeps announcing which action is running', (
      tester,
    ) async {
      // While busy the glyph is gone, so the button node's label is the only
      // thing left that says which action it is.
      final handle = tester.ensureSemantics();
      await pump(tester, onPressed: () {}, isBusy: true);

      final node = tester.getSemantics(find.byKey(actionKey));
      expect(node.label, 'Refresh');
      expect(node.flagsCollection.isButton, isTrue);
      // The spinner's own node is excluded rather than read out alongside it.
      expect(node.childrenCount, 0);

      handle.dispose();
    });
  });
}
