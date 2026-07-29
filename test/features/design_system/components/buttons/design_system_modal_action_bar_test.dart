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
    Widget bar, {
    double width = 600,
    double textScale = 1,
  }) {
    return tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SizedBox(width: width, child: bar),
        mediaQueryData: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
        ),
      ),
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
    'compact layout keeps short phone actions on one row when they fit',
    (tester) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          layout: DesignSystemModalActionBarLayout.compactPrimary,
          secondary: [
            DesignSystemButton(
              label: 'Cancel',
              variant: DesignSystemButtonVariant.secondary,
              size: DesignSystemButtonSize.medium,
              tapTargetSize: MaterialTapTargetSize.padded,
              onPressed: () {},
            ),
          ],
          primary: DesignSystemButton(
            label: 'Start sync',
            size: DesignSystemButtonSize.medium,
            fullWidth: true,
            tapTargetSize: MaterialTapTargetSize.padded,
            onPressed: () {},
          ),
        ),
        width: 310,
      );
      await tester.pump();

      final cancel = find.widgetWithText(DesignSystemButton, 'Cancel');
      final start = find.widgetWithText(DesignSystemButton, 'Start sync');
      expect(tester.getCenter(start).dy, tester.getCenter(cancel).dy);
      expect(tester.getSize(start).width, lessThan(200));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact layout wraps intrinsic actions when labels do not fit',
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
      final applyCenter = tester.getCenter(
        find.widgetWithText(DesignSystemButton, 'Apply'),
      );
      final applyWidth = tester
          .getSize(find.widgetWithText(DesignSystemButton, 'Apply'))
          .width;
      final barRect = tester.getRect(find.byType(DesignSystemModalActionBar));
      final clearRect = tester.getRect(
        find.widgetWithText(DesignSystemButton, 'Long clear action'),
      );
      final saveRect = tester.getRect(
        find.widgetWithText(DesignSystemButton, 'Long save action'),
      );
      final applyRect = tester.getRect(
        find.widgetWithText(DesignSystemButton, 'Apply'),
      );

      expect(applyCenter.dy, greaterThan(clearCenter.dy));
      expect(applyCenter.dy, greaterThan(saveCenter.dy));
      expect(clearRect.left, closeTo(barRect.left, 0.1));
      expect(saveRect.left, closeTo(barRect.left, 0.1));
      expect(applyRect.right, closeTo(barRect.right, 0.1));
      expect(applyWidth, lessThan(320));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact layout bounds an overlong action to the available width',
    (tester) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          layout: DesignSystemModalActionBarLayout.compactPrimary,
          secondary: [
            secondaryBtn(
              'A translated secondary action that cannot fit intrinsically',
            ),
          ],
          primary: DesignSystemButton(
            label: 'A translated primary action that cannot fit intrinsically',
            fullWidth: true,
            onPressed: () {},
          ),
        ),
        width: 160,
      );
      await tester.pump();

      final primary = find.widgetWithText(
        DesignSystemButton,
        'A translated primary action that cannot fit intrinsically',
      );
      final secondary = find.widgetWithText(
        DesignSystemButton,
        'A translated secondary action that cannot fit intrinsically',
      );
      expect(tester.getSize(primary).width, 160);
      expect(tester.getSize(secondary).width, 160);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact layout updates its groups and respects RTL edges',
    (tester) async {
      await pumpBar(
        tester,
        Directionality(
          textDirection: TextDirection.ltr,
          child: DesignSystemModalActionBar(
            layout: DesignSystemModalActionBarLayout.compactPrimary,
            primary: primaryBtn('Apply'),
          ),
        ),
        width: 320,
      );
      await tester.pump();

      await pumpBar(
        tester,
        Directionality(
          textDirection: TextDirection.rtl,
          child: DesignSystemModalActionBar(
            layout: DesignSystemModalActionBarLayout.compactPrimary,
            secondary: [secondaryBtn('Clear')],
            primary: primaryBtn('Apply'),
          ),
        ),
        width: 320,
      );
      await tester.pump();

      final barRect = tester.getRect(find.byType(DesignSystemModalActionBar));
      final clearRect = tester.getRect(
        find.widgetWithText(DesignSystemButton, 'Clear'),
      );
      final applyRect = tester.getRect(
        find.widgetWithText(DesignSystemButton, 'Apply'),
      );
      expect(clearRect.right, closeTo(barRect.right, 0.1));
      expect(applyRect.left, closeTo(barRect.left, 0.1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact layout stacks at 200% text scale without clipping long actions',
    (tester) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          layout: DesignSystemModalActionBarLayout.compactPrimary,
          secondary: [
            secondaryBtn('Șterge filtrele'),
            secondaryBtn('Salvează filtrul'),
          ],
          primary: DesignSystemButton(
            label: 'Aplică filtrele',
            size: DesignSystemButtonSize.large,
            onPressed: () {},
          ),
        ),
        width: 320,
        textScale: 2,
      );
      await tester.pump();

      final clearCenter = tester.getCenter(
        find.widgetWithText(DesignSystemButton, 'Șterge filtrele'),
      );
      final applyFinder = find.widgetWithText(
        DesignSystemButton,
        'Aplică filtrele',
      );
      expect(tester.getCenter(applyFinder).dy, greaterThan(clearCenter.dy));
      expect(tester.getSize(applyFinder).width, 320);
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
