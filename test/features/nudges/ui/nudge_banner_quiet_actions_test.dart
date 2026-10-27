import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_quiet_actions.dart';
import 'package:material_ui/material_ui.dart';

import '../../../test_utils/material_ui_finders.dart';
import '../../../widget_test_utils.dart';

void main() {
  const snoozeKey = ValueKey('snooze');

  Future<void> pump(
    WidgetTester tester, {
    required bool ratingDue,
    bool compact = false,
    VoidCallback? onRate,
    VoidCallback? onSnooze,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Align(
          alignment: Alignment.topRight,
          child: NudgeBannerQuietActions(
            ratingDue: ratingDue,
            compact: compact,
            snoozeKey: snoozeKey,
            onRate: onRate ?? () {},
            onSnooze: onSnooze ?? () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder rate() => find.widgetWithText(DesignSystemButton, 'Rate');

  testWidgets('both controls are the same quiet dense button with a glyph, '
      'so they share one ink, one glyph size and one floor', (tester) async {
    await pump(tester, ratingDue: true);

    final snooze = tester.widget<DesignSystemButton>(find.byKey(snoozeKey));
    final rating = tester.widget<DesignSystemButton>(rate());
    for (final button in [snooze, rating]) {
      expect(button.variant, DesignSystemButtonVariant.quiet);
      expect(button.size, DesignSystemButtonSize.dense);
      expect(button.tapTargetSize, MaterialTapTargetSize.padded);
    }
    expect(snooze.leadingIcon, LottiIcons.snooze);
    expect(rating.leadingIcon, LottiIcons.star);
    expect(findMaterialTooltip('Rate this banner'), findsOneWidget);

    double glyphSize(IconData icon) =>
        IconTheme.of(tester.element(find.byIcon(icon))).size!;
    expect(glyphSize(LottiIcons.star), IconSizes.s);
    expect(glyphSize(LottiIcons.snooze), IconSizes.s);

    final star = tester.getRect(rate());
    final snoozeRect = tester.getRect(find.byKey(snoozeKey));
    expect(star.height, TapTargets.minimum);
    expect(snoozeRect.height, TapTargets.minimum);
    expect(star.center.dy, snoozeRect.center.dy);
    expect(star.right, lessThanOrEqualTo(snoozeRect.left));
  });

  testWidgets('tapping dispatches to the right callback', (tester) async {
    var rated = 0;
    var snoozed = 0;
    await pump(
      tester,
      ratingDue: true,
      onRate: () => rated++,
      onSnooze: () => snoozed++,
    );
    await tester.tap(rate());
    await tester.tap(find.text('Snooze'));
    expect(rated, 1);
    expect(snoozed, 1);
  });

  testWidgets('without a rating due Rate is hidden but keeps its footprint: '
      'the row keeps its width, Snooze does not move, and nothing is '
      'tappable or announced in the gap', (tester) async {
    await pump(tester, ratingDue: true);
    final withStar = tester.getSize(find.byType(NudgeBannerQuietActions));
    final snoozeWithStar = tester.getRect(find.byKey(snoozeKey));

    var rated = 0;
    await pump(tester, ratingDue: false, onRate: () => rated++);
    expect(rate().hitTestable(), findsNothing);
    expect(
      findMaterialTooltip('Rate this banner').hitTestable(),
      findsNothing,
      reason:
          'Rate keeps its footprint while hidden, but is neither visible '
          'nor reachable',
    );
    expect(tester.getSize(find.byType(NudgeBannerQuietActions)), withStar);
    expect(tester.getRect(find.byKey(snoozeKey)), snoozeWithStar);
    await tester.tapAt(snoozeWithStar.centerLeft - const Offset(24, 0));
    expect(rated, 0);

    final handle = tester.ensureSemantics();
    await tester.pump();
    var root = tester.getSemantics(find.byKey(snoozeKey));
    while (root.parent != null) {
      root = root.parent!;
    }
    final labels = <String>[];
    void collect(SemanticsNode node) {
      labels.add(node.label);
      node.visitChildren((SemanticsNode child) {
        collect(child);
        return true;
      });
    }

    collect(root);
    handle.dispose();
    expect(labels, contains('Snooze'));
    expect(labels, isNot(contains('Rate')));
    expect(labels, isNot(contains('Rate this banner')));
  });

  testWidgets('on a compact host above the large text scale the pair is '
      'its glyphs alone, each still named by tooltip and semantics, and Rate '
      'still keeps its footprint while hidden; a wide host keeps the labels', (
    tester,
  ) async {
    Future<void> pumpScaled({
      required bool ratingDue,
      bool compact = true,
    }) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Align(
              alignment: Alignment.topRight,
              child: NudgeBannerQuietActions(
                ratingDue: ratingDue,
                compact: compact,
                snoozeKey: snoozeKey,
                onRate: () {},
                onSnooze: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpScaled(ratingDue: true, compact: false);
    expect(find.text('Rate'), findsOneWidget);
    expect(find.text('Snooze'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pumpScaled(ratingDue: true);
    expect(find.byType(DesignSystemButton), findsNothing);
    expect(find.text('Rate'), findsNothing);
    expect(find.text('Snooze'), findsNothing);
    expect(findMaterialTooltip('Rate this banner'), findsOneWidget);
    expect(findMaterialTooltip('Snooze'), findsOneWidget);
    final width = tester.getSize(find.byType(NudgeBannerQuietActions)).width;
    expect(width, TapTargets.minimum * 2);

    await pumpScaled(ratingDue: false);
    expect(findMaterialTooltip('Rate this banner').hitTestable(), findsNothing);
    expect(tester.getSize(find.byType(NudgeBannerQuietActions)).width, width);
  });

  testWidgets('Snooze ends its label on the trailing edge of its host, where '
      "the row's other trailing content ends", (tester) async {
    await pump(tester, ratingDue: false);
    final snooze = tester.widget<DesignSystemButton>(find.byKey(snoozeKey));
    expect(snooze.alignsLabelToTrailingEdge, isTrue);
    final host = tester.getRect(find.byType(Align));
    final label = tester.getRect(find.text('Snooze'));
    expect(label.right, closeTo(host.right, 1));
  });
}
