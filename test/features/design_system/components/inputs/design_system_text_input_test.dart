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
          leadingIcon: LottiIcons.search,
          trailingIcon: LottiIcons.close,
        ),
      );

      expect(find.byIcon(LottiIcons.search), findsOneWidget);
      expect(find.byIcon(LottiIcons.close), findsOneWidget);
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
          trailingIcon: LottiIcons.close,
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

      expect(
        find.descendant(
          of: find.byKey(key),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ConstrainedBox &&
                widget.constraints ==
                    BoxConstraints.tightFor(
                      height: dsTokensLight.spacing.step9,
                    ),
          ),
        ),
        findsOneWidget,
      );
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

      expect(
        find.descendant(
          of: find.byKey(key),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ConstrainedBox &&
                widget.constraints ==
                    BoxConstraints.tightFor(
                      height: dsTokensLight.spacing.step8,
                    ),
          ),
        ),
        findsOneWidget,
      );
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

      // Same chrome as an editable field — fill AND resting outline — with
      // only the value dropped to medium emphasis.
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
      expect(
        (decoration.border! as Border).top.color,
        dsTokensLight.colors.text.highEmphasis.withValues(alpha: 0.12),
      );
      expect(
        textField.style?.color,
        dsTokensLight.colors.text.mediumEmphasis,
      );

      // Unlike enabled: false, the field is not dimmed.
      expect(
        find.ancestor(
          of: find.byType(TextField),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
    });

    testWidgets('an editable input carries the level01 fill too', (
      tester,
    ) async {
      const key = Key('filled-input');

      await _pumpInput(
        tester,
        const DesignSystemTextInput(key: key, label: 'Goal name'),
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
      expect(
        (decoratedBox.decoration as BoxDecoration).color,
        dsTokensLight.colors.background.level01,
      );
      // An editable value keeps full emphasis.
      expect(
        tester.widget<TextField>(find.byType(TextField)).style?.color,
        dsTokensLight.colors.text.highEmphasis,
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

      // Hover never promotes a readOnly field's border.
      expect(currentBorderColor(), restingColor);
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
          trailingIcon: LottiIcons.edit,
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
          trailingIcon: LottiIcons.close,
          trailingIconKey: Key('decorative-trailing'),
        ),
      );

      // A decorative icon has no affordance to key.
      expect(find.byKey(const Key('decorative-trailing')), findsNothing);
      expect(find.byIcon(LottiIcons.close), findsOneWidget);
    });

    testWidgets('a swapped external controller drives the field', (
      tester,
    ) async {
      final first = TextEditingController(text: 'first');
      addTearDown(first.dispose);
      final second = TextEditingController(text: 'second');
      addTearDown(second.dispose);

      await _pumpInput(
        tester,
        DesignSystemTextInput(controller: first, label: 'Value'),
      );
      expect(find.text('first'), findsOneWidget);

      await _pumpInput(
        tester,
        DesignSystemTextInput(controller: second, label: 'Value'),
      );
      expect(find.text('second'), findsOneWidget);
      expect(find.text('first'), findsNothing);

      // Edits land on the new controller, not the initState-era one.
      await tester.enterText(find.byType(TextField), 'typed');
      expect(second.text, 'typed');
      expect(first.text, 'first');
    });

    testWidgets('dropping the external controller falls back to an internal '
        'one', (tester) async {
      final external = TextEditingController(text: 'external');

      await _pumpInput(
        tester,
        DesignSystemTextInput(controller: external, label: 'Value'),
      );
      expect(find.text('external'), findsOneWidget);

      await _pumpInput(
        tester,
        const DesignSystemTextInput(label: 'Value'),
      );
      external.dispose();

      // A fresh internal controller: empty, editable, and detached from the
      // disposed external one.
      expect(find.text('external'), findsNothing);
      await tester.enterText(find.byType(TextField), 'internal edit');
      expect(find.text('internal edit'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('gaining an external controller replaces the owned internal '
        'one without error', (tester) async {
      final external = TextEditingController(text: 'adopted');
      addTearDown(external.dispose);

      await _pumpInput(
        tester,
        const DesignSystemTextInput(label: 'Value'),
      );
      await tester.enterText(find.byType(TextField), 'scratch');

      await _pumpInput(
        tester,
        DesignSystemTextInput(controller: external, label: 'Value'),
      );

      expect(find.text('adopted'), findsOneWidget);
      expect(find.text('scratch'), findsNothing);
      await tester.enterText(find.byType(TextField), 'kept');
      expect(external.text, 'kept');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'a reparented input survives its old controller being disposed',
      (tester) async {
        // Regression: a GlobalKey-preserved element used to keep its
        // initState-era controller, so a reorder that disposed the old
        // owner's controller made the next keystroke throw.
        final anchor = GlobalKey();
        final first = TextEditingController(text: 'one');
        final second = TextEditingController(text: 'two');
        addTearDown(second.dispose);

        Widget anchoredInput(TextEditingController controller) => KeyedSubtree(
          key: anchor,
          child: DesignSystemTextInput(controller: controller, label: 'Value'),
        );

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            SizedBox(
              width: 401,
              child: Column(
                children: [anchoredInput(first), const SizedBox(height: 8)],
              ),
            ),
            theme: DesignSystemTheme.light(),
          ),
        );
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            SizedBox(
              width: 401,
              child: Column(
                children: [const SizedBox(height: 8), anchoredInput(second)],
              ),
            ),
            theme: DesignSystemTheme.light(),
          ),
        );
        first.dispose();

        await tester.enterText(find.byType(TextField), 'typed');
        expect(second.text, 'typed');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('a long read-only value wraps instead of clipping', (
      tester,
    ) async {
      const longValue =
          'Gym (3×/week) · Run (5×/week) · Average steps per day '
          '(8,000 steps a day) · Deep work (no more than 12 hours)';
      final controller = TextEditingController(text: longValue);
      addTearDown(controller.dispose);

      await _pumpInput(
        tester,
        DesignSystemTextInput(
          controller: controller,
          label: 'Goal name',
          readOnly: true,
        ),
      );
      final readOnlyField = tester.widget<TextField>(find.byType(TextField));
      expect(readOnlyField.maxLines, isNull);
      final readOnlyHeight = tester.getSize(find.byType(TextField)).height;

      await _pumpInput(
        tester,
        DesignSystemTextInput(controller: controller, label: 'Goal name'),
      );
      final editableField = tester.widget<TextField>(find.byType(TextField));
      expect(editableField.maxLines, 1);
      final editableHeight = tester.getSize(find.byType(TextField)).height;

      // The same value wraps to multiple lines only in the read-only field.
      expect(readOnlyHeight, greaterThan(editableHeight * 1.5));
    });

    testWidgets('text is vertically centered with icons', (tester) async {
      await _pumpInput(
        tester,
        const DesignSystemTextInput(
          label: 'With Icons',
          leadingIcon: LottiIcons.search,
          trailingIcon: LottiIcons.close,
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
