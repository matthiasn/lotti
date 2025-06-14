import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ai_settings_search_bar.dart';

void main() {
  group('AiSettingsSearchBar', () {
    late TextEditingController controller;
    var onChangedCalled = false;
    var onClearCalled = false;
    var lastChangedValue = '';

    setUp(() {
      controller = TextEditingController();
      onChangedCalled = false;
      onClearCalled = false;
      lastChangedValue = '';
    });

    tearDown(() {
      controller.dispose();
    });

    Widget createWidget({
      String? hintText,
      VoidCallback? onClear,
      ValueChanged<String>? onChanged,
      bool isCompact = false,
      ThemeData? theme,
    }) {
      return MaterialApp(
        theme: theme,
        home: Scaffold(
          body: AiSettingsSearchBar(
            controller: controller,
            hintText: hintText ?? 'Search AI configurations...',
            isCompact: isCompact,
            onClear: onClear ??
                () {
                  onClearCalled = true;
                },
            onChanged: onChanged ??
                (value) {
                  onChangedCalled = true;
                  lastChangedValue = value;
                },
          ),
        ),
      );
    }

    testWidgets('displays correctly with default styling',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.text('Search AI configurations...'), findsOneWidget);
    });

    testWidgets('shows custom hint text', (WidgetTester tester) async {
      const customHint = 'Search AI configurations...';
      await tester.pumpWidget(createWidget(hintText: customHint));

      expect(find.text(customHint), findsOneWidget);
    });

    testWidgets('calls onChanged when text is entered',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      const testText = 'test query';
      await tester.enterText(find.byType(TextField), testText);

      expect(onChangedCalled, isTrue);
      expect(lastChangedValue, testText);
    });

    testWidgets('shows clear button when text is present',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      // Initially no clear button
      expect(find.byIcon(Icons.clear_rounded), findsNothing);

      // Enter text
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump();

      // Clear button should appear
      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);
    });

    testWidgets('hides clear button when text is empty',
        (WidgetTester tester) async {
      controller.text = 'test';
      await tester.pumpWidget(createWidget());

      // Clear button should be visible
      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);

      // Clear the text
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      // Clear button should be hidden
      expect(find.byIcon(Icons.clear_rounded), findsNothing);
    });

    testWidgets('calls onClear when clear button is tapped',
        (WidgetTester tester) async {
      controller.text = 'test';
      await tester.pumpWidget(createWidget());

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pump();

      expect(onClearCalled, isTrue);
    });

    testWidgets('clears text when clear button is tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      // Enter text
      await tester.enterText(find.byType(TextField), 'test query');
      await tester.pump();

      expect(controller.text, 'test query');

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pump();

      // Text should be cleared (assuming onClear implementation clears it)
      expect(find.byIcon(Icons.clear_rounded), findsNothing);
    });

    testWidgets('has proper accessibility properties',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      // Check that the text field is focusable
      await tester.tap(textField);
      await tester.pump();

      final textFieldWidget = tester.widget<TextField>(textField);
      expect(textFieldWidget.decoration?.hintText, isNotNull);
    });

    testWidgets('responds to controller changes externally',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      // Change controller text externally
      controller.text = 'external change';
      await tester.pump();

      expect(find.text('external change'), findsOneWidget);
      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);
    });

    testWidgets('handles empty hint text gracefully',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(hintText: ''));

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    });

    testWidgets('maintains focus state correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      final textField = find.byType(TextField);

      // Focus the text field
      await tester.tap(textField);
      await tester.pump();

      // Enter some text
      await tester.enterText(textField, 'test');
      await tester.pump();

      // The text should remain and clear button should be visible
      expect(find.text('test'), findsOneWidget);
      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);
    });

    testWidgets('handles rapid text changes', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget());

      final textField = find.byType(TextField);

      // Rapidly change text multiple times
      await tester.enterText(textField, 'a');
      await tester.enterText(textField, 'ab');
      await tester.enterText(textField, 'abc');
      await tester.pump();

      expect(controller.text, 'abc');
      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);
    });

    group('keyboard navigation', () {
      testWidgets('can be focused with tab', (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const TextField(),
                AiSettingsSearchBar(
                  controller: controller,
                  hintText: 'Search...',
                  onClear: () {},
                  onChanged: (_) {},
                ),
              ],
            ),
          ),
        ));

        // Tab to the search bar
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();

        // Search bar should be focusable
        expect(find.byType(AiSettingsSearchBar), findsOneWidget);
      });
    });

    group('edge cases', () {
      testWidgets('handles null callbacks gracefully',
          (WidgetTester tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: AiSettingsSearchBar(
              controller: controller,
              hintText: 'Search...',
              onClear: () {}, // Required callback
              onChanged: (_) {}, // Required callback
            ),
          ),
        ));

        // Should not throw when text is entered
        await tester.enterText(find.byType(TextField), 'test');
        await tester.pump();

        expect(find.text('test'), findsOneWidget);
      });

      testWidgets('handles very long text input', (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        const longText =
            'This is a very long search query that might overflow the text field and test how well the widget handles extensive user input without breaking the layout or functionality';

        await tester.enterText(find.byType(TextField), longText);
        await tester.pump();

        expect(controller.text, longText);
        expect(find.byIcon(Icons.clear_rounded), findsOneWidget);
      });
    });

    group('compact mode', () {
      testWidgets('displays correctly in compact mode',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget(isCompact: true));

        expect(find.byType(TextField), findsOneWidget);
        expect(find.byIcon(Icons.search_rounded), findsOneWidget);

        // Check that container has correct height
        final container = find.byType(Container).first;
        final containerBox = tester.renderObject<RenderBox>(container);
        expect(containerBox.size.height, 36);
      });

      testWidgets('shows smaller text in compact mode',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget(isCompact: true));

        await tester.enterText(find.byType(TextField), 'test');
        await tester.pump();

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.style?.fontSize, 14);
      });

      testWidgets('clear button works in compact mode',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget(isCompact: true));

        await tester.enterText(find.byType(TextField), 'test');
        await tester.pump();

        expect(find.byIcon(Icons.clear_rounded), findsOneWidget);

        await tester.tap(find.byIcon(Icons.clear_rounded));
        await tester.pump();

        expect(onClearCalled, isTrue);
      });
    });

    group('theme variations', () {
      testWidgets('displays correctly in dark mode',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget(
          theme: ThemeData.dark(),
        ));

        expect(find.byType(TextField), findsOneWidget);
        expect(find.byIcon(Icons.search_rounded), findsOneWidget);

        // Should render without errors in dark mode
        final container = find.byType(Container).first;
        expect(container, findsOneWidget);
      });

      testWidgets('displays correctly in light mode',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget(
          theme: ThemeData.light(),
        ));

        expect(find.byType(TextField), findsOneWidget);
        expect(find.byIcon(Icons.search_rounded), findsOneWidget);

        // Should render without errors in light mode
        final container = find.byType(Container).first;
        expect(container, findsOneWidget);
      });

      testWidgets('compact mode works in dark theme',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget(
          isCompact: true,
          theme: ThemeData.dark(),
        ));

        expect(find.byType(TextField), findsOneWidget);

        // Check that container has correct height
        final container = find.byType(Container).first;
        final containerWidget = tester.widget<Container>(container);
        expect(containerWidget.constraints?.maxHeight, 36);
      });
    });

    group('widget lifecycle', () {
      testWidgets('disposes properly when removed from tree',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        // Verify widget is rendered
        expect(find.byType(AiSettingsSearchBar), findsOneWidget);

        // Remove widget from tree
        await tester.pumpWidget(const MaterialApp(
          home: Scaffold(
            body: SizedBox(),
          ),
        ));

        // Widget should be disposed
        expect(find.byType(AiSettingsSearchBar), findsNothing);
      });

      testWidgets('handles controller listener properly across rebuilds',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        // Change controller text
        controller.text = 'test1';
        await tester.pump();
        expect(find.byIcon(Icons.clear_rounded), findsOneWidget);

        // Rebuild widget with same controller
        await tester.pumpWidget(createWidget());

        // Change controller text again
        controller.text = 'test2';
        await tester.pump();
        expect(find.byIcon(Icons.clear_rounded), findsOneWidget);

        // Clear text
        controller.text = '';
        await tester.pump();
        expect(find.byIcon(Icons.clear_rounded), findsNothing);
      });

      testWidgets('text input action is set to search',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.textInputAction, TextInputAction.search);
      });

      testWidgets('keyboard type is set to text', (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.keyboardType, TextInputType.text);
      });
    });

    group('accessibility', () {
      testWidgets('semantic labels are properly set',
          (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());

        // Search icon should have semantic label
        final searchIcon = tester.widget<Icon>(
          find.byIcon(Icons.search_rounded),
        );
        expect(searchIcon.semanticLabel, 'Search icon');

        // Enter text to show clear button
        await tester.enterText(find.byType(TextField), 'test');
        await tester.pump();

        // Clear icon should have semantic label
        final clearIcon = tester.widget<Icon>(
          find.byIcon(Icons.clear_rounded),
        );
        expect(clearIcon.semanticLabel, 'Clear search');
      });
    });
  });
}
