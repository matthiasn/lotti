import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/insights/ui/widgets/insights_delta_chip.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('InsightsDeltaChip', () {
    Future<void> pump(
      WidgetTester tester, {
      required int current,
      required int previous,
      ThemeData? theme,
      InsightsTrendValence valence = InsightsTrendValence.moreIsBetter,
    }) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          InsightsDeltaChip(
            current: current,
            previous: previous,
            valence: valence,
          ),
          theme: theme,
        ),
      );
      // MaterialApp's AnimatedTheme tweens a light↔dark switch over
      // kThemeAnimationDuration (~200ms); settle it so the asserted accent
      // reflects the target theme, not an interpolated mid-transition value.
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('shows a signed-up percent for growth', (tester) async {
      await pump(tester, current: 118, previous: 100);
      expect(find.text('+18%'), findsOneWidget);
    });

    testWidgets('shows a signed-down percent for a decline', (tester) async {
      await pump(tester, current: 88, previous: 100);
      expect(find.text('-12%'), findsOneWidget);
    });

    testWidgets('ellipsizes an extreme delta inside a narrow constraint', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox(
            width: 60,
            child: InsightsDeltaChip(current: 1230000, previous: 1),
          ),
        ),
      );
      await tester.pump();

      final label = tester.widget<Text>(find.text('+122999900%'));
      expect(label.overflow, TextOverflow.ellipsis);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('+122999900%'),
      );
      expect(paragraph.didExceedMaxLines, isTrue);
      expect(paragraph.size.width, lessThan(60));
    });

    testWidgets('shows "new" when there is no previous time', (tester) async {
      await pump(tester, current: 60, previous: 0);
      expect(find.text('new'), findsOneWidget);
    });

    testWidgets('renders nothing when both periods are empty', (tester) async {
      await pump(tester, current: 0, previous: 0);
      expect(find.textContaining('%'), findsNothing);
      expect(find.text('new'), findsNothing);
    });

    testWidgets('a sub-1% swing stays neutral — no arrow, no accent', (
      tester,
    ) async {
      // +0.9% (1009 vs 1000) rounds to +1% but is rounding noise on a small
      // base: it shows the figure without the confident arrow + colour that a
      // real swing earns.
      await pump(tester, current: 1009, previous: 1000);
      expect(find.text('+1%'), findsOneWidget);
      expect(find.byIcon(LottiIcons.arrowUp), findsNothing);
      expect(find.byIcon(LottiIcons.arrowDown), findsNothing);
    });

    testWidgets('a >=1% swing keeps the directional arrow', (tester) async {
      // +1.2% (1012 vs 1000) clears the dead-band → full directional treatment.
      await pump(tester, current: 1012, previous: 1000);
      expect(find.text('+1%'), findsOneWidget);
      expect(find.byIcon(LottiIcons.arrowUp), findsOneWidget);
    });

    // The accent must clear WCAG AA 4.5:1 on the card in both themes; the green
    // `hover` step fails on the light card, so light uses the darker `pressed`
    // step and dark uses the more saturated `hover` step. Asserting the actual
    // rendered colour guards that contrast choice against regression.
    testWidgets('growth accent uses the AA-safe green per theme', (
      tester,
    ) async {
      await pump(
        tester,
        current: 118,
        previous: 100,
        theme: ThemeData.light(useMaterial3: true),
      );
      final lightIcon = tester.widget<Icon>(
        find.byIcon(LottiIcons.arrowUp),
      );
      expect(lightIcon.color, dsTokensLight.colors.alert.success.ink);

      await pump(
        tester,
        current: 118,
        previous: 100,
        theme: ThemeData.dark(useMaterial3: true),
      );
      final darkIcon = tester.widget<Icon>(
        find.byIcon(LottiIcons.arrowUp),
      );
      expect(darkIcon.color, dsTokensDark.colors.alert.success.ink);
    });

    testWidgets('decline accent uses the AA-safe red per theme', (
      tester,
    ) async {
      await pump(
        tester,
        current: 88,
        previous: 100,
        theme: ThemeData.light(useMaterial3: true),
      );
      final lightIcon = tester.widget<Icon>(
        find.byIcon(LottiIcons.arrowDown),
      );
      expect(lightIcon.color, dsTokensLight.colors.alert.error.ink);

      await pump(
        tester,
        current: 88,
        previous: 100,
        theme: ThemeData.dark(useMaterial3: true),
      );
      final darkIcon = tester.widget<Icon>(
        find.byIcon(LottiIcons.arrowDown),
      );
      expect(darkIcon.color, dsTokensDark.colors.alert.error.ink);
    });

    // Valence flips the accent while keeping the arrow + sign truthful: for a
    // cost/energy/carbon metric (lessIsBetter) a rise is bad, so an up arrow
    // reads clay (error), not green.
    testWidgets('lessIsBetter paints a rise clay and a fall green', (
      tester,
    ) async {
      await pump(
        tester,
        current: 118,
        previous: 100,
        valence: InsightsTrendValence.lessIsBetter,
        theme: ThemeData.light(useMaterial3: true),
      );
      expect(find.text('+18%'), findsOneWidget); // direction still up
      final upIcon = tester.widget<Icon>(
        find.byIcon(LottiIcons.arrowUp),
      );
      expect(upIcon.color, dsTokensLight.colors.alert.error.ink);

      await pump(
        tester,
        current: 88,
        previous: 100,
        valence: InsightsTrendValence.lessIsBetter,
        theme: ThemeData.light(useMaterial3: true),
      );
      final downIcon = tester.widget<Icon>(
        find.byIcon(LottiIcons.arrowDown),
      );
      expect(downIcon.color, dsTokensLight.colors.alert.success.ink);
    });

    testWidgets('neutral valence keeps the arrow but drops the accent', (
      tester,
    ) async {
      await pump(
        tester,
        current: 118,
        previous: 100,
        valence: InsightsTrendValence.neutral,
        theme: ThemeData.light(useMaterial3: true),
      );
      expect(find.text('+18%'), findsOneWidget);
      final icon = tester.widget<Icon>(
        find.byIcon(LottiIcons.arrowUp),
      );
      // The medium-emphasis neutral text colour — neither green nor clay.
      expect(icon.color, dsTokensLight.colors.text.mediumEmphasis);
      expect(icon.color, isNot(dsTokensLight.colors.alert.success.ink));
      expect(icon.color, isNot(dsTokensLight.colors.alert.error.ink));
    });
  });
}
