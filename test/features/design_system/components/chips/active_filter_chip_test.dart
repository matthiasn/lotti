import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/chips/active_filter_chip.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('ActiveFilterChip', () {
    Future<void> pump(WidgetTester tester, Widget child) {
      return tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Theme(
            data: DesignSystemTheme.dark(),
            child: Scaffold(body: Center(child: child)),
          ),
        ),
      );
    }

    testWidgets('calls onRemove when tapped', (tester) async {
      var removed = 0;
      await pump(
        tester,
        ActiveFilterChip(
          label: 'OPEN',
          accentColor: const Color(0xFFFF0000),
          onRemove: () => removed++,
        ),
      );

      await tester.tap(find.byType(ActiveFilterChip));
      await tester.pump();
      expect(removed, 1);
    });

    testWidgets(
      'always renders the trailing filled-circle ✕ so the remove '
      'affordance is unambiguous',
      (tester) async {
        await pump(
          tester,
          ActiveFilterChip(
            label: 'Focus',
            accentColor: const Color(0xFFFFAA00),
            onRemove: () {},
          ),
        );

        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.byType(ActiveFilterChip),
            matching: find.byIcon(Icons.cancel_rounded),
          ),
        );
        expect(icon.size, 14);
      },
    );

    testWidgets('uses the accent colour as the border stroke', (tester) async {
      const accent = Color(0xFF00FF88);
      await pump(
        tester,
        ActiveFilterChip(
          label: 'Work',
          accentColor: accent,
          onRemove: () {},
        ),
      );

      // The outer Material of the chip carries the border side in its shape.
      final material = tester
          .widgetList<Material>(
            find.descendant(
              of: find.byType(ActiveFilterChip),
              matching: find.byType(Material),
            ),
          )
          .first;
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side.color, accent);
      expect(
        shape.borderRadius,
        BorderRadius.circular(dsTokensLight.radii.badgesPills),
      );
    });

    testWidgets('renders the leading icon in the accent colour', (
      tester,
    ) async {
      const accent = Color(0xFFAA00FF);
      await pump(
        tester,
        ActiveFilterChip(
          label: 'In progress',
          accentColor: accent,
          leadingIcon: Icons.play_arrow_rounded,
          onRemove: () {},
        ),
      );

      final leading = tester.widget<Icon>(
        find.descendant(
          of: find.byType(ActiveFilterChip),
          matching: find.byIcon(Icons.play_arrow_rounded),
        ),
      );
      expect(leading.color, accent);
      expect(leading.size, 14);
    });

    testWidgets('uses the avatar slot when provided instead of leadingIcon', (
      tester,
    ) async {
      const avatar = SizedBox.square(
        dimension: 14,
        key: ValueKey('priority-avatar'),
        child: ColoredBox(color: Color(0xFFFF0000)),
      );

      await pump(
        tester,
        ActiveFilterChip(
          label: 'P0',
          accentColor: const Color(0xFFFF0000),
          avatar: avatar,
          onRemove: () {},
        ),
      );

      expect(find.byKey(const ValueKey('priority-avatar')), findsOneWidget);
      // No Icon other than the trailing cancel glyph.
      expect(
        find.descendant(
          of: find.byType(ActiveFilterChip),
          matching: find.byType(Icon),
        ),
        findsOneWidget, // only the ✕
      );
    });

    test('asserts when both leadingIcon and avatar are supplied', () {
      expect(
        () => ActiveFilterChip(
          label: 'Both',
          accentColor: const Color(0xFF000000),
          leadingIcon: Icons.abc,
          avatar: const SizedBox.shrink(),
          onRemove: () {},
        ),
        throwsAssertionError,
      );
    });
  });
}
