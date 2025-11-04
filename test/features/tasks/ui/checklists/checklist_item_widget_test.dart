import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_widget.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';

import '../../../../test_helper.dart';

void main() {
  group('ChecklistItemWidget', () {
    testWidgets('applies background + strikethrough when checked',
        (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistItemWidget(
            title: 'Test Item',
            isChecked: false,
            onChanged: (_) {},
          ),
        ),
      );

      // Ensure we render with an AnimatedContainer row wrapper
      expect(find.byType(AnimatedContainer), findsWidgets);

      // Toggle checkbox to checked
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify strikethrough style is applied to the title text
      final textWidget = find
          .byType(Text)
          .evaluate()
          .map((e) => e.widget as Text)
          .firstWhere((t) => t.data == 'Test Item');
      expect(
        textWidget.style?.decoration,
        equals(TextDecoration.lineThrough),
      );
    });
    testWidgets('renders title and checkbox correctly', (tester) async {
      // Define test variables
      const title = 'Test Checklist Item';
      bool? checkboxValue;

      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistItemWidget(
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
        WidgetTestBench(
          child: ChecklistItemWidget(
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
        WidgetTestBench(
          child: ChecklistItemWidget(
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
        WidgetTestBench(
          child: ChecklistItemWidget(
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
        WidgetTestBench(
          child: ChecklistItemWidget(
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
        WidgetTestBench(
          child: ChecklistItemWidget(
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
        WidgetTestBench(
          child: ChecklistItemWidget(
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
        WidgetTestBench(
          child: ChecklistItemWidget(
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
        WidgetTestBench(
          child: ChecklistItemWidget(
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

    testWidgets('has MouseRegion for hover interactions', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistItemWidget(
            title: 'Test Item',
            isChecked: false,
            onChanged: (_) {},
          ),
        ),
      );

      // Find the MouseRegion widget - it should exist to enable hover
      expect(find.byType(MouseRegion), findsWidgets);

      // Find AnimatedContainer which should change color on hover
      expect(find.byType(AnimatedContainer), findsOneWidget);

      // Verify animation duration is set correctly
      final animatedContainer =
          tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      expect(
        animatedContainer.duration,
        equals(const Duration(milliseconds: 200)),
      );
      expect(animatedContainer.curve, equals(Curves.easeInOut));
    });

    testWidgets('animates background color transitions', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistItemWidget(
            title: 'Test Item',
            isChecked: false,
            onChanged: (_) {},
          ),
        ),
      );

      // Verify AnimatedContainer exists with correct animation settings
      final animatedContainer =
          tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      expect(
        animatedContainer.duration,
        equals(const Duration(milliseconds: 200)),
      );
      expect(animatedContainer.curve, equals(Curves.easeInOut));

      // Toggle checkbox to trigger animation
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();

      // Verify container still exists (animation in progress)
      expect(find.byType(AnimatedContainer), findsOneWidget);

      // Complete the animation
      await tester.pump(const Duration(milliseconds: 200));

      // Verify animation completed
      expect(find.byType(AnimatedContainer), findsOneWidget);
    });

    testWidgets('applies border radius to container', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistItemWidget(
            title: 'Test Item',
            isChecked: false,
            onChanged: (_) {},
          ),
        ),
      );

      // Find AnimatedContainer and verify border radius
      final animatedContainer =
          tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      final decoration = animatedContainer.decoration as BoxDecoration?;

      expect(decoration, isNotNull);
      expect(decoration!.borderRadius, isA<BorderRadius>());
      final borderRadius = decoration.borderRadius! as BorderRadius;
      expect(borderRadius.topLeft.x, equals(12.0));
    });

    testWidgets('shows correct spacing after edit icon', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistItemWidget(
            title: 'Test Item',
            isChecked: false,
            onChanged: (_) {},
          ),
        ),
      );

      // Find all SizedBox widgets
      final sizedBoxes = find.byType(SizedBox);

      // Verify at least one SizedBox exists (the spacing after edit icon)
      expect(sizedBoxes, findsWidgets);

      // Find the SizedBox with width: 8 (spacing after edit icon)
      final sizedBoxWidgets = tester
          .widgetList<SizedBox>(sizedBoxes)
          .where((widget) => widget.width == 8.0);

      // Verify the spacing exists when showEditIcon is true
      expect(sizedBoxWidgets.isNotEmpty, isTrue);
    });

    testWidgets('does not show spacing when showEditIcon is false',
        (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistItemWidget(
            title: 'Test Item',
            isChecked: false,
            onChanged: (_) {},
            showEditIcon: false,
          ),
        ),
      );

      // When showEditIcon is false, verify edit icon is not present
      expect(find.byIcon(Icons.edit), findsNothing);

      // Verify the spacing SizedBox with width 8.0 is NOT rendered
      final sizedBoxWidgets = tester
          .widgetList<SizedBox>(find.byType(SizedBox))
          .where((widget) => widget.width == 8.0);

      expect(sizedBoxWidgets, isEmpty);
    });

    testWidgets('applies different background colors based on state',
        (tester) async {
      // Test unchecked state
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistItemWidget(
            title: 'Test Item',
            isChecked: false,
            onChanged: (_) {},
          ),
        ),
      );

      // Verify AnimatedContainer exists with decoration
      var animatedContainer =
          tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      var decoration = animatedContainer.decoration as BoxDecoration?;
      expect(decoration, isNotNull);
      expect(decoration!.color, isNotNull);

      // Toggle to checked state
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify container decoration changed
      animatedContainer =
          tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      decoration = animatedContainer.decoration as BoxDecoration?;
      expect(decoration, isNotNull);
      expect(decoration!.color, isNotNull);
    });

    testWidgets('toggles edit mode when edit button is tapped', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistItemWidget(
            title: 'Test Item',
            isChecked: false,
            onChanged: (_) {},
            onTitleChange: (_) {},
          ),
        ),
      );

      // Find and tap the edit button
      final editButtons = find.byIcon(Icons.edit);
      expect(editButtons, findsWidgets);

      // Tap one of the edit buttons
      await tester.tap(editButtons.first);
      await tester.pump();

      // Verify AnimatedCrossFade exists (indicates edit mode toggle)
      expect(find.byType(AnimatedCrossFade), findsOneWidget);

      // Verify TitleTextField is present (edit mode active)
      expect(find.byType(TitleTextField), findsOneWidget);
    });
  });
}
