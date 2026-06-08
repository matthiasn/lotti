import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';

import '../../../test_helper.dart';

void main() {
  group('TitleTextField', () {
    testWidgets('should initialize with initialValue', (tester) async {
      const initialValue = 'Test Title';

      await tester.pumpWidget(
        WidgetTestBench(
          child: TitleTextField(
            initialValue: initialValue,
            onSave: (value) => {},
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, equals(initialValue));
    });

    testWidgets('should update controller when initialValue changes', (
      tester,
    ) async {
      const firstValue = 'First Title';
      const secondValue = 'Updated Title by AI';

      // Create widget with first value
      await tester.pumpWidget(
        WidgetTestBench(
          child: TitleTextField(
            key: const Key('title_field'),
            initialValue: firstValue,
            onSave: (value) => {},
          ),
        ),
      );

      // Verify first value is set
      var textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, equals(firstValue));

      // Update widget with new value (simulating AI setting new title)
      await tester.pumpWidget(
        WidgetTestBench(
          child: TitleTextField(
            key: const Key('title_field'),
            initialValue: secondValue,
            onSave: (value) => {},
          ),
        ),
      );

      // Verify controller was updated with new value
      textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, equals(secondValue));
    });

    testWidgets(
      'should reset to new initialValue on cancel when resetToInitialValue is true',
      (tester) async {
        const initialValue = 'AI Generated Title';
        var cancelCalled = false;

        await tester.pumpWidget(
          WidgetTestBench(
            child: TitleTextField(
              initialValue: initialValue,
              resetToInitialValue: true,
              onSave: (value) => {},
              onCancel: () => cancelCalled = true,
            ),
          ),
        );

        // Type some text to make it dirty
        await tester.enterText(find.byType(TextField), 'Modified Text');
        await tester.pump();

        // Tap cancel button
        await tester.tap(find.byIcon(Icons.cancel_outlined));
        await tester.pump();

        // Verify text was reset to initialValue
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller!.text, equals(initialValue));
        expect(cancelCalled, isTrue);
      },
    );

    testWidgets('should preserve edited value when clicking into field', (
      tester,
    ) async {
      const initialValue = 'AI Generated Title';

      await tester.pumpWidget(
        WidgetTestBench(
          child: TitleTextField(
            initialValue: initialValue,
            resetToInitialValue: true,
            onSave: (value) => {},
          ),
        ),
      );

      // Tap on the text field to focus it
      await tester.tap(find.byType(TextField));
      await tester.pump();

      // Verify the text is still there (this is the bug we fixed)
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller!.text, equals(initialValue));
    });

    testWidgets('should save modified text when save button is pressed', (
      tester,
    ) async {
      const initialValue = 'AI Generated Title';
      const modifiedValue = 'User Modified Title';
      var savedValue = '';

      await tester.pumpWidget(
        WidgetTestBench(
          child: TitleTextField(
            initialValue: initialValue,
            onSave: (value) => savedValue = value ?? '',
          ),
        ),
      );

      // Modify the text
      await tester.enterText(find.byType(TextField), modifiedValue);
      await tester.pump();

      // Tap save button
      await tester.tap(find.byIcon(Icons.check_circle));
      await tester.pump();

      expect(savedValue, equals(modifiedValue));
    });
  });

  group('TitleTextField - Keyboard Shortcuts', () {
    testWidgets('saves on Ctrl+S and keeps focus', (tester) async {
      final focusNode = FocusNode();
      final saved = <String?>[];

      await tester.pumpWidget(
        WidgetTestBench(
          child: Center(
            child: TitleTextField(
              focusNode: focusNode,
              keepFocusOnSave: true,
              clearOnSave: true,
              onSave: saved.add,
            ),
          ),
        ),
      );

      // Focus the field and enter text
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(focusNode.hasFocus, isTrue);
      await tester.enterText(find.byType(TextField), 'foo');

      // Send Ctrl+S (platform-agnostic path)
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();

      expect(saved.length, 1);
      expect(
        focusNode.hasFocus,
        isTrue,
        reason: 'Focus should be retained after save',
      );
    });
  });

  group('TitleTextField - Tap Outside', () {
    testWidgets('calls onTapOutside when not dirty', (tester) async {
      var tappedOutside = false;

      await tester.pumpWidget(
        const WidgetTestBench(
          child: SizedBox.shrink(),
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: Center(
            child: TitleTextField(
              initialValue: '',
              onSave: (_) {},
              onTapOutside: (_) {
                tappedOutside = true;
              },
            ),
          ),
        ),
      );

      // Focus field, but do not change text so _dirty stays false
      await tester.tap(find.byType(TextField));
      await tester.pump();

      // Tap outside area
      await tester.sendEventToBinding(const PointerDownEvent());
      await tester.pump();

      expect(tappedOutside, isTrue);
    });
  });
}
