import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/selection/selection_modal_base.dart';
import 'package:lotti/widgets/selection/selection_option.dart';
import 'package:lotti/widgets/selection/selection_save_button.dart';

import '../../test_helper.dart';
import 'selection_modal_base_test_helpers.dart';

void main() {
  group('SelectionModalContent', () {
    Widget createTestWidget({
      required List<Widget> children,
      EdgeInsets? padding,
    }) {
      return WidgetTestBench(
        child: Center(
          child: SelectionModalContent(
            padding: padding ?? const EdgeInsets.all(20),
            children: children,
          ),
        ),
      );
    }

    testWidgets('applies correct default padding', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          children: const [Text('Test Content')],
        ),
      );
      await tester.pump();

      final padding = tester.widget<Padding>(
        find.byType(Padding).first,
      );
      expect(padding.padding, const EdgeInsets.all(20));
    });

    testWidgets('applies custom padding', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          children: const [Text('Test Content')],
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        ),
      );
      await tester.pump();

      final padding = tester.widget<Padding>(
        find.byType(Padding).first,
      );
      expect(
        padding.padding,
        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      );
    });

    testWidgets('renders all children', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          children: const [
            Text('Child 1'),
            Text('Child 2'),
            Text('Child 3'),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Child 1'), findsOneWidget);
      expect(find.text('Child 2'), findsOneWidget);
      expect(find.text('Child 3'), findsOneWidget);
    });

    testWidgets('uses Column with mainAxisSize.min', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          children: const [Text('Content')],
        ),
      );
      await tester.pump();

      final column = tester.widget<Column>(find.byType(Column).first);
      expect(column.mainAxisSize, MainAxisSize.min);
    });

    testWidgets('handles empty children list', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          children: const [],
        ),
      );
      await tester.pump();

      expect(find.byType(SelectionModalContent), findsOneWidget);
      expect(find.byType(Column), findsOneWidget);
    });
  });

  group('SelectionOptionsList', () {
    Widget createTestWidget({
      required int itemCount,
      required IndexedWidgetBuilder itemBuilder,
      double? separatorHeight,
    }) {
      return WidgetTestBench(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectionOptionsList(
                itemCount: itemCount,
                itemBuilder: itemBuilder,
                separatorHeight: separatorHeight ?? 8,
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('renders correct number of items', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          itemCount: 5,
          itemBuilder: (context, index) => Text('Item $index'),
        ),
      );
      await tester.pump();

      for (var i = 0; i < 5; i++) {
        expect(find.text('Item $i'), findsOneWidget);
      }
    });

    testWidgets('uses default separator height', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          itemCount: 3,
          itemBuilder: (context, index) => SizedBox(
            height: 50,
            child: Text('Item $index'),
          ),
        ),
      );
      await tester.pump();

      // Check ListView.separated is used
      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(
        listView.itemExtent,
        isNull,
      ); // ListView.separated doesn't use itemExtent
    });

    testWidgets('handles empty list', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          itemCount: 0,
          itemBuilder: (context, index) => Text('Item $index'),
        ),
      );
      await tester.pump();

      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('Item 0'), findsNothing);
    });

    testWidgets('uses shrinkWrap', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          itemCount: 3,
          itemBuilder: (context, index) => Text('Item $index'),
        ),
      );
      await tester.pump();

      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.shrinkWrap, true);
    });

    testWidgets('is wrapped in Flexible', (tester) async {
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
      await tester.pump();

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
      await tester.pump();

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
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Verify structure
      expect(find.byType(TestSelectionModal), findsOneWidget);
      expect(find.byType(SelectionModalContent), findsOneWidget);
      expect(find.byType(SelectionOptionsList), findsOneWidget);
      expect(find.byType(SelectionOption), findsNWidgets(2));
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
                return ElevatedButton(
                  onPressed: () {
                    SelectionModalBase.show(
                      context: context,
                      title: 'Dark Theme Modal',
                      child: const SelectionModalContent(
                        children: [Text('Dark theme content')],
                      ),
                    );
                  },
                  child: const Text('Open Modal'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Tap button to open modal
      await tester.tap(find.text('Open Modal'));
      // Advance through the modal route transition (bounded, no settle).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify content is shown with dark theme
      expect(find.text('Dark theme content'), findsOneWidget);
    });
  });
}
