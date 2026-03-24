import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemTextInput', () {
    testWidgets('renders with label and hint text', (tester) async {
      const key = Key('basic-input');

      await _pumpInput(
        tester,
        const DesignSystemTextInput(
          key: key,
          label: 'Name',
          hintText: 'Enter name...',
        ),
      );

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Enter name...'), findsOneWidget);
    });

    testWidgets('renders helper text below field', (tester) async {
      await _pumpInput(
        tester,
        const DesignSystemTextInput(
          label: 'Email',
          helperText: 'Your work email',
        ),
      );

      expect(find.text('Your work email'), findsOneWidget);
    });

    testWidgets('renders error text and hides helper when error is set', (
      tester,
    ) async {
      await _pumpInput(
        tester,
        const DesignSystemTextInput(
          label: 'Required',
          helperText: 'Helper',
          errorText: 'Required field',
        ),
      );

      expect(find.text('Required field'), findsOneWidget);
      expect(find.text('Helper'), findsNothing);
    });

    testWidgets('renders leading and trailing icons', (tester) async {
      const key = Key('icons-input');

      await _pumpInput(
        tester,
        const DesignSystemTextInput(
          key: key,
          label: 'Search',
          leadingIcon: Icons.search,
          trailingIcon: Icons.clear,
        ),
      );

      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('calls onChanged when text is entered', (tester) async {
      String? changedText;

      await _pumpInput(
        tester,
        DesignSystemTextInput(
          label: 'Input',
          onChanged: (text) => changedText = text,
        ),
      );

      await tester.enterText(find.byType(TextField), 'Hello');
      expect(changedText, 'Hello');
    });

    testWidgets('applies disabled opacity when not enabled', (tester) async {
      const key = Key('disabled-input');

      await _pumpInput(
        tester,
        const DesignSystemTextInput(
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
      const key = Key('error-input');

      await _pumpInput(
        tester,
        const DesignSystemTextInput(
          key: key,
          label: 'Error',
          errorText: 'Invalid',
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
      const key = Key('semantics-input');

      await _pumpInput(
        tester,
        const DesignSystemTextInput(
          key: key,
          label: 'Name',
          semanticsLabel: 'Enter your name',
        ),
      );

      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Enter your name',
          ),
        ),
      );

      expect(semantics.properties.label, 'Enter your name');
    });

    testWidgets('disposes internal controller without error', (tester) async {
      await _pumpInput(
        tester,
        const DesignSystemTextInput(label: 'Disposable'),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SizedBox.shrink(),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('uses external controller when provided', (tester) async {
      final controller = TextEditingController(text: 'Initial');

      await _pumpInput(
        tester,
        DesignSystemTextInput(
          controller: controller,
          label: 'External',
        ),
      );

      expect(find.text('Initial'), findsOneWidget);

      controller.dispose();
    });
  });
}

Future<void> _pumpInput(
  WidgetTester tester,
  Widget child,
) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      SizedBox(width: 401, child: child),
      theme: DesignSystemTheme.light(),
    ),
  );
}
