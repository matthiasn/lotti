import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/branding/design_system_brand_logo.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemBrandLogo', () {
    testWidgets('uses the light asset in light theme', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemBrandLogo(),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(
        find.byKey(const ValueKey('designSystemBrandLogo.light')),
        findsOneWidget,
      );
    });

    testWidgets('uses the dark asset in dark theme', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemBrandLogo(),
          theme: DesignSystemTheme.dark(),
        ),
      );

      expect(
        find.byKey(const ValueKey('designSystemBrandLogo.dark')),
        findsOneWidget,
      );
    });

    testWidgets('honors an explicit variant override', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DesignSystemBrandLogo(
            variant: DesignSystemBrandLogoVariant.dark,
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(
        find.byKey(const ValueKey('designSystemBrandLogo.dark')),
        findsOneWidget,
      );
    });
  });
}
