import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/empty_states/design_system_empty_state.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_detail_empty_state.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(
      makeTestableWidget2(
        Theme(
          data: DesignSystemTheme.dark(),
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  group('DesktopDetailEmptyState', () {
    testWidgets('renders message and default icon with token colours', (
      tester,
    ) async {
      await pump(
        tester,
        const DesktopDetailEmptyState(message: 'Select a task'),
      );

      // Delegates to the shared DesignSystemEmptyState grammar: step9 glyph,
      // subtitle1/highEmphasis title.
      expect(find.byType(DesignSystemEmptyState), findsOneWidget);
      final icon = tester.widget<Icon>(
        find.byIcon(Icons.touch_app_outlined),
      );
      expect(icon.size, dsTokensDark.spacing.step9);
      expect(icon.color, dsTokensDark.colors.text.lowEmphasis);

      final message = tester.widget<Text>(find.text('Select a task'));
      expect(message.style?.color, dsTokensDark.colors.text.highEmphasis);
      expect(
        message.style?.fontSize,
        dsTokensDark.typography.styles.subtitle.subtitle1.fontSize,
      );
      expect(message.textAlign, TextAlign.center);
    });

    testWidgets('honors a custom icon', (tester) async {
      await pump(
        tester,
        const DesktopDetailEmptyState(
          message: 'Pick something',
          icon: Icons.inbox_outlined,
        ),
      );

      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.byIcon(Icons.touch_app_outlined), findsNothing);
    });
  });
}
