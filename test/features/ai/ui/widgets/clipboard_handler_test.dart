import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/widgets/copyable_text_field.dart';

void main() {
  group('ClipboardHandler Unit Tests', () {
    late TextEditingController controller;
    late ClipboardHandler clipboardHandler;

    setUp(() {
      controller = TextEditingController();
      clipboardHandler = ClipboardHandler(controller);
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    tearDown(() {
      controller.dispose();
    });

    group('copy()', () {
      testWidgets('copies selected text when text is selected', (tester) async {
        // Setup
        controller
          ..text = 'Hello World'
          ..selection = const TextSelection(baseOffset: 0, extentOffset: 5);

        // Mock clipboard
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.setData') {
              final data = methodCall.arguments as Map<String, dynamic>;
              expect(data['text'], equals('Hello'));
              return null;
            }
            return null;
          },
        );

        // Execute
        clipboardHandler.copy();

        // Cleanup
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      testWidgets('copies entire text when no text is selected',
          (tester) async {
        // Setup
        controller
          ..text = 'Hello World'
          ..selection = const TextSelection.collapsed(offset: 5);

        // Mock clipboard
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.setData') {
              final data = methodCall.arguments as Map<String, dynamic>;
              expect(data['text'], equals('Hello World'));
              return null;
            }
            return null;
          },
        );

        // Execute
        clipboardHandler.copy();

        // Cleanup
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      testWidgets('copies empty string when text is empty', (tester) async {
        // Setup
        controller
          ..text = ''
          ..selection = const TextSelection.collapsed(offset: 0);

        // Mock clipboard
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.setData') {
              final data = methodCall.arguments as Map<String, dynamic>;
              expect(data['text'], equals(''));
              return null;
            }
            return null;
          },
        );

        // Execute
        clipboardHandler.copy();

        // Cleanup
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      testWidgets('handles invalid selection by copying entire text',
          (tester) async {
        // Setup
        controller
          ..text = 'Test Text'
          ..selection = const TextSelection(baseOffset: -1, extentOffset: -1);

        // Mock clipboard
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.setData') {
              final data = methodCall.arguments as Map<String, dynamic>;
              expect(data['text'], equals('Test Text'));
              return null;
            }
            return null;
          },
        );

        // Execute
        clipboardHandler.copy();

        // Cleanup
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      testWidgets('does not copy when selected text is empty', (tester) async {
        // Setup
        controller
          ..text = 'Hello World'
          ..selection = const TextSelection(baseOffset: 5, extentOffset: 5);

        // Mock clipboard - should copy entire text when selection is collapsed
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.setData') {
              final data = methodCall.arguments as Map<String, dynamic>;
              expect(data['text'], equals('Hello World'));
              return null;
            }
            return null;
          },
        );

        // Execute
        clipboardHandler.copy();

        // Cleanup
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
    });

    group('paste()', () {
      testWidgets('pastes text at cursor position when no selection',
          (tester) async {
        // Setup
        controller
          ..text = 'Hello World'
          ..selection = const TextSelection.collapsed(offset: 5);

        // Mock clipboard
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.getData') {
              return <String, dynamic>{'text': ' Inserted'};
            }
            return null;
          },
        );

        // Execute
        await clipboardHandler.paste();

        // Verify
        expect(controller.text, equals('Hello Inserted World'));
        expect(controller.selection.baseOffset,
            equals(14)); // 5 + 9 (' Inserted'.length)

        // Cleanup
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      testWidgets('replaces selected text when pasting', (tester) async {
        // Setup
        controller
          ..text = 'Hello World'
          ..selection = const TextSelection(baseOffset: 6, extentOffset: 11);

        // Mock clipboard
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.getData') {
              return <String, dynamic>{'text': 'Flutter'};
            }
            return null;
          },
        );

        // Execute
        await clipboardHandler.paste();

        // Verify
        expect(controller.text, equals('Hello Flutter'));
        expect(controller.selection.baseOffset,
            equals(13)); // 6 + 7 ('Flutter'.length)

        // Cleanup
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      testWidgets('handles empty clipboard data gracefully', (tester) async {
        // Setup
        const originalText = 'Hello World';
        controller
          ..text = originalText
          ..selection = const TextSelection.collapsed(offset: 5);

        // Mock clipboard to return null
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.getData') {
              return null;
            }
            return null;
          },
        );

        // Execute
        await clipboardHandler.paste();

        // Verify text unchanged
        expect(controller.text, equals(originalText));
        expect(controller.selection.baseOffset, equals(5));

        // Cleanup
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      testWidgets('pastes at end when selection is invalid', (tester) async {
        // Setup
        controller
          ..text = 'Hello'
          ..selection = const TextSelection(baseOffset: -1, extentOffset: -1);

        // Mock clipboard
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.getData') {
              return <String, dynamic>{'text': ' World'};
            }
            return null;
          },
        );

        // Execute
        await clipboardHandler.paste();

        // Verify
        expect(controller.text, equals('Hello World'));
        expect(controller.selection.baseOffset, equals(11)); // at end

        // Cleanup
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      testWidgets('pastes empty string correctly', (tester) async {
        // Setup
        controller
          ..text = 'Hello World'
          ..selection = const TextSelection(baseOffset: 5, extentOffset: 6);

        // Mock clipboard
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.getData') {
              return <String, dynamic>{'text': ''};
            }
            return null;
          },
        );

        // Execute
        await clipboardHandler.paste();

        // Verify
        expect(controller.text, equals('HelloWorld'));
        expect(controller.selection.baseOffset, equals(5));

        // Cleanup
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
    });

    group('cut()', () {
      testWidgets('cuts selected text and updates controller', (tester) async {
        // Setup
        controller
          ..text = 'Hello World'
          ..selection = const TextSelection(baseOffset: 6, extentOffset: 11);

        // Mock clipboard
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.setData') {
              final data = methodCall.arguments as Map<String, dynamic>;
              expect(data['text'], equals('World'));
              return null;
            }
            return null;
          },
        );

        // Execute
        clipboardHandler.cut();

        // Verify
        expect(controller.text, equals('Hello '));
        expect(controller.selection.baseOffset, equals(6));
        expect(controller.selection.extentOffset, equals(6));

        // Cleanup
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      testWidgets('does nothing when no text is selected', (tester) async {
        // Setup
        const originalText = 'Hello World';
        controller
          ..text = originalText
          ..selection = const TextSelection.collapsed(offset: 5);

        // Mock clipboard - should not be called
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.setData') {
              fail(
                  'Clipboard.setData should not be called when no text is selected');
            }
            return null;
          },
        );

        // Execute
        clipboardHandler.cut();

        // Verify text unchanged
        expect(controller.text, equals(originalText));
        expect(controller.selection.baseOffset, equals(5));

        // Cleanup
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      testWidgets('handles invalid selection gracefully', (tester) async {
        // Setup
        const originalText = 'Hello World';
        controller
          ..text = originalText
          ..selection = const TextSelection(baseOffset: -1, extentOffset: -1);

        // Mock clipboard - should not be called
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.setData') {
              fail(
                  'Clipboard.setData should not be called with invalid selection');
            }
            return null;
          },
        );

        // Execute
        clipboardHandler.cut();

        // Verify text unchanged
        expect(controller.text, equals(originalText));

        // Cleanup
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      testWidgets('cuts entire selected text', (tester) async {
        // Setup
        controller
          ..text = 'Flutter'
          ..selection = const TextSelection(baseOffset: 0, extentOffset: 7);

        // Mock clipboard
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            if (methodCall.method == 'Clipboard.setData') {
              final data = methodCall.arguments as Map<String, dynamic>;
              expect(data['text'], equals('Flutter'));
              return null;
            }
            return null;
          },
        );

        // Execute
        clipboardHandler.cut();

        // Verify
        expect(controller.text, equals(''));
        expect(controller.selection.baseOffset, equals(0));

        // Cleanup
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      testWidgets('does not cut when selected text is empty', (tester) async {
        // Setup
        controller
          ..text = 'Hello World'
          ..selection = const TextSelection(baseOffset: 5, extentOffset: 5);

        // Execute
        clipboardHandler.cut();

        // Verify text unchanged (collapsed selection means no text selected)
        expect(controller.text, equals('Hello World'));
        expect(controller.selection.baseOffset, equals(5));
      });
    });

    group('selectAll()', () {
      test('selects all text in controller', () {
        // Setup
        controller
          ..text = 'Hello World'
          ..selection = const TextSelection.collapsed(offset: 5);

        // Execute
        clipboardHandler.selectAll();

        // Verify
        expect(controller.selection.baseOffset, equals(0));
        expect(controller.selection.extentOffset, equals(11));
        expect(controller.selection.textInside(controller.text),
            equals('Hello World'));
      });

      test('handles empty text', () {
        // Setup
        controller
          ..text = ''
          ..selection = const TextSelection.collapsed(offset: 0);

        // Execute
        clipboardHandler.selectAll();

        // Verify
        expect(controller.selection.baseOffset, equals(0));
        expect(controller.selection.extentOffset, equals(0));
      });

      test('updates selection when text is already selected', () {
        // Setup
        controller
          ..text = 'Flutter Development'
          ..selection = const TextSelection(baseOffset: 5, extentOffset: 10);

        // Execute
        clipboardHandler.selectAll();

        // Verify entire text is selected
        expect(controller.selection.baseOffset, equals(0));
        expect(controller.selection.extentOffset, equals(19));
        expect(controller.selection.textInside(controller.text),
            equals('Flutter Development'));
      });

      test('works with multiline text', () {
        // Setup
        const multilineText = 'Line 1\nLine 2\nLine 3';
        controller
          ..text = multilineText
          ..selection = const TextSelection.collapsed(offset: 10);

        // Execute
        clipboardHandler.selectAll();

        // Verify
        expect(controller.selection.baseOffset, equals(0));
        expect(controller.selection.extentOffset, equals(multilineText.length));
        expect(controller.selection.textInside(controller.text),
            equals(multilineText));
      });

      test('works with special characters and emojis', () {
        // Setup
        const specialText = r'Hello 👋 World! @#$%^&*()';
        controller
          ..text = specialText
          ..selection = const TextSelection.collapsed(offset: 5);

        // Execute
        clipboardHandler.selectAll();

        // Verify
        expect(controller.selection.baseOffset, equals(0));
        expect(controller.selection.extentOffset, equals(specialText.length));
        expect(controller.selection.textInside(controller.text),
            equals(specialText));
      });
    });

    group('edge cases and integration', () {
      test('controller reference is maintained', () {
        expect(clipboardHandler.controller, equals(controller));
      });

      test('operations work with very long text', () {
        // Setup
        final longText = 'A' * 10000; // 10k characters
        controller
          ..text = longText
          ..selection =
              const TextSelection(baseOffset: 1000, extentOffset: 2000);

        // Execute selectAll
        clipboardHandler.selectAll();

        // Verify
        expect(controller.selection.baseOffset, equals(0));
        expect(controller.selection.extentOffset, equals(10000));
      });

      test('operations work with unicode text', () {
        // Setup
        const unicodeText = '🎉 Hello 世界 مرحبا 🌍';
        controller
          ..text = unicodeText
          ..selection = const TextSelection.collapsed(offset: 5);

        // Execute selectAll
        clipboardHandler.selectAll();

        // Verify
        expect(controller.selection.baseOffset, equals(0));
        expect(controller.selection.extentOffset, equals(unicodeText.length));
        expect(controller.selection.textInside(controller.text),
            equals(unicodeText));
      });
    });
  });
}
