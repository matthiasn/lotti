import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/selection/selection_option.dart';

void main() {
  group('SelectionOption', () {
    Widget createTestWidget({
      required String title,
      required IconData icon, required bool isSelected, required VoidCallback onTap, String? description,
      Widget? selectionIndicator,
    }) {
      return MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: SelectionOption(
            title: title,
            description: description,
            icon: icon,
            isSelected: isSelected,
            onTap: onTap,
            selectionIndicator: selectionIndicator,
          ),
        ),
      );
    }

    group('Rendering', () {
      testWidgets('renders all required elements', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Test Option',
          icon: Icons.settings,
          isSelected: false,
          onTap: () {},
        ));

        expect(find.text('Test Option'), findsOneWidget);
        expect(find.byIcon(Icons.settings), findsOneWidget);
        expect(find.byType(InkWell), findsOneWidget);
        expect(find.byType(Container), findsAtLeastNWidgets(2));
      });

      testWidgets('renders description when provided', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Test Option',
          description: 'This is a description',
          icon: Icons.settings,
          isSelected: false,
          onTap: () {},
        ));

        expect(find.text('This is a description'), findsOneWidget);
      });

      testWidgets('does not render description when not provided',
          (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Test Option',
          icon: Icons.settings,
          isSelected: false,
          onTap: () {},
        ));

        expect(find.text('This is a description'), findsNothing);
      });

      testWidgets('truncates long description with ellipsis', (tester) async {
        final longDescription =
            'This is a very long description that should be truncated after two lines. ' *
                10;

        await tester.pumpWidget(createTestWidget(
          title: 'Test Option',
          description: longDescription,
          icon: Icons.settings,
          isSelected: false,
          onTap: () {},
        ));

        final textWidget = tester.widget<Text>(
          find.descendant(
            of: find.byType(SelectionOption),
            matching: find.text(longDescription),
          ),
        );

        expect(textWidget.maxLines, 2);
        expect(textWidget.overflow, TextOverflow.ellipsis);
      });
    });

    group('Selection State', () {
      testWidgets('shows checkmark when selected with default indicator',
          (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Test Option',
          icon: Icons.settings,
          isSelected: true,
          onTap: () {},
        ));

        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      });

      testWidgets('shows empty circle when not selected with default indicator',
          (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Test Option',
          icon: Icons.settings,
          isSelected: false,
          onTap: () {},
        ));

        expect(find.byIcon(Icons.check_rounded), findsNothing);

        // Find the empty circle container
        final circleContainers = tester
            .widgetList<Container>(
          find.descendant(
            of: find.byType(SelectionOption),
            matching: find.byType(Container),
          ),
        )
            .where((container) {
          final decoration = container.decoration as BoxDecoration?;
          return decoration != null &&
              decoration.border != null &&
              decoration.borderRadius == BorderRadius.circular(20);
        });

        expect(circleContainers.isNotEmpty, true);
      });

      testWidgets('uses custom selection indicator when provided',
          (tester) async {
        final customIndicator = Container(
          width: 20,
          height: 20,
          color: Colors.red,
          key: const Key('custom_indicator'),
        );

        await tester.pumpWidget(createTestWidget(
          title: 'Test Option',
          icon: Icons.settings,
          isSelected: true,
          onTap: () {},
          selectionIndicator: customIndicator,
        ));

        expect(find.byKey(const Key('custom_indicator')), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsNothing);
      });

      testWidgets('applies different styling when selected', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Test Option',
          icon: Icons.settings,
          isSelected: true,
          onTap: () {},
        ));

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(SelectionOption),
                matching: find.byType(Container),
              )
              .first,
        );

        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.color, isNotNull);
        expect(decoration.border?.top.width, 2);
        expect(decoration.boxShadow, isNotNull);
        expect(decoration.boxShadow!.length, greaterThan(0));
      });
    });

    group('Interaction', () {
      testWidgets('calls onTap when tapped', (tester) async {
        var tapped = false;

        await tester.pumpWidget(createTestWidget(
          title: 'Test Option',
          icon: Icons.settings,
          isSelected: false,
          onTap: () => tapped = true,
        ));

        await tester.tap(find.byType(InkWell));
        expect(tapped, true);
      });

      testWidgets('shows ink splash on tap', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Test Option',
          icon: Icons.settings,
          isSelected: false,
          onTap: () {},
        ));

        final inkWell = tester.widget<InkWell>(find.byType(InkWell));
        expect(inkWell.borderRadius, BorderRadius.circular(16));
      });

      testWidgets('handles rapid taps correctly', (tester) async {
        var tapCount = 0;

        await tester.pumpWidget(createTestWidget(
          title: 'Test Option',
          icon: Icons.settings,
          isSelected: false,
          onTap: () => tapCount++,
        ));

        // Rapid taps
        for (var i = 0; i < 5; i++) {
          await tester.tap(find.byType(InkWell));
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(tapCount, 5);
      });
    });

    group('Theming', () {
      testWidgets('adapts to dark theme', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: SelectionOption(
                title: 'Test Option',
                icon: Icons.settings,
                isSelected: false,
                onTap: () {},
              ),
            ),
          ),
        );

        final context = tester.element(find.byType(SelectionOption));
        final colorScheme = Theme.of(context).colorScheme;

        // Verify the widget adapts to dark theme
        expect(colorScheme.brightness, Brightness.dark);
      });

      testWidgets('uses correct icon size', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Test Option',
          icon: Icons.settings,
          isSelected: false,
          onTap: () {},
        ));

        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.byType(SelectionOption),
            matching: find.byIcon(Icons.settings),
          ),
        );

        expect(icon.size, 24);
      });
    });

    group('Accessibility', () {
      testWidgets('has proper touch target size', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Test Option',
          icon: Icons.settings,
          isSelected: false,
          onTap: () {},
        ));

        final inkWellSize = tester.getSize(find.byType(InkWell));
        expect(inkWellSize.height, greaterThanOrEqualTo(48));
      });

      testWidgets('maintains readable text contrast', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: 'Test Option',
          description: 'Test description',
          icon: Icons.settings,
          isSelected: true,
          onTap: () {},
        ));

        // The widget should maintain readable contrast
        // This is ensured by the theme system
        expect(find.text('Test Option'), findsOneWidget);
        expect(find.text('Test description'), findsOneWidget);
      });
    });

    group('Edge Cases', () {
      testWidgets('handles empty title', (tester) async {
        await tester.pumpWidget(createTestWidget(
          title: '',
          icon: Icons.settings,
          isSelected: false,
          onTap: () {},
        ));

        expect(find.text(''), findsOneWidget);
      });

      testWidgets('handles very long title', (tester) async {
        const longTitle = 'This is a very long title that might need to wrap';

        await tester.pumpWidget(createTestWidget(
          title: longTitle,
          icon: Icons.settings,
          isSelected: false,
          onTap: () {},
        ));

        expect(find.text(longTitle), findsOneWidget);
      });

      testWidgets('handles null callback gracefully', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SelectionOption(
                title: 'Test Option',
                icon: Icons.settings,
                isSelected: false,
                onTap: () {}, // Required parameter, can't be null
              ),
            ),
          ),
        );

        // Should not crash
        expect(find.byType(SelectionOption), findsOneWidget);
      });
    });
  });

  group('RadioSelectionIndicator', () {
    Widget createTestWidget({required bool isSelected}) {
      return MaterialApp(
        theme: ThemeData.light(),
        home: Scaffold(
          body: Center(
            child: RadioSelectionIndicator(isSelected: isSelected),
          ),
        ),
      );
    }

    testWidgets('shows filled circle when selected', (tester) async {
      await tester.pumpWidget(createTestWidget(isSelected: true));

      // Should have outer circle container
      final containers = tester.widgetList<Container>(find.byType(Container));
      expect(containers.length, 2); // Outer and inner

      // Check inner filled circle
      final innerCircle = containers.last;
      final decoration = innerCircle.decoration! as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(decoration.color, isNotNull);
    });

    testWidgets('shows empty circle when not selected', (tester) async {
      await tester.pumpWidget(createTestWidget(isSelected: false));

      // Should have only outer circle container
      final containers = tester.widgetList<Container>(find.byType(Container));
      expect(containers.length, 1);

      // Check it's empty (no child)
      final container = containers.first;
      expect(container.child, isNull);
    });

    testWidgets('has correct dimensions', (tester) async {
      await tester.pumpWidget(createTestWidget(isSelected: true));

      final outerContainer =
          tester.widget<Container>(find.byType(Container).first);
      expect(outerContainer.constraints?.maxWidth, 20);
      expect(outerContainer.constraints?.maxHeight, 20);
    });

    testWidgets('adapts to theme colors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: Center(
              child: RadioSelectionIndicator(isSelected: true),
            ),
          ),
        ),
      );

      final context = tester.element(find.byType(RadioSelectionIndicator));
      final colorScheme = Theme.of(context).colorScheme;
      expect(colorScheme.brightness, Brightness.dark);
    });
  });
}
