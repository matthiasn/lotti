import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

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

  DesignSystemButton intrinsicPrimaryBtn(String label) => DesignSystemButton(
    label: label,
    size: DesignSystemButtonSize.large,
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

  Finder btn(String label) => find.widgetWithText(DesignSystemButton, label);
  Rect rectOf(WidgetTester tester, String label) => tester.getRect(btn(label));
  double widthOf(WidgetTester tester, String label) =>
      tester.getSize(btn(label)).width;

  Rect barRect(WidgetTester tester) =>
      tester.getRect(find.byType(DesignSystemModalActionBar));

  /// The bar's own render object — the flow that measures and places the
  /// groups. Reached by type name because the flow is a private implementation
  /// detail of the component.
  RenderBox flowRenderBox(WidgetTester tester) {
    final flow = find.descendant(
      of: find.byType(DesignSystemModalActionBar),
      matching: find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_ActionFlow',
      ),
    );
    expect(flow, findsOneWidget);
    return tester.renderObject<RenderBox>(flow);
  }

  List<RenderBox> flowChildren(RenderBox flow) {
    final children = <RenderBox>[];
    flow.visitChildren((child) => children.add(child as RenderBox));
    return children;
  }

  // ---------------------------------------------------------------------------
  // dominantPrimary — the primary takes the width the secondaries leave.
  // ---------------------------------------------------------------------------
  group('dominantPrimary, labels fit', () {
    testWidgets('the primary flexes wider than the intrinsic secondaries', (
      tester,
    ) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          secondary: [secondaryBtn('Cancel'), secondaryBtn('Clear')],
          primary: primaryBtn('Done'),
        ),
      );

      expect(
        widthOf(tester, 'Done'),
        greaterThan(widthOf(tester, 'Cancel') + widthOf(tester, 'Clear')),
        reason: 'the primary should flex to fill the trailing width',
      );
    });

    testWidgets('the primary consumes exactly the width left over', (
      tester,
    ) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          secondary: [secondaryBtn('Cancel')],
          primary: primaryBtn('Done'),
        ),
      );

      final bar = barRect(tester);
      final cancel = rectOf(tester, 'Cancel');
      final done = rectOf(tester, 'Done');

      expect(cancel.left, closeTo(bar.left, 0.1));
      expect(done.right, closeTo(bar.right, 0.1));
      // No dead space: the primary starts one gutter after the secondary ends.
      expect(done.left - cancel.right, dsTokensLight.spacing.step5);
      expect(
        done.width,
        bar.width - cancel.width - dsTokensLight.spacing.step5,
      );
    });

    testWidgets('a lone primary fills the whole bar', (tester) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(primary: primaryBtn('Save')),
      );

      expect(widthOf(tester, 'Save'), 600);
      expect(rectOf(tester, 'Save').left, closeTo(barRect(tester).left, 0.1));
    });

    testWidgets('the gutter before the primary exceeds the gap between the '
        'secondaries', (tester) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          secondary: [secondaryBtn('Cancel'), secondaryBtn('Clear')],
          primary: primaryBtn('Done'),
        ),
      );

      final interSecondaryGap =
          rectOf(tester, 'Clear').left - rectOf(tester, 'Cancel').right;
      final gutterBeforePrimary =
          rectOf(tester, 'Done').left - rectOf(tester, 'Clear').right;

      expect(interSecondaryGap, dsTokensLight.spacing.step3);
      expect(gutterBeforePrimary, dsTokensLight.spacing.step5);
      expect(
        gutterBeforePrimary,
        greaterThan(interSecondaryGap),
        reason:
            'the gutter before the primary is wider than the inter-secondary '
            'gap so a destructive secondary is harder to fat-finger',
      );
    });

    testWidgets('all actions share one row, vertically centred', (
      tester,
    ) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          secondary: [secondaryBtn('Cancel')],
          primary: primaryBtn('Done'),
        ),
      );

      expect(
        tester.getCenter(btn('Done')).dy,
        tester.getCenter(btn('Cancel')).dy,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // The regression this component was fixed for: the fit decision must come
  // from the labels, not from a width threshold. Each case below overflowed the
  // row and collapsed the primary to zero width under the old thresholds.
  // ---------------------------------------------------------------------------
  group('dominantPrimary, labels do not fit', () {
    testWidgets('a long localized pair wraps instead of overflowing at 360', (
      tester,
    ) async {
      const cancel = 'Abbrechen und zurückkehren';
      const confirm = 'Datenbank endgültig löschen';
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          secondary: [secondaryBtn(cancel)],
          primary: primaryBtn(confirm),
        ),
        width: 360,
      );

      expect(
        tester.takeException(),
        isNull,
        reason: 'the row must not overflow — 360 is a common handset width',
      );
      expect(
        widthOf(tester, confirm),
        360,
        reason: 'the confirm action collapsed to zero width before the fix',
      );
      expect(
        tester.getCenter(btn(confirm)).dy,
        greaterThan(tester.getCenter(btn(cancel)).dy),
      );
    });

    testWidgets('a single secondary wider than the bar wraps and is bounded', (
      tester,
    ) async {
      const cancel = 'Alle lokalen Daten unwiderruflich entfernen';
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          secondary: [secondaryBtn(cancel)],
          primary: primaryBtn('Löschen'),
        ),
        width: 360,
      );

      expect(tester.takeException(), isNull);
      expect(widthOf(tester, cancel), 360);
      expect(widthOf(tester, 'Löschen'), 360);
    });

    testWidgets('two secondaries that overrun the row wrap above the primary', (
      tester,
    ) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          secondary: [
            secondaryBtn('Filter zurücksetzen'),
            secondaryBtn('Filter speichern'),
          ],
          primary: primaryBtn('Filter anwenden'),
        ),
        width: 400,
      );

      expect(tester.takeException(), isNull);
      expect(widthOf(tester, 'Filter anwenden'), 400);
      expect(
        tester.getCenter(btn('Filter anwenden')).dy,
        greaterThan(tester.getCenter(btn('Filter zurücksetzen')).dy),
      );
    });

    testWidgets('the wrapped primary sits one runGap below the secondaries', (
      tester,
    ) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          secondary: [secondaryBtn('Abbrechen und zurückkehren')],
          primary: primaryBtn('Datenbank endgültig löschen'),
        ),
        width: 360,
      );

      final secondary = rectOf(tester, 'Abbrechen und zurückkehren');
      final primary = rectOf(tester, 'Datenbank endgültig löschen');
      expect(primary.top - secondary.bottom, dsTokensLight.spacing.step3);
    });

    testWidgets('one pixel decides the wrap, and nothing overflows either way', (
      tester,
    ) async {
      // Find the exact width at which the labels stop fitting, then assert the
      // behaviour on both sides of it. This pins the boundary itself rather
      // than a comfortably-wide and a comfortably-narrow sample.
      Widget bar() => DesignSystemModalActionBar(
        secondary: [secondaryBtn('Cancel')],
        primary: primaryBtn('Delete everything'),
      );

      await pumpBar(tester, bar(), width: 1000);
      // The rendered primary is stretched, so ask the flow for the width at
      // which the groups still share a row rather than measuring the buttons.
      final needed = flowRenderBox(
        tester,
      ).getMaxIntrinsicWidth(double.infinity);

      await pumpBar(tester, bar(), width: needed);
      expect(tester.takeException(), isNull);
      expect(
        tester.getCenter(btn('Delete everything')).dy,
        tester.getCenter(btn('Cancel')).dy,
        reason: 'at exactly the required width the actions still share a row',
      );

      await pumpBar(tester, bar(), width: needed - 1);
      expect(tester.takeException(), isNull);
      expect(
        tester.getCenter(btn('Delete everything')).dy,
        greaterThan(tester.getCenter(btn('Cancel')).dy),
        reason: 'one pixel short, the groups must take separate rows',
      );
      expect(widthOf(tester, 'Delete everything'), needed - 1);
    });

    testWidgets('a primary too wide even alone is bounded, never negative', (
      tester,
    ) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          secondary: [secondaryBtn('A very long secondary action label')],
          primary: primaryBtn('A very long primary confirmation label'),
        ),
        width: 80,
      );

      expect(tester.takeException(), isNull);
      expect(widthOf(tester, 'A very long primary confirmation label'), 80);
      expect(widthOf(tester, 'A very long secondary action label'), 80);
    });
  });

  // ---------------------------------------------------------------------------
  // compactPrimary — the primary keeps its intrinsic width.
  // ---------------------------------------------------------------------------
  group('compactPrimary', () {
    testWidgets('keeps an intrinsic primary on the same footer row', (
      tester,
    ) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          layout: DesignSystemModalActionBarLayout.compactPrimary,
          secondary: [secondaryBtn('Clear'), secondaryBtn('Save')],
          primary: intrinsicPrimaryBtn('Apply'),
        ),
      );

      expect(
        tester.getCenter(btn('Apply')).dy,
        tester.getCenter(btn('Clear')).dy,
      );
      expect(
        tester.getCenter(btn('Apply')).dx,
        greaterThan(tester.getCenter(btn('Clear')).dx),
      );
      expect(
        widthOf(tester, 'Apply'),
        lessThan(200),
        reason: 'compact keeps the primary at its label width, not the row',
      );
    });

    testWidgets('spreads the groups to opposite edges when there is slack', (
      tester,
    ) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          layout: DesignSystemModalActionBarLayout.compactPrimary,
          secondary: [secondaryBtn('Clear')],
          primary: intrinsicPrimaryBtn('Apply'),
        ),
      );

      final bar = barRect(tester);
      expect(rectOf(tester, 'Clear').left, closeTo(bar.left, 0.1));
      expect(
        rectOf(tester, 'Apply').right,
        closeTo(bar.right, 0.1),
        reason:
            'the gutter is the minimum separation, not a fixed gap — spare '
            'width goes between the groups',
      );
    });

    testWidgets(
      'needs less width than the dominant layout to stay on one row',
      (
        tester,
      ) async {
        // The only difference between the two layouts' fit thresholds is the
        // gutter: step3 for compact, step5 for dominant.
        double singleRowWidth(DesignSystemModalActionBarLayout layout) {
          return tester
              .renderObject<RenderBox>(
                find.descendant(
                  of: find.byType(DesignSystemModalActionBar),
                  matching: find.byWidgetPredicate(
                    (widget) => widget.runtimeType.toString() == '_ActionFlow',
                  ),
                ),
              )
              .getMaxIntrinsicWidth(double.infinity);
        }

        Widget bar(DesignSystemModalActionBarLayout layout) =>
            DesignSystemModalActionBar(
              layout: layout,
              secondary: [secondaryBtn('Clear')],
              primary: intrinsicPrimaryBtn('Apply'),
            );

        await pumpBar(
          tester,
          bar(DesignSystemModalActionBarLayout.compactPrimary),
        );
        final compact = singleRowWidth(
          DesignSystemModalActionBarLayout.compactPrimary,
        );

        await pumpBar(
          tester,
          bar(DesignSystemModalActionBarLayout.dominantPrimary),
        );
        final dominant = singleRowWidth(
          DesignSystemModalActionBarLayout.dominantPrimary,
        );

        expect(
          dominant - compact,
          dsTokensLight.spacing.step5 - dsTokensLight.spacing.step3,
        );
      },
    );

    testWidgets('keeps short phone actions on one row when they fit', (
      tester,
    ) async {
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

      expect(
        tester.getCenter(btn('Start sync')).dy,
        tester.getCenter(btn('Cancel')).dy,
      );
      expect(widthOf(tester, 'Start sync'), lessThan(200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('wraps intrinsic actions to their own edges when labels do not '
        'fit', (tester) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          layout: DesignSystemModalActionBarLayout.compactPrimary,
          secondary: [
            secondaryBtn('Long clear action'),
            secondaryBtn('Long save action'),
          ],
          primary: intrinsicPrimaryBtn('Apply'),
        ),
        width: 320,
      );

      final bar = barRect(tester);
      expect(
        tester.getCenter(btn('Apply')).dy,
        greaterThan(tester.getCenter(btn('Long clear action')).dy),
      );
      expect(rectOf(tester, 'Long clear action').left, closeTo(bar.left, 0.1));
      expect(rectOf(tester, 'Long save action').left, closeTo(bar.left, 0.1));
      expect(
        rectOf(tester, 'Apply').right,
        closeTo(bar.right, 0.1),
        reason: 'wrapped compact keeps the primary on the trailing edge',
      );
      expect(
        widthOf(tester, 'Apply'),
        lessThan(320),
        reason: 'compact does not stretch the primary when it wraps',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('bounds an overlong action to the available width', (
      tester,
    ) async {
      const secondaryLabel =
          'A translated secondary action that cannot fit intrinsically';
      const primaryLabel =
          'A translated primary action that cannot fit intrinsically';
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          layout: DesignSystemModalActionBarLayout.compactPrimary,
          secondary: [secondaryBtn(secondaryLabel)],
          primary: DesignSystemButton(
            label: primaryLabel,
            fullWidth: true,
            onPressed: () {},
          ),
        ),
        width: 160,
      );

      expect(widthOf(tester, primaryLabel), 160);
      expect(widthOf(tester, secondaryLabel), 160);
      expect(tester.takeException(), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Directionality — leading/trailing edges must follow the text direction.
  // ---------------------------------------------------------------------------
  group('text direction', () {
    testWidgets('RTL mirrors the leading and trailing edges', (tester) async {
      await pumpBar(
        tester,
        Directionality(
          textDirection: TextDirection.rtl,
          child: DesignSystemModalActionBar(
            secondary: [secondaryBtn('Clear')],
            primary: primaryBtn('Apply'),
          ),
        ),
      );

      final bar = barRect(tester);
      expect(rectOf(tester, 'Clear').right, closeTo(bar.right, 0.1));
      expect(rectOf(tester, 'Apply').left, closeTo(bar.left, 0.1));
    });

    testWidgets('the flow relayouts when the direction flips', (tester) async {
      Widget bar(TextDirection direction) => Directionality(
        textDirection: direction,
        child: DesignSystemModalActionBar(
          layout: DesignSystemModalActionBarLayout.compactPrimary,
          secondary: [secondaryBtn('Clear')],
          primary: intrinsicPrimaryBtn('Apply'),
        ),
      );

      await pumpBar(tester, bar(TextDirection.ltr), width: 320);
      final renderBox = flowRenderBox(tester);
      expect(
        rectOf(tester, 'Apply').right,
        closeTo(barRect(tester).right, 0.1),
      );

      await pumpBar(tester, bar(TextDirection.rtl), width: 320);
      expect(
        flowRenderBox(tester),
        same(renderBox),
        reason: 'the same render object must be updated, not recreated',
      );
      expect(rectOf(tester, 'Apply').left, closeTo(barRect(tester).left, 0.1));
      expect(tester.takeException(), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Large text always stacks, regardless of layout or available width.
  // ---------------------------------------------------------------------------
  group('large text', () {
    testWidgets('dominant stacks at 200% even on a wide bar', (tester) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          secondary: [secondaryBtn('Cancel')],
          primary: primaryBtn('Done'),
        ),
        textScale: 2,
      );

      expect(
        tester.getCenter(btn('Done')).dy,
        greaterThan(tester.getCenter(btn('Cancel')).dy),
      );
      expect(widthOf(tester, 'Done'), 600);
    });

    testWidgets('compact stacks at 200% without clipping long actions', (
      tester,
    ) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          layout: DesignSystemModalActionBarLayout.compactPrimary,
          secondary: [
            secondaryBtn('Șterge filtrele'),
            secondaryBtn('Salvează filtrul'),
          ],
          primary: intrinsicPrimaryBtn('Aplică filtrele'),
        ),
        width: 320,
        textScale: 2,
      );

      expect(
        tester.getCenter(btn('Aplică filtrele')).dy,
        greaterThan(tester.getCenter(btn('Șterge filtrele')).dy),
      );
      expect(widthOf(tester, 'Aplică filtrele'), 320);
      expect(tester.takeException(), isNull);
    });

    testWidgets('just under the threshold still measures rather than stacks', (
      tester,
    ) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          secondary: [secondaryBtn('Cancel')],
          primary: primaryBtn('Done'),
        ),
        textScale: 1.3,
      );

      expect(
        tester.getCenter(btn('Done')).dy,
        tester.getCenter(btn('Cancel')).dy,
        reason: '1.3 is not "> 1.3", so the measured layout still applies',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Render-object contracts: dry layout and intrinsics must agree with what is
  // actually painted, so the bar composes inside IntrinsicWidth/IntrinsicHeight
  // and scrollable sheets.
  // ---------------------------------------------------------------------------
  group('render object contracts', () {
    testWidgets('dry layout matches the laid-out size when the groups wrap', (
      tester,
    ) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          secondary: [secondaryBtn('Abbrechen und zurückkehren')],
          primary: primaryBtn('Datenbank endgültig löschen'),
        ),
        width: 360,
      );

      final flow = flowRenderBox(tester);
      const constraints = BoxConstraints(maxWidth: 360);
      expect(flow.getDryLayout(constraints), flow.size);
      expect(flow.size.width, 360);
    });

    testWidgets('dry layout matches the laid-out size on a single row', (
      tester,
    ) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          secondary: [secondaryBtn('Cancel')],
          primary: primaryBtn('Done'),
        ),
      );

      final flow = flowRenderBox(tester);
      expect(flow.getDryLayout(const BoxConstraints(maxWidth: 600)), flow.size);
    });

    testWidgets('dry layout matches for a lone primary', (tester) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(primary: primaryBtn('Save')),
      );

      final flow = flowRenderBox(tester);
      expect(flow.getDryLayout(const BoxConstraints(maxWidth: 600)), flow.size);
    });

    testWidgets('max intrinsic width is the single-row width, min is the '
        'widest group', (tester) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          secondary: [secondaryBtn('Cancel')],
          primary: primaryBtn('Done'),
        ),
      );

      final flow = flowRenderBox(tester);
      final children = flowChildren(flow);
      final secondaryIntrinsic = children.first.getMaxIntrinsicWidth(
        double.infinity,
      );
      final primaryIntrinsic = children.last.getMaxIntrinsicWidth(
        double.infinity,
      );

      expect(
        flow.getMaxIntrinsicWidth(double.infinity),
        secondaryIntrinsic + dsTokensLight.spacing.step5 + primaryIntrinsic,
      );
      expect(
        flow.getMinIntrinsicWidth(double.infinity),
        children
            .map((child) => child.getMinIntrinsicWidth(double.infinity))
            .reduce((a, b) => a > b ? a : b),
      );
    });

    testWidgets('a lone primary reports its own intrinsic widths', (
      tester,
    ) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(primary: primaryBtn('Save')),
      );

      final flow = flowRenderBox(tester);
      final child = flowChildren(flow).single;
      expect(
        flow.getMaxIntrinsicWidth(double.infinity),
        child.getMaxIntrinsicWidth(double.infinity),
        reason: 'no secondary means no gutter is added',
      );
      expect(
        flow.getMinIntrinsicWidth(double.infinity),
        child.getMinIntrinsicWidth(double.infinity),
      );
    });

    testWidgets('intrinsic height covers both rows once the groups wrap', (
      tester,
    ) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          secondary: [secondaryBtn('Abbrechen und zurückkehren')],
          primary: primaryBtn('Datenbank endgültig löschen'),
        ),
        width: 360,
      );

      final flow = flowRenderBox(tester);
      final children = flowChildren(flow);
      expect(
        flow.getMaxIntrinsicHeight(360),
        children.first.getMaxIntrinsicHeight(360) +
            dsTokensLight.spacing.step3 +
            children.last.getMaxIntrinsicHeight(360),
      );
      expect(flow.getMaxIntrinsicHeight(360), flow.size.height);
    });

    testWidgets('intrinsic height is a single row height when the labels fit', (
      tester,
    ) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          secondary: [secondaryBtn('Cancel')],
          primary: primaryBtn('Done'),
        ),
      );

      final flow = flowRenderBox(tester);
      expect(flow.getMaxIntrinsicHeight(600), flow.size.height);
      expect(
        flow.getMinIntrinsicHeight(600),
        lessThanOrEqualTo(flow.size.height),
      );
    });

    testWidgets('a lone primary reports its own intrinsic height', (
      tester,
    ) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(primary: primaryBtn('Save')),
      );

      final flow = flowRenderBox(tester);
      final child = flowChildren(flow).single;
      expect(flow.getMaxIntrinsicHeight(600), child.getMaxIntrinsicHeight(600));
      expect(flow.getMinIntrinsicHeight(600), child.getMinIntrinsicHeight(600));
    });

    testWidgets('a lone primary too wide to fit reserves no empty row above '
        'itself', (tester) async {
      // There is no secondary group to wrap below, so a primary that cannot fit
      // is simply bounded — it must not be pushed down by a runGap, which would
      // leave dead space and desync intrinsic height from the rendered height.
      const label = 'Eine sehr lange übersetzte Bestätigungsbeschriftung';
      await pumpBar(
        tester,
        DesignSystemModalActionBar(primary: primaryBtn(label)),
        width: 120,
      );

      final flow = flowRenderBox(tester);
      final child = flowChildren(flow).single;

      expect(widthOf(tester, label), 120);
      expect(
        rectOf(tester, label).top,
        closeTo(barRect(tester).top, 0.1),
        reason: 'the primary starts at the top of the bar, not one gap down',
      );
      expect(flow.size.height, child.size.height);
      expect(flow.getMaxIntrinsicHeight(120), flow.size.height);
      expect(flow.getDryLayout(const BoxConstraints(maxWidth: 120)), flow.size);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unbounded width falls back to the single-row width', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Row(
            children: [
              // No Expanded: the bar is offered unbounded width.
              DesignSystemModalActionBar(
                secondary: [secondaryBtn('Cancel')],
                primary: primaryBtn('Done'),
              ),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final flow = flowRenderBox(tester);
      expect(
        flow.size.width,
        flow.getMaxIntrinsicWidth(double.infinity),
        reason: 'with no width to fill, the bar sizes to its actions',
      );
      expect(
        tester.getCenter(btn('Done')).dy,
        tester.getCenter(btn('Cancel')).dy,
      );
    });

    testWidgets('token changes relayout the same render object', (
      tester,
    ) async {
      Widget themedBar(double gap) {
        final tokens = dsTokensLight.copyWith(
          spacing: dsTokensLight.spacing.copyWith(step3: gap),
        );
        return Theme(
          data: resolveTestTheme().copyWith(
            extensions: <ThemeExtension<dynamic>>[tokens],
          ),
          child: DesignSystemModalActionBar(
            secondary: [
              secondaryBtn('A translated secondary that wraps to its own row'),
            ],
            primary: primaryBtn(
              'A translated primary that wraps to its own row',
            ),
          ),
        );
      }

      await pumpBar(tester, themedBar(8), width: 160);
      final flow = flowRenderBox(tester);
      final children = flowChildren(flow);
      expect(children, hasLength(2));

      Rect childRect(RenderBox child) =>
          child.localToGlobal(Offset.zero) & child.size;

      expect(
        childRect(children.last).top - childRect(children.first).bottom,
        8,
      );

      await pumpBar(tester, themedBar(16), width: 160);
      expect(
        flowRenderBox(tester),
        same(flow),
        reason: 'a token change must update the render object, not replace it',
      );
      final updated = flowChildren(flow);
      expect(
        childRect(updated.last).top - childRect(updated.first).bottom,
        16,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('switching layout mode updates the existing render object', (
      tester,
    ) async {
      Widget bar(DesignSystemModalActionBarLayout layout) =>
          DesignSystemModalActionBar(
            layout: layout,
            secondary: [secondaryBtn('Clear')],
            primary: intrinsicPrimaryBtn('Apply'),
          );

      await pumpBar(
        tester,
        bar(DesignSystemModalActionBarLayout.compactPrimary),
      );
      final flow = flowRenderBox(tester);
      final compactWidth = widthOf(tester, 'Apply');

      await pumpBar(
        tester,
        bar(DesignSystemModalActionBarLayout.dominantPrimary),
      );
      expect(flowRenderBox(tester), same(flow));
      expect(
        widthOf(tester, 'Apply'),
        greaterThan(compactWidth),
        reason: 'the primary starts filling the leftover width',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('adding a secondary updates the existing render object', (
      tester,
    ) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(primary: primaryBtn('Done')),
      );
      final flow = flowRenderBox(tester);
      expect(flowChildren(flow), hasLength(1));
      expect(widthOf(tester, 'Done'), 600);

      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          secondary: [secondaryBtn('Cancel')],
          primary: primaryBtn('Done'),
        ),
      );
      expect(flowChildren(flowRenderBox(tester)), hasLength(2));
      expect(
        widthOf(tester, 'Done'),
        lessThan(600),
        reason: 'the primary yields the secondary its width plus the gutter',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Interaction and surrounding chrome.
  // ---------------------------------------------------------------------------
  group('interaction and chrome', () {
    testWidgets('both actions stay tappable once the groups wrap', (
      tester,
    ) async {
      var cancelled = 0;
      var confirmed = 0;
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          secondary: [
            DesignSystemButton(
              label: 'Abbrechen und zurückkehren',
              variant: DesignSystemButtonVariant.secondary,
              size: DesignSystemButtonSize.large,
              onPressed: () => cancelled++,
            ),
          ],
          primary: DesignSystemButton(
            label: 'Datenbank endgültig löschen',
            size: DesignSystemButtonSize.large,
            fullWidth: true,
            onPressed: () => confirmed++,
          ),
        ),
        width: 360,
      );

      await tester.tap(btn('Datenbank endgültig löschen'));
      await tester.tap(btn('Abbrechen und zurückkehren'));
      await tester.pump();

      expect(confirmed, 1, reason: 'the wrapped primary must still hit-test');
      expect(cancelled, 1);
    });

    testWidgets('padding insets the actions from the bar edges', (
      tester,
    ) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(
          padding: const EdgeInsets.all(20),
          primary: primaryBtn('Save'),
        ),
      );

      expect(widthOf(tester, 'Save'), 560);
      expect(rectOf(tester, 'Save').left - barRect(tester).left, 20);
    });

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

      expect(find.byType(DesignSystemGlassStrip), findsOneWidget);
      expect(btn('Done'), findsOneWidget);
    });

    testWidgets('glass defaults to off (no DesignSystemGlassStrip)', (
      tester,
    ) async {
      await pumpBar(
        tester,
        DesignSystemModalActionBar(primary: primaryBtn('Save')),
      );

      expect(find.byType(DesignSystemGlassStrip), findsNothing);
    });
  });
}
