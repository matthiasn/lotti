import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/modal/animated_modal_item.dart';
import 'package:lotti/widgets/modal/animated_modal_item_controller.dart';
import 'package:lotti/widgets/modal/animated_modal_item_with_icon.dart';
import 'package:lotti/widgets/modal/modern_modal_entry_type_item.dart';

void main() {
  group('AnimatedModalItem Resource Management Tests', () {
    testWidgets('AnimatedModalItem handles property updates correctly',
        (tester) async {
      var tapCount = 0;

      // Initial widget with default values
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItem(
              onTap: () => tapCount++,
              child: const Text('Test Item'),
            ),
          ),
        ),
      );

      // Verify initial state works
      await tester.tap(find.text('Test Item'));
      await tester.pump();
      expect(tapCount, 1);

      // Update widget with new animation values
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItem(
              onTap: () => tapCount++,
              hoverScale: 0.95,
              tapScale: 0.90,
              tapOpacity: 0.7,
              hoverElevation: 8,
              child: const Text('Test Item'),
            ),
          ),
        ),
      );

      // Verify widget still works after update
      await tester.tap(find.text('Test Item'));
      await tester.pump();
      expect(tapCount, 2);

      // Widget should still be present and functional
      expect(find.byType(AnimatedModalItem), findsOneWidget);
      expect(find.text('Test Item'), findsOneWidget);
    });

    testWidgets('AnimatedModalItemWithIcon handles property updates correctly',
        (tester) async {
      var tapCount = 0;
      var iconBuilderCallCount = 0;

      // Initial widget with default values
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItemWithIcon(
              onTap: () => tapCount++,
              iconBuilder: (context, animation, {required isPressed}) {
                iconBuilderCallCount++;
                return Icon(
                  Icons.add,
                  size: 24 * animation.value,
                );
              },
              child: const Text('Test Item'),
            ),
          ),
        ),
      );

      // Verify initial state works
      await tester.tap(find.text('Test Item'));
      await tester.pump();
      expect(tapCount, 1);
      expect(iconBuilderCallCount, greaterThan(0));

      final initialBuilderCount = iconBuilderCallCount;

      // Update widget with new animation values
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItemWithIcon(
              onTap: () => tapCount++,
              hoverScale: 0.95,
              tapScale: 0.90,
              iconScaleOnTap: 0.8,
              iconBuilder: (context, animation, {required isPressed}) {
                iconBuilderCallCount++;
                return Icon(
                  Icons.add,
                  size: 24 * animation.value,
                );
              },
              child: const Text('Test Item'),
            ),
          ),
        ),
      );

      // Icon builder should be called again after update
      expect(iconBuilderCallCount, greaterThan(initialBuilderCount));

      // Verify widget still works after update
      await tester.tap(find.text('Test Item'));
      await tester.pump();
      expect(tapCount, 2);

      // Widget should still be present and functional
      expect(find.byType(AnimatedModalItemWithIcon), findsOneWidget);
      expect(find.text('Test Item'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('AnimatedModalItem properly disposes controllers',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItem(
              onTap: () {},
              child: const Text('Test Item'),
            ),
          ),
        ),
      );

      // Remove the widget
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(),
          ),
        ),
      );

      // Controllers should be disposed (no way to directly test this,
      // but the test will fail if dispose throws an error)
      expect(find.byType(AnimatedModalItem), findsNothing);
    });

    testWidgets('AnimatedModalItem handles controller switching correctly',
        (tester) async {
      var tapCount = 0;
      final externalController = AnimatedModalItemController(
        vsync: const TestVSync(),
      );

      // Start with internal controller
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItem(
              onTap: () => tapCount++,
              child: const Text('Test Item'),
            ),
          ),
        ),
      );

      // Verify it works
      await tester.tap(find.text('Test Item'));
      await tester.pump();
      expect(tapCount, 1);

      // Switch to external controller
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItem(
              controller: externalController,
              onTap: () => tapCount++,
              child: const Text('Test Item'),
            ),
          ),
        ),
      );

      // Verify it still works
      await tester.tap(find.text('Test Item'));
      await tester.pump();
      expect(tapCount, 2);

      // Switch back to internal controller
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItem(
              onTap: () => tapCount++,
              child: const Text('Test Item'),
            ),
          ),
        ),
      );

      // Verify it still works
      await tester.tap(find.text('Test Item'));
      await tester.pump();
      expect(tapCount, 3);

      externalController.dispose();
    });

    testWidgets('AnimatedModalItemWithIcon properly disposes controllers',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItemWithIcon(
              onTap: () {},
              iconBuilder: (context, animation, {required isPressed}) {
                return const Icon(Icons.add);
              },
              child: const Text('Test Item'),
            ),
          ),
        ),
      );

      // Remove the widget
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(),
          ),
        ),
      );

      // Controllers should be disposed
      expect(find.byType(AnimatedModalItemWithIcon), findsNothing);
    });

    testWidgets('ModernModalEntryTypeItem handles property updates correctly',
        (tester) async {
      var tapCount = 0;

      // Initial widget with default values
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernModalEntryTypeItem(
              icon: Icons.event,
              title: 'Create Event',
              onTap: () => tapCount++,
            ),
          ),
        ),
      );

      // Verify initial state works
      await tester.tap(find.text('Create Event'));
      await tester.pump();
      expect(tapCount, 1);

      // Update widget with disabled state (which triggers didUpdateWidget)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernModalEntryTypeItem(
              icon: Icons.event,
              title: 'Create Event',
              onTap: () => tapCount++,
              isDisabled: true,
            ),
          ),
        ),
      );

      // Try tapping disabled widget
      await tester.tap(find.text('Create Event'));
      await tester.pump();
      expect(tapCount, 1); // Should not increment

      // Update back to enabled
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernModalEntryTypeItem(
              icon: Icons.event,
              title: 'Create Event',
              onTap: () => tapCount++,
            ),
          ),
        ),
      );

      // Should work again
      await tester.tap(find.text('Create Event'));
      await tester.pump();
      expect(tapCount, 2);

      // Widget should still be present and functional
      expect(find.byType(ModernModalEntryTypeItem), findsOneWidget);
      expect(find.text('Create Event'), findsOneWidget);
      expect(find.byIcon(Icons.event), findsOneWidget);
    });

    testWidgets('ModernModalEntryTypeItem properly disposes controllers',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModernModalEntryTypeItem(
              icon: Icons.task,
              title: 'Create Task',
              onTap: () {},
            ),
          ),
        ),
      );

      // Remove the widget
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(),
          ),
        ),
      );

      // Controllers should be disposed
      expect(find.byType(ModernModalEntryTypeItem), findsNothing);
    });
  });
}
