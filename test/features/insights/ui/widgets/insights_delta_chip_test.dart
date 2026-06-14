import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/insights/ui/widgets/insights_delta_chip.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('insightsDeltaPercent', () {
    test('rounds the percent change', () {
      expect(insightsDeltaPercent(120, 100), 20);
      expect(insightsDeltaPercent(80, 100), -20);
      expect(insightsDeltaPercent(100, 100), 0);
      expect(insightsDeltaPercent(118, 100), 18);
    });

    test('is null when there is no previous baseline', () {
      expect(insightsDeltaPercent(60, 0), isNull);
      expect(insightsDeltaPercent(0, 0), isNull);
    });
  });

  group('InsightsDeltaChip', () {
    Future<void> pump(
      WidgetTester tester, {
      required int current,
      required int previous,
      ThemeData? theme,
    }) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          InsightsDeltaChip(current: current, previous: previous),
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
      expect(find.byIcon(Icons.arrow_upward_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
    });

    testWidgets('a >=1% swing keeps the directional arrow', (tester) async {
      // +1.2% (1012 vs 1000) clears the dead-band → full directional treatment.
      await pump(tester, current: 1012, previous: 1000);
      expect(find.text('+1%'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
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
        find.byIcon(Icons.arrow_upward_rounded),
      );
      expect(lightIcon.color, dsTokensLight.colors.alert.success.pressed);

      await pump(
        tester,
        current: 118,
        previous: 100,
        theme: ThemeData.dark(useMaterial3: true),
      );
      final darkIcon = tester.widget<Icon>(
        find.byIcon(Icons.arrow_upward_rounded),
      );
      expect(darkIcon.color, dsTokensDark.colors.alert.success.hover);
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
        find.byIcon(Icons.arrow_downward_rounded),
      );
      expect(lightIcon.color, dsTokensLight.colors.alert.error.pressed);

      await pump(
        tester,
        current: 88,
        previous: 100,
        theme: ThemeData.dark(useMaterial3: true),
      );
      final darkIcon = tester.widget<Icon>(
        find.byIcon(Icons.arrow_downward_rounded),
      );
      expect(darkIcon.color, dsTokensDark.colors.alert.error.hover);
    });
  });
}
