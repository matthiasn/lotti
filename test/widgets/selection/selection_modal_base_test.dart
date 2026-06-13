import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/selection/selection_modal_base.dart';
import 'package:lotti/widgets/selection/selection_save_button.dart';

import '../../test_helper.dart';
import 'selection_modal_base_test_helpers.dart';

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
        await tester.pumpWidget(
          createTestWidget(
            title: 'Test Modal',
            child: const Text('Test Content'),
          ),
        );
        await tester.pump();

        expect(find.text('Test Modal'), findsOneWidget);
        expect(find.text('Test Content'), findsOneWidget);
      });

      testWidgets('includes save button when onSave is provided', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            title: 'Test Modal',
            onSave: () {},
            child: const Text('Test Content'),
          ),
        );
        await tester.pump();

        expect(find.byType(SelectionSaveButton), findsOneWidget);
      });

      testWidgets('hides save button when onSave is null', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            title: 'Test Modal',
            child: const Text('Test Content'),
          ),
        );
        await tester.pump();

        expect(find.byType(SelectionSaveButton), findsNothing);
      });

      testWidgets('renders trailing widget when provided', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            title: 'Test Modal',
            trailing: const Icon(Icons.info),
            child: const Text('Test Content'),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.info), findsOneWidget);
      });

      testWidgets('show method opens modal correctly', (tester) async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    SelectionModalBase.show(
                      context: context,
                      title: 'Test Title',
                      child: const Text('Test Child'),
                    );
                  },
                  child: const Text('Open Modal'),
                );
              },
            ),
          ),
        );
        await tester.pump();

        // Tap button to open modal
        await tester.tap(find.text('Open Modal'));
        // Advance through the modal route transition (bounded, no settle).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Verify modal content is shown
        expect(find.text('Test Child'), findsOneWidget);
      });

      testWidgets('modal dismisses on barrier tap', (tester) async {
        await tester.pumpWidget(
          WidgetTestBench(
            child: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    SelectionModalBase.show(
                      context: context,
                      title: 'Test Title',
                      child: const Text('Dismissible Child'),
                    );
                  },
                  child: const Text('Open Modal'),
                );
              },
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Open Modal'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Dismissible Child'), findsOneWidget);

        // Tapping the scrim outside the sheet dismisses the modal (the
        // SelectionModalBase.show path is barrierDismissible by default).
        await tester.tapAt(const Offset(10, 10));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Dismissible Child'), findsNothing);
      });
    });

    group('Child Content', () {
      testWidgets('properly displays child widgets', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            title: 'Test Modal',
            child: const Column(
              children: [
                Text('Child 1'),
                Text('Child 2'),
                Text('Child 3'),
              ],
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Child 1'), findsOneWidget);
        expect(find.text('Child 2'), findsOneWidget);
        expect(find.text('Child 3'), findsOneWidget);
        expect(find.byType(Column), findsAtLeastNWidgets(1));
      });

      testWidgets('handles complex child layouts', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
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
          ),
        );
        await tester.pump();

        expect(find.byType(ListView), findsOneWidget);
        expect(find.byType(ListTile), findsNWidgets(5));
        expect(find.byIcon(Icons.star), findsNWidgets(5));
      });
    });

    group('Interaction', () {
      testWidgets('save button calls onSave when tapped', (tester) async {
        var saved = false;

        await tester.pumpWidget(
          createTestWidget(
            title: 'Test Modal',
            onSave: () => saved = true,
            child: const Text('Test Content'),
          ),
        );
        await tester.pump();

        await tester.tap(find.byType(SelectionSaveButton));
        expect(saved, true);
      });

      testWidgets('handles disabled save button', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            title: 'Test Modal',
            child: const Text('Test Content'),
          ),
        );
        await tester.pump();

        // Save button should not exist when onSave is null
        expect(find.byType(SelectionSaveButton), findsNothing);
      });
    });

    group('Edge Cases', () {
      testWidgets('handles empty content', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            title: 'Test Modal',
            child: const SizedBox.shrink(),
          ),
        );
        await tester.pump();

        // The empty body must not break the modal chrome: the title still
        // renders and no layout exception is thrown.
        expect(find.text('Test Modal'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('handles very long title', (tester) async {
        final longTitle =
            'This is a very long title that might wrap to multiple lines' * 3;

        await tester.pumpWidget(
          WidgetTestBench(
            child: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    SelectionModalBase.show(
                      context: context,
                      title: longTitle,
                      child: const Text('Test'),
                    );
                  },
                  child: const Text('Open Modal'),
                );
              },
            ),
          ),
        );
        await tester.pump();

        // Tap button to open modal
        await tester.tap(find.text('Open Modal'));
        // Advance through the modal route transition (bounded, no settle).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Verify content is shown (title might be truncated in the modal)
        expect(find.text('Test'), findsOneWidget);
      });

      testWidgets('handles scrollable content', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            title: 'Test Modal',
            child: SingleChildScrollView(
              child: Container(
                height: 1000,
                color: Colors.blue,
                child: const Center(child: Text('Very tall content')),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Very tall content'), findsOneWidget);
      });
    });
  });
}
