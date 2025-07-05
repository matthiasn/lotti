import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/animated_modal_item.dart';
import 'package:lotti/widgets/modal/animated_modal_item_controller.dart';

void main() {
  group('AnimatedModalItem', () {
    late AnimatedModalItemController controller;

    setUp(() {
      // Controller will be created in each test with the proper vsync
    });

    testWidgets('renders child widget correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItem(
              onTap: () {},
              child: const Text('Test Child'),
            ),
          ),
        ),
      );

      expect(find.text('Test Child'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItem(
              onTap: () => tapCount++,
              child: const Text('Tap Me'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap Me'));
      expect(tapCount, 1);
    });

    testWidgets('does not call onTap when disabled', (tester) async {
      var tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItem(
              onTap: () => tapCount++,
              isDisabled: true,
              child: const Text('Disabled'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Disabled'));
      expect(tapCount, 0);
    });

    testWidgets('shows reduced opacity when disabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItem(
              onTap: () {},
              isDisabled: true,
              child: const Text('Disabled'),
            ),
          ),
        ),
      );

      final opacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity).first,
      );
      expect(opacity.opacity, 0.5);
    });

    testWidgets('hover animation works on desktop', (tester) async {
      controller = AnimatedModalItemController(
        vsync: const TestVSync(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItem(
              controller: controller,
              onTap: () {},
              child: const Text('Hover Me'),
            ),
          ),
        ),
      );

      expect(controller.hoverValue, 0.0);

      // Simulate mouse hover
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.text('Hover Me')));
      await tester.pump();

      // Animation should start
      expect(controller.hoverAnimationController.isAnimating, true);

      // Let animation progress
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.hoverValue, greaterThan(0.0));
      expect(controller.hoverValue, lessThanOrEqualTo(1.0));

      // Move mouse away
      await gesture.moveTo(const Offset(500, 500));
      await tester.pump();

      // Animation should reverse
      expect(controller.hoverAnimationController.isAnimating, true);

      // Wait for animation to complete
      await tester.pumpAndSettle();
      expect(controller.hoverValue, 0.0);
    });

    testWidgets('tap animation works correctly', (tester) async {
      controller = AnimatedModalItemController(
        vsync: const TestVSync(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItem(
              controller: controller,
              onTap: () {},
              child: const Text('Tap Me'),
            ),
          ),
        ),
      );

      expect(controller.tapValue, 0.0);

      // Start tap
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Tap Me')),
      );
      await tester.pump();

      // Animation should start
      expect(controller.tapAnimationController.isAnimating, true);

      // Let animation progress
      await tester.pump(const Duration(milliseconds: 75));
      expect(controller.tapValue, greaterThan(0.0));
      expect(controller.tapValue, lessThanOrEqualTo(1.0));

      // End tap
      await gesture.up();
      await tester.pump();

      // Animation should reverse
      expect(controller.tapAnimationController.isAnimating, true);

      // Wait for animation to complete
      await tester.pumpAndSettle();
      expect(controller.tapValue, 0.0);
    });

    testWidgets('tap cancel works correctly', (tester) async {
      controller = AnimatedModalItemController(
        vsync: const TestVSync(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItem(
              controller: controller,
              onTap: () {},
              child: const Text('Tap Me'),
            ),
          ),
        ),
      );

      // Start tap
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Tap Me')),
      );
      await tester.pump();

      // Let animation progress
      await tester.pump(const Duration(milliseconds: 75));
      expect(controller.tapValue, greaterThan(0.0));

      // Cancel tap by moving away
      await gesture.moveBy(const Offset(200, 200));
      await gesture.cancel();
      await tester.pump();

      // Animation should reverse
      expect(controller.tapAnimationController.isAnimating, true);

      // Wait for animation to complete
      await tester.pumpAndSettle();
      expect(controller.tapValue, 0.0);
    });

    testWidgets('applies correct container styling', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: AnimatedModalItem(
              onTap: () {},
              child: const Text('Styled'),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(AnimatedModalItem),
              matching: find.byType(Container),
            )
            .first,
      );

      expect(
          container.margin,
          const EdgeInsets.symmetric(
            horizontal: AppTheme.cardPadding,
            vertical: AppTheme.cardSpacing / 2,
          ));
    });

    testWidgets('animates shadow on hover', (tester) async {
      controller = AnimatedModalItemController(
        vsync: const TestVSync(),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: AnimatedModalItem(
              controller: controller,
              onTap: () {},
              hoverElevation: 8, // Custom elevation
              child: const Text('Shadow Test'),
            ),
          ),
        ),
      );

      // Verify shadow animation setup
      expect(controller.hoverValue, 0.0);

      // Trigger hover
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.text('Shadow Test')));
      await tester.pump();

      // Animation should start
      expect(controller.hoverAnimationController.isAnimating, true);

      // Let animation progress and check shadow changes
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.hoverValue, greaterThan(0.0));

      // AnimatedContainer will handle the shadow animation
      // We just verify that the hover animation is working
      final animatedContainer = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      expect(animatedContainer.duration, const Duration(milliseconds: 200));

      // Clean up - move mouse away and let animations complete
      await gesture.moveTo(const Offset(500, 500));
      await tester.pumpAndSettle();
    });

    testWidgets('respects custom animation parameters', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItem(
              onTap: () {},
              hoverScale: 0.95,
              tapScale: 0.90,
              tapOpacity: 0.6,
              hoverElevation: 10,
              child: const Text('Custom'),
            ),
          ),
        ),
      );

      expect(find.text('Custom'), findsOneWidget);
      // The actual animation values would be tested through the controller
    });

    testWidgets('handles simultaneous hover and tap', (tester) async {
      controller = AnimatedModalItemController(
        vsync: const TestVSync(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItem(
              controller: controller,
              onTap: () {},
              child: const Text('Multi Action'),
            ),
          ),
        ),
      );

      // Start hover
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.text('Multi Action')));
      await tester.pump();

      // Let hover animation progress
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.hoverValue, greaterThan(0.0));

      // Add tap while hovering
      await gesture.down(tester.getCenter(find.text('Multi Action')));
      await tester.pump();

      // Let tap animation progress
      await tester.pump(const Duration(milliseconds: 75));
      expect(controller.hoverValue, greaterThan(0.0));
      expect(controller.tapValue, greaterThan(0.0));

      // Release tap
      await gesture.up();
      await tester.pump();

      // Tap should reverse while hover continues
      await tester.pump(const Duration(milliseconds: 75));
      expect(controller.hoverValue, greaterThan(0.0));
      expect(controller.tapValue, lessThan(1.0)); // Animation reversing

      // Clean up - move mouse away and let animations complete
      await gesture.moveTo(const Offset(500, 500));
      await tester.pumpAndSettle();
    });

    testWidgets('cleans up resources on dispose', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItem(
              onTap: () {},
              child: const Text('Dispose Test'),
            ),
          ),
        ),
      );

      expect(find.text('Dispose Test'), findsOneWidget);

      // Replace with empty container to trigger dispose
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(),
          ),
        ),
      );

      // Allow animations to complete before checking
      await tester.pumpAndSettle();

      expect(find.text('Dispose Test'), findsNothing);
    });
  });
}
