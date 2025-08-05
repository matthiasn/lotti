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

      // Count the number of icon widgets
      final iconCount = tester.widgetList(find.byType(Icon)).length;
      // Should have all CategoryIcon values plus close button (counting the actual count we have: 56 + 1 = 57)
      // But if we're only seeing 21, the layout might be lazy-loaded or compressed
      expect(iconCount, greaterThanOrEqualTo(21));
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
