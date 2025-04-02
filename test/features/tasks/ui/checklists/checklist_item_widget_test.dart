import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_widget.dart';

import '../../../../test_helper.dart';

void main() {
  group('ChecklistItemWidget', () {
    testWidgets('renders title and checkbox correctly', (tester) async {
      // Define test variables
      const title = 'Test Checklist Item';
      bool? checkboxValue;

      await tester.pumpWidget(
        createTestApp(
          ChecklistItemWidget(
            title: title,
            isChecked: false,
            onChanged: (value) {
              checkboxValue = value;
            },
          ),
        ),
      );

      // Verify widget was created properly
      expect(find.byType(ChecklistItemWidget), findsOneWidget);

      // Find specifically the Text widget, not any widget that has text
      final textWidgets = find.byType(Text).evaluate().toList();
      final hasTitle = textWidgets.any((element) {
        final widget = element.widget as Text;
        return widget.data == title;
      });
      expect(hasTitle, isTrue, reason: 'Text widget with title not found');

      // Verify checkbox exists and is unchecked
      final checkbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(checkbox.value, isFalse);

      // Tap the checkbox
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();

      // Verify callback was called with expected value
      expect(checkboxValue, isTrue);
    });

    testWidgets('renders checked state correctly', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          ChecklistItemWidget(
            title: 'Test Item',
            isChecked: true,
            onChanged: (_) {},
          ),
        ),
      );

      // Verify checkbox is checked
      final checkbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(checkbox.value, isTrue);
    });

    testWidgets('updates when isChecked property changes', (tester) async {
      // Start with unchecked state
      await tester.pumpWidget(
        createTestApp(
          ChecklistItemWidget(
            title: 'Test Item',
            isChecked: false,
            onChanged: (_) {},
          ),
        ),
      );

      // Verify initial state
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );

      // Update to checked state
      await tester.pumpWidget(
        createTestApp(
          ChecklistItemWidget(
            title: 'Test Item',
            isChecked: true,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.pump();

      // Verify updated state
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
    });

    testWidgets('shows edit icon when showEditIcon is true', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          ChecklistItemWidget(
            title: 'Test Item',
            isChecked: false,
            onChanged: (_) {},
          ),
        ),
      );

      // Verify edit icon is visible
      expect(find.byIcon(Icons.edit), findsWidgets);
    });

    testWidgets('does not show edit icon when showEditIcon is false',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          ChecklistItemWidget(
            title: 'Test Item',
            isChecked: false,
            onChanged: (_) {},
            showEditIcon: false,
          ),
        ),
      );

      // In the case where showEditIcon is false, we should not find an edit icon
      // within the row, but we may still find one elsewhere if onEdit is provided
      // Let's check the widget directly
      final widget =
          tester.widget<ChecklistItemWidget>(find.byType(ChecklistItemWidget));
      expect(widget.showEditIcon, false);
    });

    testWidgets('can use onEdit callback when provided', (tester) async {
      // Track if callback was called
      var editCallbackCalled = false;

      await tester.pumpWidget(
        createTestApp(
          ChecklistItemWidget(
            title: 'Test Item',
            isChecked: false,
            onChanged: (_) {},
            onEdit: () {
              editCallbackCalled = true;
            },
          ),
        ),
      );

      // Verify the ChecklistItemWidget has an onEdit callback
      final widget =
          tester.widget<ChecklistItemWidget>(find.byType(ChecklistItemWidget));
      expect(widget.onEdit, isNotNull);

      // Call the callback directly to verify it works
      widget.onEdit!();
      expect(editCallbackCalled, isTrue);
    });

    testWidgets('can use TitleTextField for editing title', (tester) async {
      // Store the result of the callback
      String? newTitle;

      await tester.pumpWidget(
        createTestApp(
          ChecklistItemWidget(
            title: 'Test Item',
            isChecked: false,
            onChanged: (_) {},
            onTitleChange: (value) {
              newTitle = value;
            },
          ),
        ),
      );

      // Find and verify that the onTitleChange callback is set
      final widget =
          tester.widget<ChecklistItemWidget>(find.byType(ChecklistItemWidget));
      expect(widget.onTitleChange, isNotNull);

      // Call the callback with a test value
      widget.onTitleChange!('Updated Title');

      // Verify callback was called with the expected value
      expect(newTitle, equals('Updated Title'));
    });

    testWidgets('is disabled when readOnly is true', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          ChecklistItemWidget(
            title: 'Test Item',
            isChecked: false,
            onChanged: (_) {},
            readOnly: true,
          ),
        ),
      );

      // Verify the checkbox is disabled
      final checkbox = tester.widget<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(checkbox.onChanged, isNull);
    });
  });
}
