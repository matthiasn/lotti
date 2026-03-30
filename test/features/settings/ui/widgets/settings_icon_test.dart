import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('SettingsIcon', () {
    testWidgets('renders icon with correct size and color', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SettingsIcon(icon: Icons.settings),
          theme: DesignSystemTheme.light(),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.settings));
      expect(icon.size, 20.0);
      expect(icon.color, dsTokensLight.colors.interactive.enabled);
    });

    testWidgets('renders container with correct size', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SettingsIcon(icon: Icons.settings),
          theme: DesignSystemTheme.light(),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final constraints = container.constraints;
      expect(constraints?.maxWidth, SettingsIcon.containerSize);
      expect(constraints?.maxHeight, SettingsIcon.containerSize);
    });

    testWidgets('uses interactive color with reduced opacity for background', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SettingsIcon(icon: Icons.settings),
          theme: DesignSystemTheme.light(),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;
      expect(
        decoration.color,
        dsTokensLight.colors.interactive.enabled.withValues(alpha: 0.12),
      );
    });
  });
}
