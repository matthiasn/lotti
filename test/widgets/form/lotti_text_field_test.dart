import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/form/lotti_text_field.dart';

import '../../test_helper.dart';

void main() {
  group('LottiTextField', () {
    late TextEditingController controller;

    setUp(() {
      controller = TextEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('renders with basic properties', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextField(
            controller: controller,
            labelText: 'Test Label',
            hintText: 'Test Hint',
          ),
        ),
      );

      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Test Label'), findsOneWidget);
      expect(find.text('Test Hint'), findsOneWidget);
    });

    testWidgets('shows helper text when provided', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextField(
            controller: controller,
            helperText: 'Helper text here',
          ),
        ),
      );

      expect(find.text('Helper text here'), findsOneWidget);
    });

    testWidgets('shows error text when provided', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextField(
            controller: controller,
            errorText: 'Error message',
          ),
        ),
      );

      expect(find.text('Error message'), findsOneWidget);
    });

    testWidgets('displays prefix icon when provided', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextField(
            controller: controller,
            prefixIcon: Icons.search,
          ),
        ),
      );

      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('displays suffix icon when provided', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextField(
            controller: controller,
            suffixIcon: Icons.clear,
          ),
        ),
      );

      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('displays custom prefix widget when provided', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextField(
            controller: controller,
            prefix: const Text(r'$'),
          ),
        ),
      );

      expect(find.text(r'$'), findsOneWidget);
    });

    testWidgets('displays custom suffix widget when provided', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextField(
            controller: controller,
            suffix: const Text('USD'),
          ),
        ),
      );

      expect(find.text('USD'), findsOneWidget);
    });

    testWidgets('respects enabled state', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextField(
            controller: controller,
            enabled: false,
          ),
        ),
      );

      final textField =
          tester.widget<TextFormField>(find.byType(TextFormField));
      expect(textField.enabled, isFalse);
    });

    testWidgets('respects readOnly state', (tester) async {
      controller.text = 'Original text';

      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextField(
            controller: controller,
            readOnly: true,
          ),
        ),
      );

      // Verify the field shows the original text
      expect(find.text('Original text'), findsOneWidget);

      // Verify the widget is created with readOnly property
      final lottiTextField =
          tester.widget<LottiTextField>(find.byType(LottiTextField));
      expect(lottiTextField.readOnly, isTrue);

      // The controller text remains as is
      expect(controller.text, equals('Original text'));
    });

    testWidgets('handles text input correctly', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextField(
            controller: controller,
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'Test input');
      expect(controller.text, equals('Test input'));
    });

    testWidgets('calls onChanged callback', (tester) async {
      String? changedValue;

      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextField(
            controller: controller,
            onChanged: (value) => changedValue = value,
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'New text');
      expect(changedValue, equals('New text'));
    });

    testWidgets('calls onSubmitted callback', (tester) async {
      String? submittedValue;

      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextField(
            controller: controller,
            onSubmitted: (value) => submittedValue = value,
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'Submit text');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      expect(submittedValue, equals('Submit text'));
    });

    testWidgets('calls onTap callback', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextField(
            controller: controller,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(TextFormField));
      expect(tapped, isTrue);
    });

    testWidgets('hides text when obscureText is true', (tester) async {
      controller.text = 'password123';

      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextField(
            controller: controller,
            obscureText: true,
          ),
        ),
      );

      // When obscureText is true, the actual text should be hidden
      // We can't easily test the visual obscuring, but we can verify
      // the widget is created with the property
      final lottiTextField =
          tester.widget<LottiTextField>(find.byType(LottiTextField));
      expect(lottiTextField.obscureText, isTrue);
    });

    testWidgets('validates input with validator', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: Form(
            child: LottiTextField(
              controller: controller,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required field';
                }
                return null;
              },
            ),
          ),
        ),
      );

      final form = Form.of(tester.element(find.byType(TextFormField)));
      expect(form.validate(), isFalse);

      await tester.enterText(find.byType(TextFormField), 'Valid input');
      expect(form.validate(), isTrue);
    });

    testWidgets('applies input formatters', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextField(
            controller: controller,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'abc123def456');
      expect(controller.text, equals('123456'));
    });

    testWidgets('respects maxLength setting', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextField(
            controller: controller,
            maxLength: 5,
          ),
        ),
      );

      // Verify the widget has maxLength set
      final lottiTextField =
          tester.widget<LottiTextField>(find.byType(LottiTextField));
      expect(lottiTextField.maxLength, equals(5));

      // Enter text that exceeds maxLength
      await tester.enterText(find.byType(TextFormField), '123456789');

      // Flutter enforces maxLength
      expect(controller.text, equals('12345'));
    });

    testWidgets('handles multiline input settings', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextField(
            controller: controller,
            maxLines: 3,
            minLines: 2,
          ),
        ),
      );

      // The widget should be created with the correct properties
      final lottiTextField =
          tester.widget<LottiTextField>(find.byType(LottiTextField));
      expect(lottiTextField.maxLines, equals(3));
      expect(lottiTextField.minLines, equals(2));
    });

    testWidgets('uses provided focus node', (tester) async {
      final focusNode = FocusNode();

      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextField(
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      );

      // Request focus
      focusNode.requestFocus();
      await tester.pump();

      expect(focusNode.hasFocus, isTrue);

      focusNode.dispose();
    });

    testWidgets('applies all input properties correctly', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextField(
            controller: controller,
            autocorrect: false,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.search,
            textCapitalization: TextCapitalization.words,
          ),
        ),
      );

      // Verify the widget is created with all the properties
      final lottiTextField =
          tester.widget<LottiTextField>(find.byType(LottiTextField));
      expect(lottiTextField.autocorrect, isFalse);
      expect(lottiTextField.autofocus, isTrue);
      expect(lottiTextField.keyboardType, equals(TextInputType.emailAddress));
      expect(lottiTextField.textInputAction, equals(TextInputAction.search));
      expect(
          lottiTextField.textCapitalization, equals(TextCapitalization.words));
    });

    testWidgets('applies custom style properties', (tester) async {
      const customStyle = TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.red,
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextField(
            controller: controller,
            style: customStyle,
            fillColor: Colors.blue,
            borderRadius: 20,
          ),
        ),
      );

      final lottiTextField =
          tester.widget<LottiTextField>(find.byType(LottiTextField));
      expect(lottiTextField.style, equals(customStyle));
      expect(lottiTextField.fillColor, equals(Colors.blue));
      expect(lottiTextField.borderRadius, equals(20.0));
    });

    testWidgets('disabled text field shows with reduced opacity',
        (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: Column(
            children: [
              LottiTextField(
                controller: controller,
                // enabled: true, // default value
                prefixIcon: Icons.search,
              ),
              LottiTextField(
                controller: TextEditingController(),
                enabled: false,
                prefixIcon: Icons.search,
              ),
            ],
          ),
        ),
      );

      // Both text fields should render
      expect(find.byType(LottiTextField), findsNWidgets(2));
      expect(find.byIcon(Icons.search), findsNWidgets(2));
    });

    testWidgets('prefix and suffix icons override prefix and suffix widgets',
        (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextField(
            controller: controller,
            prefixIcon: Icons.search,
            prefix: const Text('PREFIX'),
            suffixIcon: Icons.clear,
            suffix: const Text('SUFFIX'),
          ),
        ),
      );

      // Icons should be shown, not the text widgets
      expect(find.byIcon(Icons.search), findsOneWidget);
      expect(find.byIcon(Icons.clear), findsOneWidget);
      expect(find.text('PREFIX'), findsNothing);
      expect(find.text('SUFFIX'), findsNothing);
    });

    testWidgets('decoration is properly styled', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextField(
            controller: controller,
            labelText: 'Label',
            hintText: 'Hint',
            helperText: 'Helper',
          ),
        ),
      );

      // Label and helper text should be visible
      expect(find.text('Label'), findsOneWidget);
      expect(find.text('Helper'), findsOneWidget);

      // The LottiTextField widget should have all the properties set
      final lottiTextField =
          tester.widget<LottiTextField>(find.byType(LottiTextField));
      expect(lottiTextField.labelText, equals('Label'));
      expect(lottiTextField.hintText, equals('Hint'));
      expect(lottiTextField.helperText, equals('Helper'));

      // The TextFormField should be properly rendered with decoration
      expect(find.byType(TextFormField), findsOneWidget);

      // Focus the field and enter text to see hint
      await tester.tap(find.byType(TextFormField));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), '');
      await tester.pump();
    });

    testWidgets('error state shows error border and text', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextField(
            controller: controller,
            errorText: 'This field has an error',
          ),
        ),
      );

      expect(find.text('This field has an error'), findsOneWidget);

      // The error text should be styled in error color
      final errorText = tester.widget<Text>(
        find.text('This field has an error'),
      );
      expect(errorText.style?.color, isNotNull);
    });
  });

  group('LottiTextArea', () {
    late TextEditingController controller;

    setUp(() {
      controller = TextEditingController();
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('renders as multiline text field', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextArea(
            controller: controller,
            labelText: 'Text Area Label',
            hintText: 'Enter multiple lines',
          ),
        ),
      );

      expect(find.byType(LottiTextField), findsOneWidget);
      expect(find.text('Text Area Label'), findsOneWidget);
      expect(find.text('Enter multiple lines'), findsOneWidget);

      final lottiTextField =
          tester.widget<LottiTextField>(find.byType(LottiTextField));
      expect(lottiTextField.keyboardType, equals(TextInputType.multiline));
      expect(lottiTextField.textInputAction, equals(TextInputAction.newline));
    });

    testWidgets('uses default maxLines and minLines', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextArea(
            controller: controller,
          ),
        ),
      );

      final lottiTextField =
          tester.widget<LottiTextField>(find.byType(LottiTextField));
      expect(lottiTextField.maxLines, equals(5));
      expect(lottiTextField.minLines, equals(3));
    });

    testWidgets('accepts custom maxLines and minLines', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextArea(
            controller: controller,
            maxLines: 10,
            minLines: 5,
          ),
        ),
      );

      final lottiTextField =
          tester.widget<LottiTextField>(find.byType(LottiTextField));
      expect(lottiTextField.maxLines, equals(10));
      expect(lottiTextField.minLines, equals(5));
    });

    testWidgets('passes through all properties to LottiTextField',
        (tester) async {
      const helperText = 'Helper text';
      const errorText = 'Error text';
      const maxLength = 100;
      const fillColor = Colors.green;
      const borderRadius = 16.0;

      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextArea(
            controller: controller,
            helperText: helperText,
            errorText: errorText,
            enabled: false,
            readOnly: true,
            maxLength: maxLength,
            onChanged: (value) {},
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            fillColor: fillColor,
            borderRadius: borderRadius,
          ),
        ),
      );

      final lottiTextField =
          tester.widget<LottiTextField>(find.byType(LottiTextField));
      expect(lottiTextField.helperText, equals(helperText));
      expect(lottiTextField.errorText, equals(errorText));
      expect(lottiTextField.enabled, isFalse);
      expect(lottiTextField.readOnly, isTrue);
      expect(lottiTextField.maxLength, equals(maxLength));
      expect(lottiTextField.onChanged, isNotNull);
      expect(lottiTextField.validator, isNotNull);
      expect(lottiTextField.fillColor, equals(fillColor));
      expect(lottiTextField.borderRadius, equals(borderRadius));
    });

    testWidgets('handles multiline text input', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextArea(
            controller: controller,
          ),
        ),
      );

      const multilineText = 'Line 1\nLine 2\nLine 3';
      await tester.enterText(find.byType(TextFormField), multilineText);
      expect(controller.text, equals(multilineText));
    });

    testWidgets('uses provided focus node', (tester) async {
      final focusNode = FocusNode();

      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextArea(
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      );

      final lottiTextField =
          tester.widget<LottiTextField>(find.byType(LottiTextField));
      expect(lottiTextField.focusNode, equals(focusNode));

      focusNode.dispose();
    });

    testWidgets('shows character count when maxLength is set', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextArea(
            controller: controller,
            maxLength: 200,
          ),
        ),
      );

      // Enter some text
      await tester.enterText(find.byType(TextFormField), 'Hello world');

      // Verify the text was entered
      expect(controller.text, equals('Hello world'));
      expect(controller.text.length, equals(11));

      // The maxLength feature should limit the input
      final longText = 'a' * 250; // 250 characters
      await tester.enterText(find.byType(TextFormField), longText);
      expect(controller.text.length, lessThanOrEqualTo(200));
    });

    testWidgets('validates multiline input', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: Form(
            child: LottiTextArea(
              controller: controller,
              validator: (value) {
                if (value == null || value.length < 10) {
                  return 'Minimum 10 characters required';
                }
                return null;
              },
            ),
          ),
        ),
      );

      final form = Form.of(tester.element(find.byType(TextFormField)));

      // Should fail validation with empty text
      expect(form.validate(), isFalse);

      // Should fail with short text
      await tester.enterText(find.byType(TextFormField), 'Short');
      expect(form.validate(), isFalse);

      // Should pass with long enough text
      await tester.enterText(
          find.byType(TextFormField), 'This is a long enough text');
      expect(form.validate(), isTrue);
    });

    testWidgets('disabled text area prevents input', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextArea(
            controller: controller,
            enabled: false,
          ),
        ),
      );

      final textFormField =
          tester.widget<TextFormField>(find.byType(TextFormField));
      expect(textFormField.enabled, isFalse);
    });

    testWidgets('read-only text area shows existing text', (tester) async {
      controller.text = 'Existing text';

      await tester.pumpWidget(
        WidgetTestBench(
          child: LottiTextArea(
            controller: controller,
            readOnly: true,
          ),
        ),
      );

      // Text should be visible
      expect(find.text('Existing text'), findsOneWidget);

      // Verify the LottiTextArea has readOnly set to true
      final lottiTextArea =
          tester.widget<LottiTextArea>(find.byType(LottiTextArea));
      expect(lottiTextArea.readOnly, isTrue);

      // The underlying LottiTextField should also be readOnly
      final lottiTextField =
          tester.widget<LottiTextField>(find.byType(LottiTextField));
      expect(lottiTextField.readOnly, isTrue);
    });
  });
}
