import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/state/backfill_stats_controller.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/ui/backfill_settings_recovery.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../widget_test_utils.dart';

// The recovery actions each lead with a small filled chip behind a glyph. Both
// the chip (a raw 28) and the glyph inside it (a raw 15) were literals, and
// the danger variant tinted the error colour by a hand-picked 0.14 rather than
// reusing the theme's own error wash.

void main() {
  const stats = BackfillStatsState(
    stats: BackfillStats(
      hostStats: [],
      totalReceived: 120,
      totalMissing: 4,
      totalRequested: 7,
      totalBackfilled: 96,
      totalDeleted: 3,
      totalUnresolvable: 2,
      totalBurned: 1,
    ),
  );

  Future<DsTokens> pumpExpanded(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const SingleChildScrollView(
          child: AdvancedRecoveryGroup(
            stats: stats,
            skipped: 3,
            coordinator: null,
          ),
        ),
      ),
    );
    await tester.pump();

    final context = tester.element(find.byType(AdvancedRecoveryGroup));
    await tester.tap(find.text(context.messages.backfillAdvancedRecoveryTitle));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    return context.designTokens;
  }

  /// The square chips behind each action's leading glyph.
  List<Container> chipsOf(WidgetTester tester) => tester
      .widgetList<Container>(
        find.descendant(
          of: find.byType(AdvancedRecoveryGroup),
          matching: find.byType(Container),
        ),
      )
      .where(
        (c) =>
            c.constraints?.maxWidth == ControlSizes.iconChipCompact &&
            c.constraints?.maxHeight == ControlSizes.iconChipCompact,
      )
      .toList();

  group('AdvancedRecoveryGroup', () {
    testWidgets('stays collapsed until its header is tapped', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SingleChildScrollView(
            child: AdvancedRecoveryGroup(
              stats: stats,
              skipped: 3,
              coordinator: null,
            ),
          ),
        ),
      );
      await tester.pump();

      // Nothing but the header before the tap — the destructive actions must
      // not be one stray press away.
      expect(chipsOf(tester), isEmpty);
    });

    testWidgets('reveals its actions once expanded', (tester) async {
      await pumpExpanded(tester);

      expect(chipsOf(tester), isNotEmpty);
    });
  });

  group('the leading action chip', () {
    testWidgets('is sized from the compact control tier', (tester) async {
      await pumpExpanded(tester);

      final chips = chipsOf(tester);
      expect(chips, isNotEmpty);

      // Every chip is the same square; a row whose chip drifted would break
      // the column of glyphs running down the left edge.
      for (final chip in chips) {
        expect(chip.constraints!.maxWidth, ControlSizes.iconChipCompact);
        expect(chip.constraints!.maxHeight, ControlSizes.iconChipCompact);
      }
    });

    testWidgets('holds a meta-tier glyph that fits inside it', (tester) async {
      await pumpExpanded(tester);

      final glyphs = chipsOf(
        tester,
      ).map((c) => c.child).whereType<Icon>().toList();

      expect(glyphs, hasLength(chipsOf(tester).length));
      for (final glyph in glyphs) {
        expect(glyph.size, IconSizes.s);
        // A 15 was not on the icon ramp at all, and left an odd inset that
        // landed the glyph on a half pixel.
        expect(glyph.size, lessThan(ControlSizes.iconChipCompact));
      }
    });

    testWidgets('tints the danger action with the theme error wash', (
      tester,
    ) async {
      await pumpExpanded(tester);

      final element = tester.element(find.byType(AdvancedRecoveryGroup));
      final scheme = Theme.of(element).colorScheme;
      final tokens = element.designTokens;

      final fills = chipsOf(
        tester,
      ).map((c) => (c.decoration! as BoxDecoration).color).toSet();

      // One destructive action among several neutral ones, so both the wash
      // and the plain surface must be present — and they must differ.
      expect(fills, contains(scheme.errorContainer));
      expect(fills, contains(tokens.colors.surface.enabled));
      expect(scheme.errorContainer, isNot(tokens.colors.surface.enabled));
    });
  });

  group('the collapsible header', () {
    // Both assertions pin values a revert would reproduce (subtitle2 already
    // carries semiBold; IconSizes.m equals the 18 it replaced), so they hold
    // the contract going forward rather than catching the old literals.
    testWidgets('takes its title weight from subtitle2 itself', (tester) async {
      final tokens = await pumpExpanded(tester);
      final context = tester.element(find.byType(AdvancedRecoveryGroup));

      final title = tester.widget<Text>(
        find.text(context.messages.backfillAdvancedRecoveryTitle),
      );
      expect(title.style!.fontWeight, tokens.typography.weight.semiBold);
      expect(
        title.style!.fontWeight,
        tokens.typography.styles.subtitle.subtitle2.fontWeight,
        reason: 'the weight must come from the style, not a layered override',
      );
    });

    testWidgets('sizes its chevron on the control-glyph tier', (tester) async {
      await pumpExpanded(tester);

      final chevron = tester.widget<Icon>(find.byIcon(Icons.chevron_right));
      expect(chevron.size, IconSizes.m);
    });
  });

  group('the expanded action list', () {
    testWidgets('separates actions with design-system dividers', (
      tester,
    ) async {
      await pumpExpanded(tester);

      final dividers = find.descendant(
        of: find.byType(AdvancedRecoveryGroup),
        matching: find.byType(DesignSystemDivider),
      );
      // One rule under the header plus one between each adjacent pair:
      // as many dividers as actions. skipped = 3 adds the retry action
      // to the base seven. A revert to hand-rolled 1px Containers fails
      // here — the component, not its rendering, is the contract.
      expect(dividers, findsNWidgets(8));
    });

    testWidgets('draws no divider while collapsed', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SingleChildScrollView(
            child: AdvancedRecoveryGroup(
              stats: stats,
              skipped: 3,
              coordinator: null,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(DesignSystemDivider), findsNothing);
    });

    testWidgets('keeps every CTA at the card-internal default size', (
      tester,
    ) async {
      await pumpExpanded(tester);

      // component-contracts.md: card-internal actions belong at dense or the
      // default small — medium out-weighs the row titles beside it. Reverting
      // to an explicit `size: medium` fails this.
      final buttons = tester
          .widgetList<DesignSystemButton>(find.byType(DesignSystemButton))
          .toList();
      expect(buttons, hasLength(8));
      for (final button in buttons) {
        expect(button.size, DesignSystemButtonSize.small);
      }
    });
  });
}
