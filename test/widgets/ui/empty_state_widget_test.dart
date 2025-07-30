import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/ui/empty_state_widget.dart';

void main() {
  group('EmptyStateWidget Tests', () {
    testWidgets('displays required elements', (tester) async {
      const icon = Icons.folder_open;
      const title = 'No items found';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: icon,
              title: title,
            ),
          ),
        ),
      );

      // Should display icon
      expect(find.byIcon(icon), findsOneWidget);

      // Should display title
      expect(find.text(title), findsOneWidget);

      // Should not display description when not provided
      expect(find.byType(Text), findsOneWidget); // Only title
    });

    testWidgets('displays description when provided', (tester) async {
      const icon = Icons.search_off;
      const title = 'No results';
      const description = 'Try adjusting your search filters';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: icon,
              title: title,
              description: description,
            ),
          ),
        ),
      );

      // Should display all elements
      expect(find.byIcon(icon), findsOneWidget);
      expect(find.text(title), findsOneWidget);
      expect(find.text(description), findsOneWidget);
    });

    testWidgets('respects custom icon size', (tester) async {
      const iconSize = 64.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.inbox,
              title: 'Empty inbox',
              iconSize: iconSize,
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.inbox));
      expect(icon.size, iconSize);
    });

    testWidgets('default icon size is 48', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.inbox,
              title: 'Empty inbox',
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.inbox));
      expect(icon.size, 48);
    });

    testWidgets('displays container when showContainer is true',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.folder_open,
              title: 'No items',
            ),
          ),
        ),
      );

      // Should have a container with decoration
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(EmptyStateWidget),
              matching: find.byType(Container),
            )
            .first,
      );

      expect(container.decoration, isA<BoxDecoration>());
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(12));
      expect(decoration.border, isNotNull);
    });

    testWidgets('no container when showContainer is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.folder_open,
              title: 'No items',
              showContainer: false,
            ),
          ),
        ),
      );

      // Should only have the column, no decorated container
      expect(find.byType(Column), findsOneWidget);

      // Container might exist but without decoration
      final containers = find.byType(Container);
      var hasDecoratedContainer = false;
      for (var i = 0; i < containers.evaluate().length; i++) {
        final container = tester.widget<Container>(containers.at(i));
        if (container.decoration != null) {
          hasDecoratedContainer = true;
          break;
        }
      }
      expect(hasDecoratedContainer, isFalse);
    });

    testWidgets('text alignment is centered', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.search,
              title: 'No results found',
              description: 'Try a different search term',
            ),
          ),
        ),
      );

      // Find all text widgets
      final texts = find.byType(Text);

      // All texts should be center aligned
      for (var i = 0; i < texts.evaluate().length; i++) {
        final text = tester.widget<Text>(texts.at(i));
        expect(text.textAlign, TextAlign.center);
      }
    });

    testWidgets('respects theme colors', (tester) async {
      final theme = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        disabledColor: Colors.grey.shade400,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: EmptyStateWidget(
              icon: Icons.inbox,
              title: 'Empty',
              description: 'No items to display',
            ),
          ),
        ),
      );

      // Icon should use disabled color
      final icon = tester.widget<Icon>(find.byIcon(Icons.inbox));
      expect(icon.color, theme.disabledColor);

      // Description should use disabled color
      final descriptionText = tester.widget<Text>(
        find.text('No items to display'),
      );
      expect(
        descriptionText.style?.color,
        theme.disabledColor,
      );
    });

    testWidgets('handles long text gracefully', (tester) async {
      const longTitle = 'This is a very long title that should wrap properly';
      const longDescription =
          'This is an even longer description that provides '
          'detailed information about why the state is empty and what the user '
          'can do to populate it with content.';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: EmptyStateWidget(
                  icon: Icons.info,
                  title: longTitle,
                  description: longDescription,
                ),
              ),
            ),
          ),
        ),
      );

      // Should display all text
      expect(find.text(longTitle), findsOneWidget);
      expect(find.text(longDescription), findsOneWidget);
    });

    testWidgets('proper spacing between elements', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: EmptyStateWidget(
              icon: Icons.folder,
              title: 'Empty folder',
              description: 'Add files to get started',
            ),
          ),
        ),
      );

      // Check for SizedBox spacers
      final sizedBoxes = find.byType(SizedBox);

      // Should have spacing between icon and title (16)
      // and between title and description (8)
      expect(sizedBoxes, findsAtLeastNWidgets(2));
    });
  });
}
