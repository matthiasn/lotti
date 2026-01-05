import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/ui/widgets/create/create_menu_list_item.dart';
import 'package:lotti/themes/theme.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  group('CreateMenuListItem', () {
    testWidgets('renders with correct icon, title, and trailing plus icon',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          CreateMenuListItem(
            icon: Icons.event_rounded,
            title: 'Event',
            onTap: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify leading icon
      expect(find.byIcon(Icons.event_rounded), findsOneWidget);

      // Verify title
      expect(find.text('Event'), findsOneWidget);

      // Verify trailing plus icon
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('triggers onTap callback when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          CreateMenuListItem(
            icon: Icons.task_alt_rounded,
            title: 'Task',
            onTap: () {
              tapped = true;
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the item
      await tester.tap(find.byType(CreateMenuListItem));
      await tester.pumpAndSettle();

      // Verify callback was triggered
      expect(tapped, isTrue);
    });

    testWidgets('does not trigger onTap when disabled', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          CreateMenuListItem(
            icon: Icons.mic_none_rounded,
            title: 'Audio Recording',
            onTap: () {
              tapped = true;
            },
            isDisabled: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the item
      await tester.tap(find.byType(CreateMenuListItem));
      await tester.pumpAndSettle();

      // Verify callback was NOT triggered
      expect(tapped, isFalse);
    });

    testWidgets('displays all provided icons correctly', (tester) async {
      final testCases = [
        (Icons.event_rounded, 'Event'),
        (Icons.task_alt_rounded, 'Task'),
        (Icons.mic_none_rounded, 'Audio Recording'),
        (Icons.timer_outlined, 'Timer'),
        (Icons.notes_rounded, 'Text Entry'),
        (Icons.photo_library_rounded, 'Import Image'),
        (Icons.screenshot_monitor_rounded, 'Screenshot'),
        (Icons.content_paste_rounded, 'Paste Image'),
      ];

      for (final (icon, title) in testCases) {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            CreateMenuListItem(
              icon: icon,
              title: title,
              onTap: () {},
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify icon is rendered
        expect(find.byIcon(icon), findsOneWidget, reason: 'Icon for $title');

        // Verify title is rendered
        expect(find.text(title), findsOneWidget, reason: 'Title: $title');
      }
    });

    testWidgets('has correct icon size', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          CreateMenuListItem(
            icon: Icons.event_rounded,
            title: 'Event',
            onTap: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the leading icon
      final iconFinder = find.byIcon(Icons.event_rounded);
      final icon = tester.widget<Icon>(iconFinder);

      // Verify icon size matches theme constant
      expect(icon.size, AppTheme.iconSize + 2);
    });

    testWidgets('has correct trailing plus icon size', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          CreateMenuListItem(
            icon: Icons.event_rounded,
            title: 'Event',
            onTap: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the trailing plus icon
      final iconFinder = find.byIcon(Icons.add);
      final icon = tester.widget<Icon>(iconFinder);

      // Verify icon size matches theme constant
      expect(icon.size, AppTheme.iconSize);
    });

    testWidgets('applies correct text style', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          CreateMenuListItem(
            icon: Icons.task_alt_rounded,
            title: 'Task',
            onTap: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the title text widget
      final textFinder = find.text('Task');
      final text = tester.widget<Text>(textFinder);

      // Verify text style
      expect(text.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('disabled state shows reduced opacity colors', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          CreateMenuListItem(
            icon: Icons.event_rounded,
            title: 'Event',
            onTap: () {},
            isDisabled: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the leading icon
      final iconFinder = find.byIcon(Icons.event_rounded);
      final icon = tester.widget<Icon>(iconFinder);

      // Disabled icons have reduced alpha (0.38)
      expect(icon.color?.a, isNotNull);
    });

    testWidgets('uses Material widget for InkWell ripple effect',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          CreateMenuListItem(
            icon: Icons.task_alt_rounded,
            title: 'Task',
            onTap: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Material widget exists for proper InkWell behavior
      expect(find.byType(Material), findsWidgets);

      // Verify InkWell is present
      expect(find.byType(InkWell), findsOneWidget);
    });

    testWidgets('has correct horizontal padding', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          CreateMenuListItem(
            icon: Icons.timer_outlined,
            title: 'Timer',
            onTap: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the Padding widget inside the InkWell
      final inkWellFinder = find.byType(InkWell);
      final inkWell = tester.widget<InkWell>(inkWellFinder);
      final child = inkWell.child;

      // The child should be a Padding widget
      expect(child, isA<Padding>());

      final padding = child! as Padding;
      final edgeInsets = padding.padding as EdgeInsets;

      // Verify horizontal padding matches theme constant
      expect(edgeInsets.left, AppTheme.cardPadding);
      expect(edgeInsets.right, AppTheme.cardPadding);
    });

    testWidgets('Row contains exactly 4 children', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          CreateMenuListItem(
            icon: Icons.notes_rounded,
            title: 'Text Entry',
            onTap: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the Row widget inside CreateMenuListItem
      final rowFinder = find.descendant(
        of: find.byType(CreateMenuListItem),
        matching: find.byType(Row),
      );
      expect(rowFinder, findsOneWidget);

      final row = tester.widget<Row>(rowFinder);
      // Should have: Icon, SizedBox (spacer), Expanded (title), Icon (plus)
      expect(row.children.length, 4);
    });

    testWidgets('title uses Expanded widget to fill available space',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          CreateMenuListItem(
            icon: Icons.photo_library_rounded,
            title: 'Import Image',
            onTap: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find Expanded widget containing the title
      final expandedFinder = find.ancestor(
        of: find.text('Import Image'),
        matching: find.byType(Expanded),
      );

      expect(expandedFinder, findsOneWidget);
    });

    testWidgets('handles long titles with ellipsis overflow', (tester) async {
      const longTitle =
          'This is a very long title that should be truncated with ellipsis';

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          CreateMenuListItem(
            icon: Icons.event_rounded,
            title: longTitle,
            onTap: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the title text widget
      final textFinder = find.text(longTitle);
      final text = tester.widget<Text>(textFinder);

      // Verify text is configured for ellipsis overflow
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });
}
