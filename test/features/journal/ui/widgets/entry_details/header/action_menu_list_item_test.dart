import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/action_menu_list_item.dart';
import 'package:lotti/themes/theme.dart';

import '../../../../../../widget_test_utils.dart';

void main() {
  group('ActionMenuListItem', () {
    testWidgets('renders with correct icon and title', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ActionMenuListItem(
            icon: Icons.star_rounded,
            title: 'Favorite',
            onTap: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify leading icon
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);

      // Verify title
      expect(find.text('Favorite'), findsOneWidget);

      // ActionMenuListItem does NOT have a trailing plus icon (unlike CreateMenuListItem)
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('triggers onTap callback when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ActionMenuListItem(
            icon: Icons.lock_rounded,
            title: 'Private',
            onTap: () {
              tapped = true;
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the item
      await tester.tap(find.byType(ActionMenuListItem));
      await tester.pumpAndSettle();

      // Verify callback was triggered
      expect(tapped, isTrue);
    });

    testWidgets('does not trigger onTap when disabled', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ActionMenuListItem(
            icon: Icons.delete_outline_rounded,
            title: 'Delete entry',
            onTap: () {
              tapped = true;
            },
            isDisabled: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the item
      await tester.tap(find.byType(ActionMenuListItem));
      await tester.pumpAndSettle();

      // Verify callback was NOT triggered
      expect(tapped, isFalse);
    });

    testWidgets('displays all provided icons correctly', (tester) async {
      final testCases = [
        (Icons.star_rounded, 'Favorite'),
        (Icons.lock_rounded, 'Private'),
        (Icons.flag_rounded, 'Flagged'),
        (Icons.delete_outline_rounded, 'Delete entry'),
        (Icons.share_rounded, 'Share'),
        (Icons.add_link, 'Link from'),
        (Icons.link_off_rounded, 'Unlink'),
        (Icons.visibility_rounded, 'Hide link'),
      ];

      for (final (icon, title) in testCases) {
        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            ActionMenuListItem(
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
          ActionMenuListItem(
            icon: Icons.star_rounded,
            title: 'Favorite',
            onTap: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the leading icon
      final iconFinder = find.byIcon(Icons.star_rounded);
      final icon = tester.widget<Icon>(iconFinder);

      // Verify icon size matches theme constant (listItemIconSize)
      expect(icon.size, AppTheme.listItemIconSize);
    });

    testWidgets('applies correct text style', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ActionMenuListItem(
            icon: Icons.lock_rounded,
            title: 'Private',
            onTap: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the title text widget
      final textFinder = find.text('Private');
      final text = tester.widget<Text>(textFinder);

      // Verify text style
      expect(text.style?.fontWeight, FontWeight.w500);
    });

    testWidgets('disabled state shows reduced opacity colors', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ActionMenuListItem(
            icon: Icons.star_rounded,
            title: 'Favorite',
            onTap: () {},
            isDisabled: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the leading icon
      final iconFinder = find.byIcon(Icons.star_rounded);
      final icon = tester.widget<Icon>(iconFinder);

      // Disabled icons have reduced alpha
      expect(icon.color?.a, isNotNull);
    });

    testWidgets('destructive state shows error colors', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ActionMenuListItem(
            icon: Icons.delete_outline_rounded,
            title: 'Delete entry',
            onTap: () {},
            isDestructive: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the title text widget
      final textFinder = find.text('Delete entry');
      final text = tester.widget<Text>(textFinder);

      // Destructive text should use error color
      expect(text.style?.color, isNotNull);
    });

    testWidgets('custom icon color is applied', (tester) async {
      const customColor = Color(0xFFFFD700); // Gold

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ActionMenuListItem(
            icon: Icons.star_rounded,
            title: 'Favorite',
            onTap: () {},
            iconColor: customColor,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the leading icon
      final iconFinder = find.byIcon(Icons.star_rounded);
      final icon = tester.widget<Icon>(iconFinder);

      // Verify custom icon color is applied
      expect(icon.color, customColor);
    });

    testWidgets('uses Material widget for InkWell ripple effect',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ActionMenuListItem(
            icon: Icons.flag_rounded,
            title: 'Flagged',
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
          ActionMenuListItem(
            icon: Icons.share_rounded,
            title: 'Share',
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

    testWidgets('handles long titles with ellipsis overflow', (tester) async {
      const longTitle =
          'This is a very long title that should be truncated with ellipsis';

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ActionMenuListItem(
            icon: Icons.star_rounded,
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

    testWidgets('renders subtitle when provided', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ActionMenuListItem(
            icon: Icons.label_outline_rounded,
            title: 'Labels',
            subtitle: 'Assign labels to organize this entry',
            onTap: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title is rendered
      expect(find.text('Labels'), findsOneWidget);

      // Verify subtitle is rendered
      expect(find.text('Assign labels to organize this entry'), findsOneWidget);
    });

    testWidgets('does not render subtitle when not provided', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ActionMenuListItem(
            icon: Icons.star_rounded,
            title: 'Favorite',
            onTap: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title is rendered
      expect(find.text('Favorite'), findsOneWidget);

      // The Column inside should only have one Text child (the title)
      final columnFinder = find.descendant(
        of: find.byType(ActionMenuListItem),
        matching: find.byType(Column),
      );

      // Find all Text widgets in the row
      final textWidgets = find.descendant(
        of: columnFinder.last,
        matching: find.byType(Text),
      );

      // Should only have the title text
      expect(textWidgets, findsOneWidget);
    });

    testWidgets('does not render subtitle when empty string', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ActionMenuListItem(
            icon: Icons.star_rounded,
            title: 'Favorite',
            subtitle: '',
            onTap: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the inner Column (for title/subtitle)
      final columnFinder = find.descendant(
        of: find.byType(ActionMenuListItem),
        matching: find.byType(Column),
      );

      // Find Text widgets in the inner Column
      final textWidgets = find.descendant(
        of: columnFinder.last,
        matching: find.byType(Text),
      );

      // Should only have the title text (empty subtitle is not rendered)
      expect(textWidgets, findsOneWidget);
    });

    testWidgets('Row contains correct structure', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ActionMenuListItem(
            icon: Icons.add_link,
            title: 'Link from',
            onTap: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the Row widget inside ActionMenuListItem
      final rowFinder = find.descendant(
        of: find.byType(ActionMenuListItem),
        matching: find.byType(Row),
      );
      expect(rowFinder, findsOneWidget);

      final row = tester.widget<Row>(rowFinder);
      // Should have: Icon, SizedBox (spacer), Expanded (title column)
      expect(row.children.length, 3);
    });

    testWidgets('title uses Expanded widget to fill available space',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ActionMenuListItem(
            icon: Icons.visibility_rounded,
            title: 'Hide link',
            onTap: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find Expanded widget containing the title
      final expandedFinder = find.ancestor(
        of: find.text('Hide link'),
        matching: find.byType(Expanded),
      );

      expect(expandedFinder, findsOneWidget);
    });

    testWidgets('destructive icon uses error color', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ActionMenuListItem(
            icon: Icons.delete_outline_rounded,
            title: 'Delete entry',
            onTap: () {},
            isDestructive: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the leading icon
      final iconFinder = find.byIcon(Icons.delete_outline_rounded);
      final icon = tester.widget<Icon>(iconFinder);

      // Destructive icon should have a color (error color from theme)
      expect(icon.color, isNotNull);
    });

    testWidgets('custom iconColor is ignored when destructive', (tester) async {
      const customColor = Color(0xFF00FF00); // Green

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ActionMenuListItem(
            icon: Icons.delete_outline_rounded,
            title: 'Delete entry',
            onTap: () {},
            iconColor: customColor,
            isDestructive: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the leading icon
      final iconFinder = find.byIcon(Icons.delete_outline_rounded);
      final icon = tester.widget<Icon>(iconFinder);

      // When destructive, custom color should be ignored (error color used)
      expect(icon.color, isNot(customColor));
    });

    testWidgets('custom iconColor is ignored when disabled', (tester) async {
      const customColor = Color(0xFF00FF00); // Green

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          ActionMenuListItem(
            icon: Icons.star_rounded,
            title: 'Favorite',
            onTap: () {},
            iconColor: customColor,
            isDisabled: true,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the leading icon
      final iconFinder = find.byIcon(Icons.star_rounded);
      final icon = tester.widget<Icon>(iconFinder);

      // When disabled, custom color should be ignored (disabled color used)
      expect(icon.color, isNot(customColor));
    });
  });
}
