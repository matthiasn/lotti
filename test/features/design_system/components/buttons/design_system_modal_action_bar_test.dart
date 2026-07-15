import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';

import '../../../../widget_test_utils.dart';

void main() {
  DesignSystemButton secondaryBtn(String label) => DesignSystemButton(
    label: label,
    variant: DesignSystemButtonVariant.secondary,
    size: DesignSystemButtonSize.large,
    onPressed: () {},
  );

  DesignSystemButton primaryBtn(String label) => DesignSystemButton(
    label: label,
    size: DesignSystemButtonSize.large,
    fullWidth: true,
    onPressed: () {},
  );

  Future<void> pumpBar(
    WidgetTester tester,
    DesignSystemModalActionBar bar, {
    double width = 600,
  }) {
    return tester.pumpWidget(
      makeTestableWidgetWithScaffold(SizedBox(width: width, child: bar)),
    );
  }

  testWidgets('primary dominates: it renders wider than the intrinsic '
      'secondaries', (tester) async {
    await pumpBar(
      tester,
      DesignSystemModalActionBar(
        secondary: [secondaryBtn('Cancel'), secondaryBtn('Clear')],
        primary: primaryBtn('Done'),
      ),
    );
    await tester.pump();

    final cancelWidth = tester
        .getSize(find.widgetWithText(DesignSystemButton, 'Cancel'))
        .width;
    final clearWidth = tester
        .getSize(find.widgetWithText(DesignSystemButton, 'Clear'))
        .width;
    final doneWidth = tester
        .getSize(find.widgetWithText(DesignSystemButton, 'Done'))
        .width;

    expect(
      doneWidth,
      greaterThan(cancelWidth + clearWidth),
      reason: 'the primary should flex to fill the trailing width',
    );
  });

  testWidgets('the primary is the trailing flex child (wrapped in Expanded)', (
    tester,
  ) async {
    await pumpBar(
      tester,
      DesignSystemModalActionBar(
        secondary: [secondaryBtn('Cancel')],
        primary: primaryBtn('Done'),
      ),
    );
    await tester.pump();

    // Only the primary is inside an Expanded; the secondary keeps intrinsic
    // width.
    expect(
      find.ancestor(
        of: find.widgetWithText(DesignSystemButton, 'Done'),
        matching: find.byType(Expanded),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.widgetWithText(DesignSystemButton, 'Cancel'),
        matching: find.byType(Expanded),
      ),
      findsNothing,
    );
  });

  testWidgets('a larger gutter precedes the primary than sits between the '
      'secondaries', (tester) async {
    await pumpBar(
      tester,
      DesignSystemModalActionBar(
        secondary: [secondaryBtn('Cancel'), secondaryBtn('Clear')],
        primary: primaryBtn('Done'),
      ),
    );
    await tester.pump();

    // The bar's own gaps are the SizedBoxes that are direct children of its
    // Row (button internals use Padding/Row, not bare SizedBox gaps at this
    // level). Two gaps: step3 (between secondaries) and step5 (before primary).
    final row = tester.widget<Row>(
      find
          .descendant(
            of: find.byType(DesignSystemModalActionBar),
            matching: find.byType(Row),
          )
          .first,
    );
    final gapWidths = row.children
        .whereType<SizedBox>()
        .map((s) => s.width)
        .whereType<double>()
        .toList();

    expect(gapWidths.length, 2);
    expect(
      gapWidths.last,
      greaterThan(gapWidths.first),
      reason:
          'the gutter before the primary is wider than the inter-secondary '
          'gap so a destructive secondary is harder to fat-finger',
    );
  });

  testWidgets('a single primary (no secondaries) fills the row', (
    tester,
  ) async {
    await pumpBar(
      tester,
      DesignSystemModalActionBar(primary: primaryBtn('Save')),
    );
    await tester.pump();

    final saveWidth = tester
        .getSize(find.widgetWithText(DesignSystemButton, 'Save'))
        .width;
    expect(
      saveWidth,
      greaterThan(500),
      reason: 'a lone primary should fill most of the 600px row',
    );
  });

  testWidgets('narrow layouts wrap secondaries above a full-width primary', (
    tester,
  ) async {
    await pumpBar(
      tester,
      DesignSystemModalActionBar(
        secondary: [secondaryBtn('Cancel'), secondaryBtn('Clear')],
        primary: primaryBtn('Done'),
      ),
      width: 320,
    );
    await tester.pump();

    final cancelCenter = tester.getCenter(
      find.widgetWithText(DesignSystemButton, 'Cancel'),
    );
    final doneCenter = tester.getCenter(
      find.widgetWithText(DesignSystemButton, 'Done'),
    );
    final doneWidth = tester
        .getSize(find.widgetWithText(DesignSystemButton, 'Done'))
        .width;

    expect(doneCenter.dy, greaterThan(cancelCenter.dy));
    expect(doneWidth, 320);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact layout keeps an intrinsic primary on the same footer row',
    (tester) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          layout: DesignSystemModalActionBarLayout.compactPrimary,
          secondary: [secondaryBtn('Clear'), secondaryBtn('Save')],
          primary: DesignSystemButton(
            label: 'Apply',
            size: DesignSystemButtonSize.large,
            onPressed: () {},
          ),
        ),
      );
      await tester.pump();

      final clearCenter = tester.getCenter(
        find.widgetWithText(DesignSystemButton, 'Clear'),
      );
      final applyCenter = tester.getCenter(
        find.widgetWithText(DesignSystemButton, 'Apply'),
      );
      final applyWidth = tester
          .getSize(find.widgetWithText(DesignSystemButton, 'Apply'))
          .width;

      expect(applyCenter.dy, clearCenter.dy);
      expect(applyCenter.dx, greaterThan(clearCenter.dx));
      expect(applyWidth, lessThan(200));
      expect(
        find.ancestor(
          of: find.widgetWithText(DesignSystemButton, 'Apply'),
          matching: find.byType(Expanded),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'compact layout lets the secondary group wrap without widening primary',
    (tester) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          layout: DesignSystemModalActionBarLayout.compactPrimary,
          secondary: [
            secondaryBtn('Long clear action'),
            secondaryBtn('Long save action'),
          ],
          primary: DesignSystemButton(
            label: 'Apply',
            size: DesignSystemButtonSize.large,
            onPressed: () {},
          ),
        ),
        width: 320,
      );
      await tester.pump();

      final clearCenter = tester.getCenter(
        find.widgetWithText(DesignSystemButton, 'Long clear action'),
      );
      final saveCenter = tester.getCenter(
        find.widgetWithText(DesignSystemButton, 'Long save action'),
      );
      final applyWidth = tester
          .getSize(find.widgetWithText(DesignSystemButton, 'Apply'))
          .width;

      expect(saveCenter.dy, greaterThan(clearCenter.dy));
      expect(applyWidth, lessThan(200));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('glass: true renders the bar on a DesignSystemGlassStrip', (
    tester,
  ) async {
    await pumpBar(
      tester,
      DesignSystemModalActionBar(
        glass: true,
        secondary: [secondaryBtn('Cancel')],
        primary: primaryBtn('Done'),
      ),
    );
    await tester.pump();

    expect(find.byType(DesignSystemGlassStrip), findsOneWidget);
    // The buttons still render inside the glass surface.
    expect(find.widgetWithText(DesignSystemButton, 'Done'), findsOneWidget);
  });

  testWidgets('glass defaults to off (no DesignSystemGlassStrip)', (
    tester,
  ) async {
    await pumpBar(
      tester,
      DesignSystemModalActionBar(primary: primaryBtn('Save')),
    );
    await tester.pump();

    expect(find.byType(DesignSystemGlassStrip), findsNothing);
  });
}
