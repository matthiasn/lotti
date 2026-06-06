import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('stripTrailingColon', () {
    test('strips a trailing colon and the whitespace before it', () {
      expect(stripTrailingColon('Status:'), 'Status');
      expect(stripTrailingColon('Statut :'), 'Statut');
      expect(stripTrailingColon('Label\t:'), 'Label');
    });

    test('leaves strings without a trailing colon unchanged', () {
      expect(stripTrailingColon('Status'), 'Status');
      expect(stripTrailingColon(''), '');
      expect(stripTrailingColon(':middle: colon'), ':middle: colon');
    });

    glados.Glados<String>(
      glados.any.letterOrDigits,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'is idempotent and never reintroduces a trailing colon',
      (value) {
        for (final candidate in [value, '$value:', '$value :']) {
          final once = stripTrailingColon(candidate);
          expect(stripTrailingColon(once), once, reason: '"$candidate"');
          expect(once.endsWith(':'), isFalse, reason: '"$candidate"');
        }
        // Strings that don't end in ':' pass through verbatim.
        expect(stripTrailingColon(value), value);
      },
      tags: 'glados',
    );
  });

  group('DesignSystemFilterPalette.fromTokens', () {
    test('dark tokens produce the dark surfaces and accent', () {
      final palette = DesignSystemFilterPalette.fromTokens(dsTokensDark);

      expect(palette.sheetBackground, const Color(0xFF1C1C1C));
      expect(palette.accent, const Color(0xFF5AD5BE));
      expect(palette.primaryText, dsTokensDark.colors.text.highEmphasis);
      expect(palette.secondaryText, dsTokensDark.colors.text.mediumEmphasis);
      // Glass overlay derives from the level02 surface, bottom stop denser.
      expect(
        palette.glassFooterOverlayStart.a,
        lessThan(palette.glassFooterOverlayEnd.a),
      );
    });

    test('light tokens produce the light surfaces and accent', () {
      final palette = DesignSystemFilterPalette.fromTokens(dsTokensLight);

      expect(palette.sheetBackground, const Color(0xFFFFFCF8));
      expect(palette.accent, const Color(0xFF2CA990));
      expect(palette.primaryText, dsTokensLight.colors.text.highEmphasis);
      expect(
        palette.glassFooterOverlayStart.a,
        lessThan(palette.glassFooterOverlayEnd.a),
      );
    });
  });

  group('DesignSystemFilterActionButton', () {
    final palette = DesignSystemFilterPalette.fromTokens(dsTokensDark);

    Future<void> pumpButton(
      WidgetTester tester, {
      required bool highlighted,
      int? counter,
      VoidCallback? onTap,
    }) {
      return tester.pumpWidget(
        makeTestableWidget2(
          Theme(
            data: DesignSystemTheme.dark(),
            child: Scaffold(
              body: Center(
                child: DesignSystemFilterActionButton(
                  label: 'Apply filter',
                  palette: palette,
                  highlighted: highlighted,
                  textStyle: const TextStyle(fontSize: 16),
                  onTap: onTap ?? () {},
                  counter: counter,
                ),
              ),
            ),
          ),
        ),
      );
    }

    BoxDecoration inkDecoration(WidgetTester tester) {
      final ink = tester.widget<Ink>(
        find.descendant(
          of: find.byType(DesignSystemFilterActionButton),
          matching: find.byType(Ink),
        ),
      );
      return ink.decoration! as BoxDecoration;
    }

    testWidgets('highlighted pill paints accent fill with no border', (
      tester,
    ) async {
      await pumpButton(tester, highlighted: true);

      final decoration = inkDecoration(tester);
      expect(decoration.color, palette.accent);
      expect(decoration.border, isNull);

      final label = tester.widget<Text>(find.text('Apply filter'));
      expect(label.style?.color, palette.accentText);
    });

    testWidgets('non-highlighted pill paints pill fill with divider border', (
      tester,
    ) async {
      await pumpButton(tester, highlighted: false);

      final decoration = inkDecoration(tester);
      expect(decoration.color, palette.pillFill);
      expect(decoration.border!.top.color, palette.dividerColor);

      final label = tester.widget<Text>(find.text('Apply filter'));
      expect(label.style?.color, palette.primaryText);
    });

    testWidgets('renders the counter badge only when a counter is given', (
      tester,
    ) async {
      await pumpButton(tester, highlighted: true, counter: 3);

      final badgeText = find.text('3');
      expect(badgeText, findsOneWidget);
      final badge = tester.widget<Container>(
        find.ancestor(of: badgeText, matching: find.byType(Container)).first,
      );
      final decoration = badge.decoration! as BoxDecoration;
      expect(decoration.color, palette.applyBadgeFill);
      expect(decoration.shape, BoxShape.circle);

      await pumpButton(tester, highlighted: true);
      expect(find.text('3'), findsNothing);
    });

    testWidgets('meets the 56px action slot minimum and invokes onTap', (
      tester,
    ) async {
      var taps = 0;
      await pumpButton(tester, highlighted: true, onTap: () => taps++);

      expect(
        tester.getSize(find.byType(DesignSystemFilterActionButton)).height,
        DesignSystemFilterMetrics.actionMinHeight,
      );

      await tester.tap(find.byType(DesignSystemFilterActionButton));
      expect(taps, 1);
    });
  });

  group('DesignSystemFilterChoicePill', () {
    final palette = DesignSystemFilterPalette.fromTokens(dsTokensDark);

    Future<void> pumpPill(
      WidgetTester tester, {
      required bool selected,
      VoidCallback? onTap,
      Widget? leading,
    }) {
      return tester.pumpWidget(
        makeTestableWidget2(
          Theme(
            data: DesignSystemTheme.dark(),
            child: Scaffold(
              body: Center(
                child: DesignSystemFilterChoicePill(
                  label: 'Priority',
                  selected: selected,
                  palette: palette,
                  textStyle: const TextStyle(fontSize: 14),
                  onTap: onTap ?? () {},
                  leading: leading,
                ),
              ),
            ),
          ),
        ),
      );
    }

    BoxDecoration pillDecoration(WidgetTester tester) {
      final ink = tester.widget<Ink>(
        find.descendant(
          of: find.byType(DesignSystemFilterChoicePill),
          matching: find.byType(Ink),
        ),
      );
      return ink.decoration! as BoxDecoration;
    }

    testWidgets('unselected pill paints the base fill with no accent border', (
      tester,
    ) async {
      await pumpPill(tester, selected: false);

      final decoration = pillDecoration(tester);
      expect(decoration.color, palette.pillFill);
      // Border alpha animates with selection progress; at rest it is 0.
      expect(decoration.border!.top.color.a, 0);
    });

    testWidgets('selecting cross-fades to the selected fill and border', (
      tester,
    ) async {
      await pumpPill(tester, selected: false);
      await pumpPill(tester, selected: true);
      // Drive the 400ms selection animation to completion.
      await tester.pump(DesignSystemFilterChoicePill.animationDuration);

      final decoration = pillDecoration(tester);
      expect(decoration.color, palette.selectedPillBackground);
      expect(decoration.border!.top.color.a, closeTo(1, 0.01));
    });

    testWidgets('renders the leading widget and forwards taps', (
      tester,
    ) async {
      var taps = 0;
      await pumpPill(
        tester,
        selected: false,
        onTap: () => taps++,
        leading: const Icon(Icons.sort, size: 16),
      );

      expect(find.byIcon(Icons.sort), findsOneWidget);
      await tester.tap(find.byType(DesignSystemFilterChoicePill));
      expect(taps, 1);
    });
  });
}
