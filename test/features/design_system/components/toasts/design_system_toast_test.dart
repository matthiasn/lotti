import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemToast', () {
    testWidgets('renders success styling from tokens and dismisses', (
      tester,
    ) async {
      var dismissed = false;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SizedBox(
            width: 320,
            child: DesignSystemToast(
              tone: DesignSystemToastTone.success,
              title: 'Success',
              description: 'Notification details',
              onDismiss: () => dismissed = true,
            ),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      final title = tester.widget<Text>(find.text('Success'));
      final description = tester.widget<Text>(
        find.text('Notification details'),
      );
      final borderBox = tester.widget<DecoratedBox>(
        find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              ((widget.decoration as BoxDecoration).border as Border?)
                      ?.top
                      .color ==
                  dsTokensLight.colors.alert.success.defaultColor,
        ),
      );

      expect(title.style?.fontSize, dsTokensLight.typography.size.subtitle2);
      expect(title.style?.color, dsTokensLight.colors.text.highEmphasis);
      expect(
        description.style?.fontSize,
        dsTokensLight.typography.size.caption,
      );
      expect(
        description.style?.color,
        dsTokensLight.colors.text.mediumEmphasis,
      );
      expect(
        ((borderBox.decoration as BoxDecoration).border! as Border).top.color,
        dsTokensLight.colors.alert.success.defaultColor,
      );

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(dismissed, isTrue);
    });

    testWidgets('maps warning and error tones to the correct icons', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const Column(
            children: [
              DesignSystemToast(
                tone: DesignSystemToastTone.warning,
                title: 'Warning',
                description: 'Notification details',
              ),
              SizedBox(height: 16),
              DesignSystemToast(
                tone: DesignSystemToastTone.error,
                title: 'Error',
                description: 'Notification details',
              ),
            ],
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
      expect(find.byIcon(Icons.error_rounded), findsOneWidget);
      expect(
        find.byIcon(Icons.close_rounded),
        findsNothing,
        reason: 'dismiss icon hidden when onDismiss is null',
      );
    });
  });
}
