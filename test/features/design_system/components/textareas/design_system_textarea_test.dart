import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemTextarea', () {
    testWidgets('renders with label and hint text', (tester) async {
      const key = Key('basic-textarea');

      await _pumpTextarea(
        tester,
        const DesignSystemTextarea(
          key: key,
          label: 'Description',
          hintText: 'Enter text...',
        ),
      );

      expect(find.text('Description'), findsOneWidget);
      expect(find.text('Enter text...'), findsOneWidget);
    });

    testWidgets('renders helper text below field', (tester) async {
      const key = Key('helper-textarea');

      await _pumpTextarea(
        tester,
        const DesignSystemTextarea(
          key: key,
          label: 'Notes',
          helperText: 'Maximum 500 characters',
        ),
      );

      expect(find.text('Maximum 500 characters'), findsOneWidget);
    });

    testWidgets('renders error text and hides helper when error is set', (
      tester,
    ) async {
      const key = Key('error-textarea');

      await _pumpTextarea(
        tester,
        const DesignSystemTextarea(
          key: key,
          label: 'Required',
          helperText: 'This is helper',
          errorText: 'Field is required',
        ),
      );

      expect(find.text('Field is required'), findsOneWidget);
      expect(find.text('This is helper'), findsNothing);
    });

    testWidgets('shows character counter when enabled', (tester) async {
      const key = Key('counter-textarea');
      final controller = TextEditingController(text: 'Hello');

      await _pumpTextarea(
        tester,
        DesignSystemTextarea(
          key: key,
          controller: controller,
          maxLength: 100,
          showCounter: true,
        ),
      );

      expect(find.text('5/100'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('calls onChanged when text is entered', (tester) async {
      String? changedText;

      await _pumpTextarea(
        tester,
        DesignSystemTextarea(
          label: 'Input',
          onChanged: (text) => changedText = text,
        ),
      );

      await tester.enterText(find.byType(TextField), 'Hello world');
      expect(changedText, 'Hello world');
    });

    testWidgets('applies disabled opacity when not enabled', (tester) async {
      const key = Key('disabled-textarea');

      await _pumpTextarea(
        tester,
        const DesignSystemTextarea(
          key: key,
          label: 'Disabled',
          enabled: false,
        ),
      );

      final opacity = tester.widget<Opacity>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(Opacity),
        ),
      );

      expect(opacity.opacity, dsTokensLight.colors.text.lowEmphasis.a);
    });

    testWidgets('applies error border color when errorText is set', (
      tester,
    ) async {
      const key = Key('error-border');

      await _pumpTextarea(
        tester,
        const DesignSystemTextarea(
          key: key,
          label: 'Error field',
          errorText: 'Required',
        ),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).border != null,
          ),
        ),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;
      final border = decoration.border! as Border;

      expect(
        border.top.color,
        dsTokensLight.colors.alert.error.defaultColor,
      );
    });

    testWidgets('provides semantics label', (tester) async {
      const key = Key('semantics-textarea');

      await _pumpTextarea(
        tester,
        const DesignSystemTextarea(
          key: key,
          label: 'Message',
          semanticsLabel: 'Enter your message',
        ),
      );

      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Enter your message',
          ),
        ),
      );

      expect(semantics.properties.label, 'Enter your message');
    });

    testWidgets('renders without label when not provided', (tester) async {
      await _pumpTextarea(
        tester,
        const DesignSystemTextarea(
          hintText: 'No label here',
        ),
      );

      expect(find.text('No label here'), findsOneWidget);
    });

    testWidgets('disposes internal controller without error', (tester) async {
      await _pumpTextarea(
        tester,
        const DesignSystemTextarea(label: 'Disposable'),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox.shrink(),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('uses theme-aware color for cursor', (tester) async {
      await _pumpTextarea(
        tester,
        const DesignSystemTextarea(label: 'Caret'),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));

      expect(
        textField.cursorColor,
        dsTokensLight.colors.text.highEmphasis,
      );
      expect(textField.decoration!.border, InputBorder.none);
      expect(textField.decoration!.enabledBorder, InputBorder.none);
      expect(textField.decoration!.disabledBorder, InputBorder.none);
      expect(textField.decoration!.focusedBorder, InputBorder.none);
      expect(textField.decoration!.errorBorder, InputBorder.none);
      expect(textField.decoration!.focusedErrorBorder, InputBorder.none);
    });

    testWidgets('content padding gives enough room at top', (tester) async {
      await _pumpTextarea(
        tester,
        const DesignSystemTextarea(label: 'Padded'),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      final contentPadding =
          textField.decoration!.contentPadding! as EdgeInsets;

      // Top padding should be step4 to avoid squished text
      expect(
        contentPadding.top,
        dsTokensLight.spacing.step4,
      );
      expect(
        contentPadding.bottom,
        dsTokensLight.spacing.step3,
      );
    });
  });
}

Future<void> _pumpTextarea(
  WidgetTester tester,
  Widget child,
) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      SizedBox(width: 405, child: child),
      theme: DesignSystemTheme.light(),
    ),
  );
}
