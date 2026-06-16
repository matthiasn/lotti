import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';

import '../../../widget_test_utils.dart';

/// Captures the surface colors and the expected token values for a single
/// build so a test can assert the elevation relationship in either brightness.
class _Captured {
  _Captured({
    required this.page,
    required this.card,
    required this.level01,
    required this.level02,
  });

  final Color page;
  final Color card;
  final Color level01;
  final Color level02;
}

/// Pumps a [Builder] under the given [theme] and returns the colors resolved
/// by [dsPageSurface]/[dsCardSurface] alongside the background ramp tokens.
Future<_Captured> _capture(WidgetTester tester, ThemeData theme) async {
  late _Captured captured;

  // Clear any prior tree first so switching brightness inside a single test
  // does not capture a value mid theme-lerp animation.
  await tester.pumpWidget(const SizedBox.shrink());

  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      Builder(
        builder: (context) {
          final background = context.designTokens.colors.background;
          captured = _Captured(
            page: dsPageSurface(context),
            card: dsCardSurface(context),
            level01: background.level01,
            level02: background.level02,
          );
          return const SizedBox.shrink();
        },
      ),
      theme: theme,
    ),
  );

  return captured;
}

void main() {
  group('ds_surface_elevation', () {
    testWidgets('dark theme: page is level01, card is level02 (lighter)', (
      tester,
    ) async {
      final captured = await _capture(tester, DesignSystemTheme.dark());

      // Dark theme reads the ramp ascending: the base canvas is level01 and
      // cards sit a step lighter on level02.
      expect(captured.page, captured.level01);
      expect(captured.card, captured.level02);
      // The two surfaces must differ so cards read as elevated above the page.
      expect(captured.page, isNot(captured.card));
    });

    testWidgets('light theme: page is level02, card is level01 (lighter)', (
      tester,
    ) async {
      final captured = await _capture(tester, DesignSystemTheme.light());

      // Light theme inverts the ramp: level02 is *darker* than the white
      // level01, so the page uses the darker level02 and cards use level01 to
      // stay lighter than the page.
      expect(captured.page, captured.level02);
      expect(captured.card, captured.level01);
      expect(captured.page, isNot(captured.card));
    });

    testWidgets('elevation inverts which token is page/card across brightness', (
      tester,
    ) async {
      final dark = await _capture(tester, DesignSystemTheme.dark());
      final light = await _capture(tester, DesignSystemTheme.light());

      // The page token in dark mode is the card token in light mode and vice
      // versa — the inversion that keeps "cards lighter than the page" true in
      // both themes despite the opposite-direction background ramp.
      expect(dark.page, isNot(light.page));
      expect(dark.card, isNot(light.card));
      expect(dark.page, dark.level01);
      expect(light.card, light.level01);
    });
  });
}
