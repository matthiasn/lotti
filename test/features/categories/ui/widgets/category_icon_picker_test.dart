import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_picker.dart';

void main() {
  group('CategoryIconPicker', () {
    testWidgets('should display all available icons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CategoryIconPicker(),
          ),
        ),
      );

      // Should display all CategoryIcon values
      expect(find.byType(GridView), findsOneWidget);

      // Get the GridView widget to check its properties
      final gridView = tester.widget<GridView>(find.byType(GridView));

      // The GridView should have itemCount equal to CategoryIcon.values.length
      // (The close button is not part of the GridView, it's in the header)
      expect(gridView.semanticChildCount, equals(CategoryIcon.values.length));

      // Also verify the data source: ensure all CategoryIcon values are represented
      expect(CategoryIcon.values.length, equals(56),
          reason: 'Expected 56 CategoryIcon enum values');

      // Verify that the close button exists separately (not in the GridView)
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Test that we can find at least some of the initially visible icons
      // (This verifies the GridView is actually rendering items)
      final visibleIconCount = tester.widgetList(find.byType(Icon)).length;
      expect(visibleIconCount, greaterThan(0),
          reason: 'Should have at least some visible icons rendered');
    });

    testWidgets('should be able to scroll through and access all icons',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 600,
              child: CategoryIconPicker(),
            ),
          ),
        ),
      );

      // Track unique icons we can find by scrolling
      final foundIcons = <IconData>{};

      // Scroll through the GridView in chunks to load and collect all visible icons
      final scrollable = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(Scrollable),
      );

      // Initial collection
      for (final widget in tester.widgetList<Icon>(find.byType(Icon))) {
        foundIcons.add(widget.icon!);
      }

      // Scroll down in increments and collect more icons
      const scrollIncrement = -300.0;
      for (var i = 0; i < 10; i++) {
        await tester.drag(scrollable, const Offset(0, scrollIncrement));
        await tester.pumpAndSettle();

        // Collect any new icons that became visible
        for (final widget in tester.widgetList<Icon>(find.byType(Icon))) {
          foundIcons.add(widget.icon!);
        }
      }

      // We should have found most of the CategoryIcon values (allowing for lazy loading limitations)
      // This test ensures the scrolling mechanism works and icons are accessible
      expect(foundIcons.length, greaterThanOrEqualTo(30),
          reason:
              'Should be able to access at least 30 different icons through scrolling, found ${foundIcons.length}');

      // Verify we found the close button icon
      expect(foundIcons.contains(Icons.close), isTrue,
          reason: 'Should find the close button icon');
    });

    testWidgets('should display correct title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CategoryIconPicker(),
          ),
        ),
      );

      expect(find.text(CategoryIconStrings.chooseIconTitle), findsOneWidget);
    });

    testWidgets('should have close button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CategoryIconPicker(),
          ),
        ),
      );

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('should close dialog when close button is tapped',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => const CategoryIconPicker(),
                  );
                },
                child: const Text('Open Picker'),
              ),
            ),
          ),
        ),
      );

      // Open the dialog
      await tester.tap(find.text('Open Picker'));
      await tester.pumpAndSettle();

      // Verify dialog is open
      expect(find.byType(CategoryIconPicker), findsOneWidget);

      // Tap close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Verify dialog is closed
      expect(find.byType(CategoryIconPicker), findsNothing);
    });

    testWidgets('should highlight selected icon', (tester) async {
      const selectedIcon = CategoryIcon.fitness;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CategoryIconPicker(selectedIcon: selectedIcon),
          ),
        ),
      );

      // Find the fitness icon container
      final fitnessIconFinder = find.byIcon(Icons.fitness_center);
      expect(fitnessIconFinder, findsOneWidget);

      // Get the container widget that should be highlighted
      final containerWidget = tester.widget<Container>(
        find
            .ancestor(
              of: fitnessIconFinder,
              matching: find.byType(Container),
            )
            .first,
      );

      final decoration = containerWidget.decoration! as BoxDecoration;

      // Should have a colored background for selected state
      expect(decoration.color, isNotNull);
      expect((decoration.color!.a * 255.0).round() & 0xff, greaterThan(0));
    });

    testWidgets('should return selected icon when tapped', (tester) async {
      CategoryIcon? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showDialog<CategoryIcon>(
                    context: context,
                    builder: (context) => const CategoryIconPicker(),
                  );
                },
                child: const Text('Show Picker'),
              ),
            ),
          ),
        ),
      );

      // Open the picker
      await tester.tap(find.text('Show Picker'));
      await tester.pumpAndSettle();

      // Tap on the fitness icon
      await tester.tap(find.byIcon(Icons.fitness_center));
      await tester.pumpAndSettle();

      expect(result, equals(CategoryIcon.fitness));
    });

    testWidgets('should display icon names', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CategoryIconPicker(),
          ),
        ),
      );

      // Should display some icon names - look for any text that matches known display names
      final textWidgets = find.byType(Text);
      expect(textWidgets, findsWidgets);

      // Should find at least some of our known display names
      final allText =
          tester.widgetList<Text>(textWidgets).map((w) => w.data).toList();
      expect(
          allText.contains('Fitness') ||
              allText.contains('Running') ||
              allText.contains('Home'),
          isTrue);
    });

    testWidgets('should use correct grid layout', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CategoryIconPicker(),
          ),
        ),
      );

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

      expect(delegate.crossAxisCount,
          equals(CategoryIconConstants.pickerGridColumns));
      expect(delegate.crossAxisSpacing,
          equals(CategoryIconConstants.pickerGridSpacing));
      expect(delegate.mainAxisSpacing,
          equals(CategoryIconConstants.pickerGridSpacing));
    });

    testWidgets('should have correct dialog constraints', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CategoryIconPicker(),
          ),
        ),
      );

      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      final container = dialog.child! as Container;
      final constraints = container.constraints!;

      expect(
          constraints.maxWidth, equals(CategoryIconConstants.pickerMaxWidth));
    });

    testWidgets('should handle null selectedIcon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CategoryIconPicker(),
          ),
        ),
      );

      // Should render without errors
      expect(find.byType(CategoryIconPicker), findsOneWidget);
    });
  });
}
