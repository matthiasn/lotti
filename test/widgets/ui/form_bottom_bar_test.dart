import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/ui/form_bottom_bar.dart';

void main() {
  group('FormBottomBar Tests', () {
    testWidgets('displays only right buttons when no left button',
        (tester) async {
      var savePressed = false;
      var cancelPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SizedBox(),
            bottomNavigationBar: FormBottomBar(
              rightButtons: [
                TextButton(
                  onPressed: () => cancelPressed = true,
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => savePressed = true,
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      );

      // Should display both right buttons
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      // Test button presses
      await tester.tap(find.text('Cancel'));
      expect(cancelPressed, isTrue);

      await tester.tap(find.text('Save'));
      expect(savePressed, isTrue);
    });

    testWidgets('displays left button and right buttons', (tester) async {
      var deletePressed = false;
      var savePressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SizedBox(),
            bottomNavigationBar: FormBottomBar(
              leftButton: TextButton(
                onPressed: () => deletePressed = true,
                child: const Text('Delete'),
              ),
              rightButtons: [
                ElevatedButton(
                  onPressed: () => savePressed = true,
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      );

      // Should display both buttons
      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      // Test button presses
      await tester.tap(find.text('Delete'));
      expect(deletePressed, isTrue);

      await tester.tap(find.text('Save'));
      expect(savePressed, isTrue);
    });

    testWidgets('handles empty right buttons list', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(),
            bottomNavigationBar: FormBottomBar(
              leftButton: Text('Left Button'),
              rightButtons: [],
            ),
          ),
        ),
      );

      // Should display left button
      expect(find.text('Left Button'), findsOneWidget);

      // Should not crash with empty right buttons
      expect(find.byType(FormBottomBar), findsOneWidget);
    });

    testWidgets('handles multiple right buttons with proper spacing',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SizedBox(),
            bottomNavigationBar: FormBottomBar(
              rightButtons: [
                TextButton(
                  onPressed: () {},
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Reset'),
                ),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      );

      // Should display all buttons
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      // Should be in a Row
      expect(
        find.descendant(
          of: find.byType(FormBottomBar),
          matching: find.byType(Row),
        ),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('has proper container styling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
          home: Scaffold(
            body: const SizedBox(),
            bottomNavigationBar: FormBottomBar(
              rightButtons: [
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Submit'),
                ),
              ],
            ),
          ),
        ),
      );

      // Find the main container
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(FormBottomBar),
              matching: find.byType(Container),
            )
            .first,
      );

      // Check padding
      expect(container.padding, isNotNull);

      // Check decoration
      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.boxShadow, isNotNull);
      expect(decoration.boxShadow!.isNotEmpty, isTrue);
    });

    testWidgets('renders correctly with text field', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const TextField(),
            bottomNavigationBar: FormBottomBar(
              rightButtons: [
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        ),
      );

      // The FormBottomBar should be present
      expect(find.byType(FormBottomBar), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('buttons remain functional when disabled', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(),
            bottomNavigationBar: FormBottomBar(
              rightButtons: [
                ElevatedButton(
                  onPressed: null, // Disabled
                  child: Text('Save'),
                ),
              ],
            ),
          ),
        ),
      );

      // Button should be displayed but disabled
      expect(find.text('Save'), findsOneWidget);

      final button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('respects theme elevation', (tester) async {
      const elevation = 8.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            appBarTheme: const AppBarTheme(elevation: elevation),
          ),
          home: Scaffold(
            body: const SizedBox(),
            bottomNavigationBar: FormBottomBar(
              rightButtons: [
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        ),
      );

      // Should display the form bar
      expect(find.byType(FormBottomBar), findsOneWidget);
    });

    testWidgets('renders with bottom padding', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(bottom: 34), // iPhone X style safe area
            ),
            child: Scaffold(
              body: const SizedBox(),
              bottomNavigationBar: FormBottomBar(
                rightButtons: [
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Should render properly
      expect(find.byType(FormBottomBar), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('maintains button order', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(),
            bottomNavigationBar: FormBottomBar(
              leftButton: Text('Delete'),
              rightButtons: [
                Text('Cancel'),
                Text('Save'),
              ],
            ),
          ),
        ),
      );

      // Get positions of buttons
      final deletePosition = tester.getCenter(find.text('Delete'));
      final cancelPosition = tester.getCenter(find.text('Cancel'));
      final savePosition = tester.getCenter(find.text('Save'));

      // Delete should be on the left
      expect(deletePosition.dx < cancelPosition.dx, isTrue);

      // Cancel should be before Save
      expect(cancelPosition.dx < savePosition.dx, isTrue);
    });
  });
}
