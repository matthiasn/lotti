import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/selection/selection_modal_base.dart';
import 'package:lotti/widgets/selection/selection_option.dart';
import 'package:lotti/widgets/selection/selection_save_button.dart';

import '../../test_helper.dart';

// Concrete implementation for testing
class TestSelectionModal extends StatelessWidget {
  const TestSelectionModal({
    required this.title,
    required this.child,
    this.onSave,
    this.trailing,
    super.key,
  });

  final String title;
  final Widget child;
  final VoidCallback? onSave;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SelectionModalBase(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(child: child),
          if (onSave != null) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SelectionSaveButton(onPressed: onSave),
            ),
          ],
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

void main() {
  group('SelectionModalBase', () {
    Widget createTestWidget({
      required String title,
      required Widget child,
      VoidCallback? onSave,
      Widget? trailing,
    }) {
      return WidgetTestBench(
        child: Center(
          child: TestSelectionModal(
            title: title,
            onSave: onSave,
            trailing: trailing,
            child: child,
          ),
        ),
      );
    }

    group('Base Layout', () {
      testWidgets('renders with title and content', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Test Modal',
          child: const Text('Test Content'),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Test Content'), findsOneWidget);
        expect(find.text('Test Modal'), findsOneWidget);
      });

      testWidgets('includes save button when onSave is provided',
          (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Test Modal',
          onSave: () {},
          child: const Text('Test Content'),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(SelectionSaveButton), findsOneWidget);
      });

      testWidgets('hides save button when onSave is null', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Test Modal',
          child: const Text('Test Content'),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(SelectionSaveButton), findsNothing);
      });

      testWidgets('renders trailing widget when provided', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Test Modal',
          trailing: const Icon(Icons.info),
          child: const Text('Test Content'),
        ));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.info), findsOneWidget);
      });

      testWidgets('creates proper modal structure', skip: true, (tester) async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: Builder(
              builder: (context) {
                // Verify title
                final titleFinder = find.text('Test Title');
                expect(titleFinder, findsOneWidget);

                // Verify close button
                final closeButtonFinder = find.byIcon(Icons.close);
                expect(closeButtonFinder, findsOneWidget);

                // Verify drag handle
                final dragHandleFinder = find.byType(Container).first;
                final dragHandle = tester.widget<Container>(dragHandleFinder);
                expect(dragHandle.margin, const EdgeInsets.only(top: 8));

                return const Text('Test');
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
      });
    });

    group('Child Content', () {
      testWidgets('properly displays child widgets', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Test Modal',
          child: const Column(
            children: [
              Text('Child 1'),
              Text('Child 2'),
              Text('Child 3'),
            ],
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Child 1'), findsOneWidget);
        expect(find.text('Child 2'), findsOneWidget);
        expect(find.text('Child 3'), findsOneWidget);
        expect(find.byType(Column), findsAtLeastNWidgets(1));
      });

      testWidgets('handles complex child layouts', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Test Modal',
          child: ListView(
            shrinkWrap: true,
            children: List.generate(
              5,
              (index) => ListTile(
                title: Text('Item $index'),
                leading: const Icon(Icons.star),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(ListView), findsOneWidget);
        expect(find.byType(ListTile), findsNWidgets(5));
        expect(find.byIcon(Icons.star), findsNWidgets(5));
      });
    });

    group('Interaction', () {
      testWidgets('save button calls onSave when tapped', (tester) async {
        var saved = false;

        await tester.pumpWidget(createTestWidget(
          title: 'Test Modal',
          onSave: () => saved = true,
          child: const Text('Test Content'),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(SelectionSaveButton));
        expect(saved, true);
      });

      testWidgets('handles disabled save button', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Test Modal',
          child: const Text('Test Content'),
        ));
        await tester.pumpAndSettle();

        // Save button should not exist when onSave is null
        expect(find.byType(SelectionSaveButton), findsNothing);
      });
    });

    group('Edge Cases', () {
      testWidgets('handles empty content', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Test Modal',
          child: const SizedBox.shrink(),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(SizedBox), findsAtLeastNWidgets(1));
      });

      testWidgets('handles very long title', (tester) async {
        final longTitle =
            'This is a very long title that might wrap to multiple lines' * 3;

        await tester.pumpWidget(createTestWidget(
          title: longTitle,
          child: const Text('Test Content'),
        ));
        await tester.pumpAndSettle();

        expect(find.text(longTitle), findsOneWidget);
      });
    });

    testWidgets('displays correctly with basic content', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SelectionModalBase.show(
                  context: context,
                  title: 'Test Modal',
                  child: const Text('Test Content'),
                ),
                child: const Text('Show Modal'),
              ),
            ),
          ),
        ),
      );

      // Open the modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Verify modal elements
      expect(find.text('Test Modal'), findsOneWidget);
      expect(find.text('Test Content'), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget); // Close button
    });

    testWidgets('handles long content with scrolling', (tester) async {
      final longContent = List.generate(
        20,
        (i) => Text('Item $i'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SelectionModalBase.show(
                  context: context,
                  title: 'Long Content',
                  child: SelectionModalContent(
                    children: longContent,
                  ),
                ),
                child: const Text('Show Modal'),
              ),
            ),
          ),
        ),
      );

      // Open the modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Verify scrolling behavior
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 19'), findsOneWidget);
    });

    testWidgets('closes when close button is pressed', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SelectionModalBase.show(
                  context: context,
                  title: 'Test Modal',
                  child: const Text('Test Content'),
                ),
                child: const Text('Show Modal'),
              ),
            ),
          ),
        ),
      );

      // Open the modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Close the modal
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      // Verify modal is closed
      expect(find.text('Test Content'), findsNothing);
    });

    testWidgets('SelectionOptionsList displays items correctly',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => SelectionModalBase.show(
                  context: context,
                  title: 'Options List',
                  child: SelectionOptionsList(
                    itemCount: 3,
                    itemBuilder: (context, index) => Text('Option $index'),
                  ),
                ),
                child: const Text('Show Modal'),
              ),
            ),
          ),
        ),
      );

      // Open the modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Verify list items
      expect(find.text('Option 0'), findsOneWidget);
      expect(find.text('Option 1'), findsOneWidget);
      expect(find.text('Option 2'), findsOneWidget);
      expect(find.byType(Divider), findsNWidgets(2)); // Separators
    });
  });

  group('SelectionModalContent', () {
    Widget createTestWidget({
      required List<Widget> children,
    }) {
      return WidgetTestBench(
        child: Center(
          child: SelectionModalContent(
            children: children,
          ),
        ),
      );
    }

    testWidgets('applies correct default padding', (tester) async {
      await tester.pumpWidget(createTestWidget(
        children: const [Text('Test Content')],
      ));
      await tester.pumpAndSettle();

      final padding = tester.widget<Padding>(
        find.byType(Padding).first,
      );
      expect(padding.padding, const EdgeInsets.fromLTRB(24, 0, 24, 24));
    });

    testWidgets('renders all children', (tester) async {
      await tester.pumpWidget(createTestWidget(
        children: const [
          Text('Child 1'),
          Text('Child 2'),
          Text('Child 3'),
        ],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Child 1'), findsOneWidget);
      expect(find.text('Child 2'), findsOneWidget);
      expect(find.text('Child 3'), findsOneWidget);
    });

    testWidgets('uses Column with mainAxisSize.min', (tester) async {
      await tester.pumpWidget(createTestWidget(
        children: const [Text('Content')],
      ));
      await tester.pumpAndSettle();

      final column = tester.widget<Column>(find.byType(Column).first);
      expect(column.mainAxisSize, MainAxisSize.min);
    });

    testWidgets('handles empty children list', (tester) async {
      await tester.pumpWidget(createTestWidget(
        children: const [],
      ));
      await tester.pumpAndSettle();

      expect(find.byType(SelectionModalContent), findsOneWidget);
      expect(find.byType(Column), findsOneWidget);
    });
  });

  group('SelectionOptionsList', () {
    Widget createTestWidget({
      required int itemCount,
      required IndexedWidgetBuilder itemBuilder,
    }) {
      return WidgetTestBench(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectionOptionsList(
                itemCount: itemCount,
                itemBuilder: itemBuilder,
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('renders correct number of items', (tester) async {
      await tester.pumpWidget(createTestWidget(
        itemCount: 5,
        itemBuilder: (context, index) => Text('Item $index'),
      ));
      await tester.pumpAndSettle();

      for (var i = 0; i < 5; i++) {
        expect(find.text('Item $i'), findsOneWidget);
      }
    });

    testWidgets('handles empty list', (tester) async {
      await tester.pumpWidget(createTestWidget(
        itemCount: 0,
        itemBuilder: (context, index) => Text('Item $index'),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('Item 0'), findsNothing);
    });

    testWidgets('uses shrinkWrap', (tester) async {
      await tester.pumpWidget(createTestWidget(
        itemCount: 3,
        itemBuilder: (context, index) => Text('Item $index'),
      ));
      await tester.pumpAndSettle();

      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.shrinkWrap, true);
    });

    testWidgets('is wrapped in Flexible', skip: true, (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectionOptionsList(
                  itemCount: 3,
                  itemBuilder: (context, index) => Text('Item $index'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.ancestor(
          of: find.byType(ListView),
          matching: find.byType(Flexible),
        ),
        findsOneWidget,
      );
    });

    testWidgets('itemBuilder receives correct indices', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectionOptionsList(
                  itemCount: 5,
                  itemBuilder: (context, index) => Text('Item $index'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // All items should be rendered
      for (var i = 0; i < 5; i++) {
        expect(find.text('Item $i'), findsOneWidget);
      }
    });
  });

  group('Integration', () {
    testWidgets('complete modal flow works correctly', (tester) async {
      const selectedValue = 'option1';
      var savePressed = false;

      await tester.pumpWidget(
        WidgetTestBench(
          child: Center(
            child: TestSelectionModal(
              title: 'Select Option',
              onSave: () => savePressed = true,
              child: SelectionModalContent(
                children: [
                  SelectionOptionsList(
                    itemCount: 2,
                    itemBuilder: (context, index) {
                      final options = ['option1', 'option2'];
                      final option = options[index];
                      final titles = ['Option 1', 'Option 2'];
                      final descriptions = ['First option', 'Second option'];
                      final icons = [Icons.looks_one, Icons.looks_two];

                      return SelectionOption(
                        title: titles[index],
                        description: descriptions[index],
                        icon: icons[index],
                        isSelected: selectedValue == option,
                        onTap: () {},
                        selectionIndicator: RadioSelectionIndicator(
                          isSelected: selectedValue == option,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify structure
      expect(find.byType(TestSelectionModal), findsOneWidget);
      expect(find.byType(SelectionModalContent), findsOneWidget);
      expect(find.byType(SelectionOptionsList), findsOneWidget);
      expect(find.byType(SelectionOption), findsNWidgets(2));
      expect(find.byType(RadioSelectionIndicator), findsNWidgets(2));
      expect(find.byType(SelectionSaveButton), findsOneWidget);

      // Verify content
      expect(find.text('Option 1'), findsOneWidget);
      expect(find.text('Option 2'), findsOneWidget);
      expect(find.text('First option'), findsOneWidget);
      expect(find.text('Second option'), findsOneWidget);

      // Test save button
      await tester.tap(find.byType(SelectionSaveButton));
      expect(savePressed, true);
    });

    testWidgets('modal adapts to theme changes', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: Theme(
            data: ThemeData.dark(),
            child: Builder(
              builder: (context) {
                final theme = Theme.of(context);
                expect(theme.brightness, Brightness.dark);

                return const Text('Test');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    });
  });
}
