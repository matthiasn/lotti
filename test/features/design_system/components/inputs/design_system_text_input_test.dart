import 'dart:ui' show PointerDeviceKind;

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

    testWidgets('associates the label and helper text with the field', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();

      await _pumpInput(
        tester,
        const DesignSystemTextInput(
          label: 'Email',
          helperText: 'Your work email',
        ),
      );

      final field = find.bySemanticsLabel('Email, Your work email');
      expect(field, findsOneWidget);
      expect(
        tester.getSemantics(field),
        matchesSemantics(
          label: 'Email, Your work email',
          isTextField: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasFocusAction: true,
          hasTapAction: true,
        ),
      );

      semantics.dispose();
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

    testWidgets('associates and announces validation errors', (tester) async {
      final semantics = tester.ensureSemantics();

      await _pumpInput(
        tester,
        const DesignSystemTextInput(
          label: 'Required',
          errorText: 'Required field',
        ),
      );

      final field = find.bySemanticsLabel('Required, Required field');
      expect(field, findsOneWidget);
      expect(
        tester.getSemantics(field),
        matchesSemantics(
          label: 'Required, Required field',
          isTextField: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasFocusAction: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Required field')),
        matchesSemantics(
          label: 'Required field',
          isLiveRegion: true,
        ),
      );

      semantics.dispose();
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

    testWidgets('passes the requested keyboard type to the text field', (
      tester,
    ) async {
      await _pumpInput(
        tester,
        const DesignSystemTextInput(
          label: 'Count',
          keyboardType: TextInputType.number,
        ),
      );

      expect(
        tester.widget<TextField>(find.byType(TextField)).keyboardType,
        TextInputType.number,
      );
    });

    testWidgets('labels an actionable trailing icon for screen readers', (
      tester,
    ) async {
      var clearCount = 0;
      final semantics = tester.ensureSemantics();

      await _pumpInput(
        tester,
        DesignSystemTextInput(
          label: 'Search',
          trailingIcon: Icons.clear,
          trailingIconTooltip: 'Clear search',
          onTrailingIconTap: () => clearCount++,
        ),
      );

      final clearButton = find.bySemanticsLabel('Clear search');
      expect(
        tester.getSemantics(clearButton),
        matchesSemantics(
          label: 'Clear search',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(clearButton);
      expect(clearCount, 1);
      semantics.dispose();
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

    testWidgets('updates the border on mouse hover and restores it on exit', (
      tester,
    ) async {
      const key = Key('hover-input');

      await _pumpInput(
        tester,
        const DesignSystemTextInput(
          key: key,
          label: 'Hoverable',
        ),
      );

      Color currentBorderColor() {
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
        return ((decoratedBox.decoration as BoxDecoration).border! as Border)
            .top
            .color;
      }

      final restingColor = dsTokensLight.colors.text.highEmphasis.withValues(
        alpha: 0.12,
      );
      expect(currentBorderColor(), restingColor);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      await gesture.moveTo(tester.getCenter(find.byType(TextField)));
      await tester.pump();
      expect(
        currentBorderColor(),
        dsTokensLight.colors.text.mediumEmphasis,
      );

      await gesture.moveTo(const Offset(-100, -100));
      await tester.pump();
      expect(currentBorderColor(), restingColor);
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

    testWidgets('uses medium emphasis color for cursor', (tester) async {
      await _pumpInput(
        tester,
        const DesignSystemTextInput(label: 'Caret'),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));

      expect(
        textField.cursorColor,
        dsTokensLight.colors.text.mediumEmphasis,
      );
      expect(textField.decoration!.border, InputBorder.none);
      expect(textField.decoration!.enabledBorder, InputBorder.none);
      expect(textField.decoration!.disabledBorder, InputBorder.none);
      expect(textField.decoration!.focusedBorder, InputBorder.none);
      expect(textField.decoration!.errorBorder, InputBorder.none);
      expect(textField.decoration!.focusedErrorBorder, InputBorder.none);
    });

    testWidgets('medium field height uses step9', (tester) async {
      const key = Key('medium-height');

      await _pumpInput(
        tester,
        const DesignSystemTextInput(
          key: key,
          label: 'Medium',
        ),
      );

      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SizedBox &&
                widget.height == dsTokensLight.spacing.step9,
          ),
        ),
      );

      expect(sizedBox.height, dsTokensLight.spacing.step9);
    });

    testWidgets('small field height uses step8', (tester) async {
      const key = Key('small-height');

      await _pumpInput(
        tester,
        const DesignSystemTextInput(
          key: key,
          label: 'Small',
          size: DesignSystemTextInputSize.small,
        ),
      );

      final sizedBox = tester.widget<SizedBox>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SizedBox &&
                widget.height == dsTokensLight.spacing.step8,
          ),
        ),
      );

      expect(sizedBox.height, dsTokensLight.spacing.step8);
    });

    testWidgets('readOnly renders a quiet display field, not a disabled one', (
      tester,
    ) async {
      const key = Key('read-only-input');
      final controller = TextEditingController(text: 'Gym & Run');
      addTearDown(controller.dispose);

      await _pumpInput(
        tester,
        DesignSystemTextInput(
          key: key,
          controller: controller,
          label: 'Goal name',
          readOnly: true,
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.readOnly, isTrue);
      expect(textField.showCursor, isFalse);

      // Quiet fill, no outline — a display value, not an input at rest.
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
      expect(decoration.color, dsTokensLight.colors.background.level01);
      expect((decoration.border! as Border).top.color, Colors.transparent);

      // Unlike enabled: false, the field is not dimmed.
      expect(
        find.ancestor(
          of: find.byType(TextField),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
    });

    testWidgets('readOnly ignores hover instead of promoting the border', (
      tester,
    ) async {
      const key = Key('read-only-hover');

      await _pumpInput(
        tester,
        const DesignSystemTextInput(
          key: key,
          label: 'Goal name',
          readOnly: true,
        ),
      );

      Color currentBorderColor() {
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
        return ((decoratedBox.decoration as BoxDecoration).border! as Border)
            .top
            .color;
      }

      expect(currentBorderColor(), Colors.transparent);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.byType(TextField)));
      await tester.pump();

      expect(currentBorderColor(), Colors.transparent);
    });

    testWidgets('a readOnly field keeps its trailing icon action live', (
      tester,
    ) async {
      var unlocks = 0;

      await _pumpInput(
        tester,
        DesignSystemTextInput(
          label: 'Goal name',
          readOnly: true,
          trailingIcon: Icons.edit_outlined,
          trailingIconTooltip: 'Edit goal name',
          trailingIconKey: const Key('unlock-title'),
          onTrailingIconTap: () => unlocks++,
        ),
      );

      final unlock = find.byKey(const Key('unlock-title'));
      expect(unlock, findsOneWidget);
      await tester.tap(unlock);
      expect(unlocks, 1);
    });

    testWidgets('trailingIconKey only lands on an actionable icon', (
      tester,
    ) async {
      await _pumpInput(
        tester,
        const DesignSystemTextInput(
          label: 'Search',
          trailingIcon: Icons.clear,
          trailingIconKey: Key('decorative-trailing'),
        ),
      );

      // A decorative icon has no affordance to key.
      expect(find.byKey(const Key('decorative-trailing')), findsNothing);
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('text is vertically centered with icons', (tester) async {
      await _pumpInput(
        tester,
        const DesignSystemTextInput(
          label: 'With Icons',
          leadingIcon: Icons.search,
          trailingIcon: Icons.clear,
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));

      expect(textField.textAlignVertical, TextAlignVertical.center);
      expect(textField.decoration?.isDense, isTrue);
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
