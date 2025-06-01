import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/widgets/copyable_text_field.dart';

void main() {
  group('CopyableTextField widget tests', () {
    late TextEditingController controller;

    setUp(() {
      controller = TextEditingController();
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    tearDown(() {
      controller.dispose();
    });

    Widget buildTestWidget({
      required Widget child,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: child,
        ),
      );
    }

    testWidgets('widget builds correctly with all properties', (tester) async {
      const testDecoration = InputDecoration(
        labelText: 'Test Label',
        hintText: 'Test Hint',
      );

      await tester.pumpWidget(
        buildTestWidget(
          child: CopyableTextField(
            controller: controller,
            onChanged: (_) {},
            decoration: testDecoration,
            obscureText: true,
            keyboardType: TextInputType.number,
          ),
        ),
      );

      // Verify the widget tree structure
      expect(find.byType(CopyableTextField), findsOneWidget);
      expect(find.byType(CallbackShortcuts), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Verify TextField properties
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller, equals(controller));
      expect(textField.obscureText, isTrue);
      expect(textField.maxLines, equals(1));
      expect(textField.keyboardType, equals(TextInputType.number));
      expect(textField.decoration?.labelText, equals('Test Label'));
      expect(textField.decoration?.hintText, equals('Test Hint'));
    });

    testWidgets('onChanged callback is triggered', (tester) async {
      var changedValue = '';

      await tester.pumpWidget(
        buildTestWidget(
          child: CopyableTextField(
            controller: controller,
            onChanged: (value) => changedValue = value,
            decoration: const InputDecoration(),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Hello World');
      expect(changedValue, equals('Hello World'));
      expect(controller.text, equals('Hello World'));
    });

    testWidgets('keyboard shortcuts are properly configured', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: CopyableTextField(
            controller: controller,
            onChanged: (_) {},
            decoration: const InputDecoration(),
          ),
        ),
      );

      final callbackShortcuts = tester.widget<CallbackShortcuts>(
        find.byType(CallbackShortcuts),
      );

      // Verify all shortcuts are registered
      expect(callbackShortcuts.bindings.length, equals(4));

      // Verify specific shortcuts
      final shortcuts = callbackShortcuts.bindings.keys.toList();
      expect(
        shortcuts.any((s) =>
            s is SingleActivator &&
            s.trigger == LogicalKeyboardKey.keyC &&
            s.meta),
        isTrue,
      );
      expect(
        shortcuts.any((s) =>
            s is SingleActivator &&
            s.trigger == LogicalKeyboardKey.keyV &&
            s.meta),
        isTrue,
      );
      expect(
        shortcuts.any((s) =>
            s is SingleActivator &&
            s.trigger == LogicalKeyboardKey.keyX &&
            s.meta),
        isTrue,
      );
      expect(
        shortcuts.any((s) =>
            s is SingleActivator &&
            s.trigger == LogicalKeyboardKey.keyA &&
            s.meta),
        isTrue,
      );
    });

    testWidgets('contextMenuBuilder is configured', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: CopyableTextField(
            controller: controller,
            onChanged: (_) {},
            decoration: const InputDecoration(),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.contextMenuBuilder, isNotNull);
    });

    testWidgets('focus node is created and connected', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: CopyableTextField(
            controller: controller,
            onChanged: (_) {},
            decoration: const InputDecoration(),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.focusNode, isNotNull);

      // Test focus
      await tester.tap(find.byType(TextField));
      await tester.pump();

      expect(textField.focusNode!.hasFocus, isTrue);
    });

    testWidgets('widget disposes properly', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: CopyableTextField(
            controller: controller,
            onChanged: (_) {},
            decoration: const InputDecoration(),
          ),
        ),
      );

      expect(find.byType(CopyableTextField), findsOneWidget);

      await tester.pumpWidget(
        buildTestWidget(
          child: const SizedBox(),
        ),
      );

      expect(find.byType(CopyableTextField), findsNothing);
    });

    testWidgets('handles null onChanged callback', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: CopyableTextField(
            controller: controller,
            onChanged: null,
            decoration: const InputDecoration(),
          ),
        ),
      );

      // Should not throw when entering text
      await tester.enterText(find.byType(TextField), 'Test');
      expect(controller.text, equals('Test'));
    });

    testWidgets('default property values are correct', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: CopyableTextField(
            controller: controller,
            onChanged: (_) {},
            decoration: const InputDecoration(),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isFalse);
      expect(textField.maxLines, equals(1));
      expect(textField.keyboardType, equals(TextInputType.text));
    });

    testWidgets('multiline text field works', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: CopyableTextField(
            controller: controller,
            onChanged: (_) {},
            decoration: const InputDecoration(),
            maxLines: 5,
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.maxLines, equals(5));

      // Enter multiline text
      await tester.enterText(find.byType(TextField), 'Line 1\nLine 2\nLine 3');
      expect(controller.text, equals('Line 1\nLine 2\nLine 3'));
    });

    testWidgets('controller text updates are reflected', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: CopyableTextField(
            controller: controller,
            onChanged: (_) {},
            decoration: const InputDecoration(),
          ),
        ),
      );

      // Update controller directly
      controller.text = 'Updated Text';
      await tester.pump();

      // Verify the text field shows the updated text
      expect(find.text('Updated Text'), findsOneWidget);
    });

    testWidgets('selection changes are handled', (tester) async {
      controller.text = 'Hello World';

      await tester.pumpWidget(
        buildTestWidget(
          child: CopyableTextField(
            controller: controller,
            onChanged: (_) {},
            decoration: const InputDecoration(),
          ),
        ),
      );

      // Change selection
      controller.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);
      await tester.pump();

      expect(controller.selection.baseOffset, equals(0));
      expect(controller.selection.extentOffset, equals(5));
    });

    testWidgets('text field accepts input', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          child: CopyableTextField(
            controller: controller,
            onChanged: (_) {},
            decoration: const InputDecoration(),
          ),
        ),
      );

      // Type text
      await tester.enterText(find.byType(TextField), 'Test Input');
      expect(controller.text, equals('Test Input'));

      // Clear and type new text
      await tester.enterText(find.byType(TextField), 'New Text');
      expect(controller.text, equals('New Text'));
    });

    testWidgets('obscured text field hides text', (tester) async {
      controller.text = 'password123';

      await tester.pumpWidget(
        buildTestWidget(
          child: CopyableTextField(
            controller: controller,
            onChanged: (_) {},
            decoration: const InputDecoration(),
            obscureText: true,
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.obscureText, isTrue);

      // The text is still in the EditableText widget, just obscured visually
      // So we verify the obscureText property is true instead
      expect(controller.text, equals('password123'));
    });
  });
}
