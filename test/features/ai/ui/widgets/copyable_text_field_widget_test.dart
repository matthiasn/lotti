import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/widgets/copyable_text_field.dart';

void main() {
  group('CopyableTextField Widget Integration Tests', () {
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

    group('Widget Construction and Properties', () {
      testWidgets('widget builds correctly with all properties',
          (tester) async {
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
              maxLines: 3,
              keyboardType: TextInputType.number,
            ),
          ),
        );

        // Verify widget tree structure
        expect(find.byType(CopyableTextField), findsOneWidget);
        expect(find.byType(CallbackShortcuts), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);

        // Verify TextField properties
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller, equals(controller));
        expect(textField.obscureText, isFalse);
        expect(textField.maxLines, equals(3));
        expect(textField.keyboardType, equals(TextInputType.number));
        expect(textField.decoration?.labelText, equals('Test Label'));
        expect(textField.decoration?.hintText, equals('Test Hint'));
        expect(textField.focusNode, isNotNull);
        expect(textField.contextMenuBuilder, isNotNull);
      });

      testWidgets('widget builds correctly with obscured text', (tester) async {
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
        expect(textField.maxLines, equals(1));
      });

      testWidgets('default property values are applied correctly',
          (tester) async {
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

      testWidgets('widget disposes properly without errors', (tester) async {
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

        // Remove widget from tree
        await tester.pumpWidget(
          buildTestWidget(
            child: const SizedBox(),
          ),
        );

        expect(find.byType(CopyableTextField), findsNothing);
        // Verify no exceptions during disposal
      });
    });

    group('Text Input and OnChanged Callback Integration', () {
      testWidgets('onChanged callback is triggered correctly', (tester) async {
        var changedValue = '';
        var callCount = 0;

        await tester.pumpWidget(
          buildTestWidget(
            child: CopyableTextField(
              controller: controller,
              onChanged: (value) {
                changedValue = value;
                callCount++;
              },
              decoration: const InputDecoration(),
            ),
          ),
        );

        // Test text input
        await tester.enterText(find.byType(TextField), 'Hello World');
        expect(changedValue, equals('Hello World'));
        expect(controller.text, equals('Hello World'));
        expect(callCount, equals(1));

        // Test clear and new input
        await tester.enterText(find.byType(TextField), 'New Text');
        expect(changedValue, equals('New Text'));
        expect(controller.text, equals('New Text'));
        expect(callCount, equals(2));
      });

      testWidgets('handles null onChanged callback gracefully', (tester) async {
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

      testWidgets('multiline input works correctly', (tester) async {
        var changedValue = '';

        await tester.pumpWidget(
          buildTestWidget(
            child: CopyableTextField(
              controller: controller,
              onChanged: (value) => changedValue = value,
              decoration: const InputDecoration(),
              maxLines: 5,
            ),
          ),
        );

        const multilineText = 'Line 1\nLine 2\nLine 3';
        await tester.enterText(find.byType(TextField), multilineText);
        expect(controller.text, equals(multilineText));
        expect(changedValue, equals(multilineText));
      });

      testWidgets('controller updates are reflected in widget', (tester) async {
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
        controller.text = 'Programmatic Update';
        await tester.pump();

        expect(find.text('Programmatic Update'), findsOneWidget);
      });
    });

    group('Focus Management', () {
      testWidgets('focus is handled correctly', (tester) async {
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
        expect(textField.focusNode!.hasFocus, isFalse);

        // Tap to focus
        await tester.tap(find.byType(TextField));
        await tester.pump();

        expect(textField.focusNode!.hasFocus, isTrue);
      });

      testWidgets('focus node is properly connected', (tester) async {
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
        expect(textField.focusNode, isA<FocusNode>());
      });
    });

    group('Keyboard Shortcuts Integration', () {
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

        // Verify specific shortcuts exist
        final shortcuts = callbackShortcuts.bindings.keys.toList();

        // Copy shortcut (Cmd+C)
        expect(
          shortcuts.any((s) =>
              s is SingleActivator &&
              s.trigger == LogicalKeyboardKey.keyC &&
              s.meta),
          isTrue,
        );

        // Paste shortcut (Cmd+V)
        expect(
          shortcuts.any((s) =>
              s is SingleActivator &&
              s.trigger == LogicalKeyboardKey.keyV &&
              s.meta),
          isTrue,
        );

        // Cut shortcut (Cmd+X)
        expect(
          shortcuts.any((s) =>
              s is SingleActivator &&
              s.trigger == LogicalKeyboardKey.keyX &&
              s.meta),
          isTrue,
        );

        // Select All shortcut (Cmd+A)
        expect(
          shortcuts.any((s) =>
              s is SingleActivator &&
              s.trigger == LogicalKeyboardKey.keyA &&
              s.meta),
          isTrue,
        );
      });

      testWidgets('shortcuts have correct callback functions', (tester) async {
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

        // Verify all shortcuts have callbacks
        for (final binding in callbackShortcuts.bindings.values) {
          expect(binding, isNotNull);
          expect(binding, isA<Function>());
        }
      });
    });

    group('Context Menu Integration', () {
      testWidgets('context menu builder is configured', (tester) async {
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

      testWidgets('context menu builder function is properly set',
          (tester) async {
        controller.text = 'Test Text';

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
        final contextMenuBuilder = textField.contextMenuBuilder;

        expect(contextMenuBuilder, isNotNull);
        expect(contextMenuBuilder, isA<Function>());
      });
    });

    group('ClipboardHandler Integration', () {
      testWidgets('clipboard handler is created and connected', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            child: CopyableTextField(
              controller: controller,
              onChanged: (_) {},
              decoration: const InputDecoration(),
            ),
          ),
        );

        // We can't directly access the private _clipboardHandler,
        // but we can verify the integration works by testing the shortcuts
        final callbackShortcuts = tester.widget<CallbackShortcuts>(
          find.byType(CallbackShortcuts),
        );

        expect(callbackShortcuts.bindings, isNotEmpty);
        expect(callbackShortcuts.bindings.length, equals(4));
      });

      testWidgets('cut and paste operations trigger onChanged callback',
          (tester) async {
        var changeCount = 0;
        var lastValue = '';

        controller
          ..text = 'Initial Text'
          ..selection = const TextSelection(
              baseOffset: 0, extentOffset: 7); // Select "Initial"

        await tester.pumpWidget(
          buildTestWidget(
            child: CopyableTextField(
              controller: controller,
              onChanged: (value) {
                changeCount++;
                lastValue = value;
              },
              decoration: const InputDecoration(),
            ),
          ),
        );

        // Mock clipboard for cut operation
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.setData') {
              return null; // Simulate successful clipboard operation
            } else if (methodCall.method == 'Clipboard.getData') {
              return <String, dynamic>{'text': 'Pasted'};
            }
            return null;
          },
        );

        // Get the cut callback from shortcuts
        final callbackShortcuts = tester.widget<CallbackShortcuts>(
          find.byType(CallbackShortcuts),
        );

        final cutShortcut = callbackShortcuts.bindings.keys.firstWhere((s) =>
            s is SingleActivator &&
            s.trigger == LogicalKeyboardKey.keyX &&
            s.meta);

        final cutCallback = callbackShortcuts.bindings[cutShortcut]!;

        // Execute cut operation
        cutCallback();
        await tester.pump();

        // Verify onChanged was called for cut
        expect(changeCount, equals(1));
        expect(lastValue, equals(' Text')); // "Initial" should be cut

        // Reset for paste test
        changeCount = 0;

        final pasteShortcut = callbackShortcuts.bindings.keys.firstWhere((s) =>
            s is SingleActivator &&
            s.trigger == LogicalKeyboardKey.keyV &&
            s.meta);

        final pasteCallback = callbackShortcuts.bindings[pasteShortcut]!;

        // Execute paste operation (handle async callback)
        if (pasteCallback is Future<void> Function()) {
          await pasteCallback();
        } else {
          pasteCallback();
        }
        await tester.pump();

        // Verify onChanged was called for paste
        expect(changeCount, equals(1));
        expect(lastValue, contains('Pasted'));

        // Cleanup
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
    });

    group('Edge Cases and Error Handling', () {
      testWidgets('handles very long text input', (tester) async {
        final longText = 'A' * 10000; // 10k characters
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

        await tester.enterText(find.byType(TextField), longText);
        expect(controller.text, equals(longText));
        expect(changedValue, equals(longText));
      });

      testWidgets('handles unicode and special characters', (tester) async {
        const unicodeText = r'🎉 Hello 世界 مرحبا 🌍 @#$%^&*()';
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

        await tester.enterText(find.byType(TextField), unicodeText);
        expect(controller.text, equals(unicodeText));
        expect(changedValue, equals(unicodeText));
      });

      testWidgets('handles rapid text changes', (tester) async {
        var changeCount = 0;

        await tester.pumpWidget(
          buildTestWidget(
            child: CopyableTextField(
              controller: controller,
              onChanged: (_) => changeCount++,
              decoration: const InputDecoration(),
            ),
          ),
        );

        // Rapidly change text multiple times
        for (var i = 0; i < 100; i++) {
          await tester.enterText(find.byType(TextField), 'Text $i');
        }

        expect(changeCount, equals(100));
        expect(controller.text, equals('Text 99'));
      });

      testWidgets('handles widget rebuild during text editing', (tester) async {
        var changedValue = '';

        Widget buildCopyableTextField(String key) {
          return buildTestWidget(
            child: CopyableTextField(
              key: ValueKey(key),
              controller: controller,
              onChanged: (value) => changedValue = value,
              decoration: const InputDecoration(),
            ),
          );
        }

        await tester.pumpWidget(buildCopyableTextField('first'));

        await tester.enterText(find.byType(TextField), 'Initial Text');
        expect(controller.text, equals('Initial Text'));
        expect(changedValue, equals('Initial Text'));

        // Rebuild widget with new key
        await tester.pumpWidget(buildCopyableTextField('second'));

        // Text should persist through rebuild
        expect(controller.text, equals('Initial Text'));

        // Continue editing after rebuild
        await tester.enterText(find.byType(TextField), 'Updated Text');
        expect(controller.text, equals('Updated Text'));
        expect(changedValue, equals('Updated Text'));
      });

      testWidgets('handles obscured text correctly', (tester) async {
        controller.text = 'secret123';

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
        expect(controller.text,
            equals('secret123')); // Text is still accessible in controller
      });
    });
  });
}
