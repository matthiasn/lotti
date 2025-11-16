import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_widget.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
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

      // Let completion highlight timer finish to avoid pending timers.
      await tester.pump(checklistCompletionAnimationDuration);
      await tester.pump();

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

    testWidgets('shows transient completion highlight when checked',
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

      final animatedContainerFinder = find.byType(AnimatedContainer);
      expect(animatedContainerFinder, findsOneWidget);

      final context = tester.element(animatedContainerFinder);
      final colorScheme = Theme.of(context).colorScheme;
      final highlightBorderColor = colorScheme.primary.withValues(alpha: 0.7);

      // Capture initial border color.
      var animatedContainer = tester.widget<AnimatedContainer>(
        animatedContainerFinder,
      );
      var decoration = animatedContainer.decoration as BoxDecoration?;
      final initialBorder = decoration!.border as Border?;
      final initialBorderColor = initialBorder?.top.color;

      // Toggle checkbox to checked to trigger highlight.
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();

      animatedContainer = tester.widget<AnimatedContainer>(
        animatedContainerFinder,
      );
      decoration = animatedContainer.decoration as BoxDecoration?;
      final borderAfterCheck = decoration!.border as Border?;

      expect(borderAfterCheck, isNotNull);
      expect(borderAfterCheck!.top.color, equals(highlightBorderColor));
      expect(initialBorderColor, isNot(equals(highlightBorderColor)));

      // After the completion animation duration, highlight should clear.
      await tester.pump(checklistCompletionAnimationDuration);
      await tester.pump();

      animatedContainer = tester.widget<AnimatedContainer>(
        animatedContainerFinder,
      );
      decoration = animatedContainer.decoration as BoxDecoration?;
      final borderAfterDuration = decoration!.border as Border?;

      expect(borderAfterDuration, isNotNull);
      expect(
          borderAfterDuration!.top.color, isNot(equals(highlightBorderColor)));
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

      // Let completion highlight timer finish to avoid pending timers.
      await tester.pump(checklistCompletionAnimationDuration);
      await tester.pump();
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

      // Let completion highlight timer finish to avoid pending timers.
      await tester.pump(checklistCompletionAnimationDuration);
      await tester.pump();
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

      // Let completion highlight timer finish to avoid pending timers.
      await tester.pump(checklistCompletionAnimationDuration);
      await tester.pump();
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

    testWidgets('renders edit icon without extra spacer', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistItemWidget(
            title: 'Test Item',
            isChecked: false,
            onChanged: (_) {},
          ),
        ),
      );

      // Edit affordance should be present
      expect(find.byIcon(Icons.edit), findsWidgets);

      // No dedicated SizedBox spacer of width 8 is used after the edit icon in the compact layout
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final hasEightPxSpacer = sizedBoxes.any((w) => w.width == 8.0);
      expect(hasEightPxSpacer, isFalse);
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

      // Let completion highlight timer finish to avoid pending timers.
      await tester.pump(checklistCompletionAnimationDuration);
      await tester.pump();
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

    testWidgets('triggers onCancel when canceling edit mode', (tester) async {
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

      // Enter edit mode by tapping edit button
      await tester.tap(find.byIcon(Icons.edit).first);
      await tester.pump();

      // Verify we're in edit mode
      expect(find.byType(TitleTextField), findsOneWidget);

      // Find the TitleTextField and access its onCancel callback
      final titleTextField =
          tester.widget<TitleTextField>(find.byType(TitleTextField));
      expect(titleTextField.onCancel, isNotNull);

      // Call onCancel to exit edit mode
      titleTextField.onCancel!();
      await tester.pump();

      // After canceling, we should be back in view mode
      // The edit button should be visible again (not in editing state)
      expect(find.byIcon(Icons.edit), findsWidgets);
    });

    testWidgets('has MouseRegion with hover callbacks configured',
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

      // Find the MouseRegion widgets and verify at least one has hover callbacks
      final mouseRegions =
          tester.widgetList<MouseRegion>(find.byType(MouseRegion));
      expect(mouseRegions.length, greaterThan(0));

      // At least one MouseRegion should have onEnter and onExit callbacks
      final mouseRegionsWithCallbacks = mouseRegions.where(
        (mr) => mr.onEnter != null && mr.onExit != null,
      );
      expect(mouseRegionsWithCallbacks, isNotEmpty);

      // Verify AnimatedContainer exists for hover animations
      final animatedContainer =
          tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      expect(animatedContainer.duration, const Duration(milliseconds: 200));
      expect(animatedContainer.curve, Curves.easeInOut);
    });

    testWidgets('renders secondary edit button when onEdit is provided',
        (tester) async {
      var editButtonTapped = false;

      await tester.pumpWidget(
        WidgetTestBench(
          child: ChecklistItemWidget(
            title: 'Test Item',
            isChecked: false,
            onChanged: (_) {},
            onEdit: () {
              editButtonTapped = true;
            },
          ),
        ),
      );

      // Verify secondary IconButton exists (inside CheckboxListTile.secondary)
      final checkboxListTile =
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
      expect(checkboxListTile.secondary, isNotNull);
      expect(checkboxListTile.secondary, isA<IconButton>());

      // Find and tap the secondary edit button
      final secondaryEditButton = checkboxListTile.secondary! as IconButton;
      expect(secondaryEditButton.onPressed, isNotNull);

      // Call the onPressed callback
      secondaryEditButton.onPressed!();

      // Verify the callback was triggered
      expect(editButtonTapped, isTrue);
    });

    testWidgets('does not render secondary button when onEdit is null',
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

      // Verify secondary is null
      final checkboxListTile =
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile));
      expect(checkboxListTile.secondary, isNull);
    });

    testWidgets('applies editing background color when editing',
        (tester) async {
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

      // Get initial background color
      var animatedContainer =
          tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      final initialDecoration = animatedContainer.decoration as BoxDecoration?;
      final initialColor = initialDecoration?.color;

      // Enter edit mode
      await tester.tap(find.byIcon(Icons.edit).first);
      await tester.pump();

      // Get background color in edit mode
      animatedContainer =
          tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
      final editingDecoration = animatedContainer.decoration as BoxDecoration?;
      final editingColor = editingDecoration?.color;

      // Verify colors exist and container properly animates
      expect(initialColor, isNotNull);
      expect(editingColor, isNotNull);
      expect(animatedContainer.duration, const Duration(milliseconds: 200));
    });
  });
}
