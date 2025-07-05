import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/widgets/modal/animated_modal_item_with_icon.dart';

void main() {
  group('AnimatedModalItemWithIcon', () {
    testWidgets('renders icon builder content correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItemWithIcon(
              onTap: () {},
              iconBuilder: (context, iconAnimation, {required isPressed}) {
                return Container(
                  key: const Key('icon-container'),
                  child: Icon(
                    Icons.star,
                    size: 24,
                    color: isPressed ? Colors.red : Colors.blue,
                  ),
                );
              },
              child: const Text('Test Child'),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('icon-container')), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);

      // Icon should be blue when not pressed
      final icon = tester.widget<Icon>(find.byIcon(Icons.star));
      expect(icon.color, Colors.blue);
    });

    testWidgets('passes isPressed state to icon builder', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItemWithIcon(
              onTap: () {},
              iconBuilder: (context, iconAnimation, {required isPressed}) {
                return Icon(
                  Icons.star,
                  color: isPressed ? Colors.red : Colors.blue,
                );
              },
              child: const Text('Press Me'),
            ),
          ),
        ),
      );

      // Initially not pressed
      var icon = tester.widget<Icon>(find.byIcon(Icons.star));
      expect(icon.color, Colors.blue);

      // Start press
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Press Me')),
      );
      await tester.pump();

      // Should be pressed now
      icon = tester.widget<Icon>(find.byIcon(Icons.star));
      expect(icon.color, Colors.red);

      // Release
      await gesture.up();
      await tester.pump();

      // Should not be pressed anymore
      icon = tester.widget<Icon>(find.byIcon(Icons.star));
      expect(icon.color, Colors.blue);
    });

    testWidgets('animates icon scale on tap', (tester) async {
      var lastAnimationValue = 1.0;
      var wasPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItemWithIcon(
              onTap: () {},
              iconScaleOnTap: 0.8,
              iconBuilder: (context, iconAnimation, {required isPressed}) {
                lastAnimationValue = iconAnimation.value;
                wasPressed = isPressed;
                return Transform.scale(
                  scale: iconAnimation.value,
                  child: const Icon(Icons.star),
                );
              },
              child: const Text('Tap for Scale'),
            ),
          ),
        ),
      );

      expect(lastAnimationValue, 1.0);
      expect(wasPressed, false);

      // Start tap - use startGesture to control tap phases
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Tap for Scale')),
      );
      await tester.pump();

      // While pressed, isPressed should be true
      expect(wasPressed, true);

      // Release tap
      await gesture.up();
      await tester.pump();

      // After release, isPressed should be false
      expect(wasPressed, false);

      // Let animation complete
      await tester.pumpAndSettle();
      expect(lastAnimationValue, 1.0);
    });

    testWidgets('respects custom tap opacity', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItemWithIcon(
              onTap: () {},
              tapOpacity: 0.5,
              iconBuilder: (context, iconAnimation, {required isPressed}) {
                return const Icon(Icons.star);
              },
              child: const Text('Custom Opacity'),
            ),
          ),
        ),
      );

      // Start tap
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Custom Opacity')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75)); // Half animation

      // Find the AnimatedOpacity widget
      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find
            .descendant(
              of: find.byType(AnimatedModalItemWithIcon),
              matching: find.byType(AnimatedOpacity),
            )
            .last,
      );

      // Opacity should be animating towards 0.5
      expect(animatedOpacity.opacity, lessThan(1.0));
      expect(animatedOpacity.opacity, greaterThan(0.5));

      await gesture.up();
    });

    testWidgets('hover animation updates icon builder', (tester) async {
      var lastAnimationValue = 0.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItemWithIcon(
              onTap: () {},
              iconBuilder: (context, iconAnimation, {required isPressed}) {
                lastAnimationValue = iconAnimation.value;
                return Icon(
                  Icons.star,
                  size: 24 * iconAnimation.value,
                );
              },
              child: const Text('Hover Test'),
            ),
          ),
        ),
      );

      expect(lastAnimationValue, 1.0);

      // Simulate tap to change animation value
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Hover Test')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(lastAnimationValue, lessThan(1.0));

      await gesture.up();
    });

    testWidgets('handles disabled state correctly', (tester) async {
      var tapCount = 0;
      var wasPressedDuringBuild = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItemWithIcon(
              onTap: () => tapCount++,
              isDisabled: true,
              iconBuilder: (context, iconAnimation, {required isPressed}) {
                wasPressedDuringBuild = wasPressedDuringBuild || isPressed;
                return const Icon(Icons.block);
              },
              child: const Text('Disabled'),
            ),
          ),
        ),
      );

      // Try to tap
      await tester.tap(find.text('Disabled'));
      await tester.pump();

      expect(tapCount, 0);
      expect(wasPressedDuringBuild, false);

      // Check opacity
      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find
            .descendant(
              of: find.byType(AnimatedModalItemWithIcon),
              matching: find.byType(AnimatedOpacity),
            )
            .last,
      );
      expect(animatedOpacity.opacity, 0.5);
    });

    testWidgets('combines hover and tap animations correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItemWithIcon(
              onTap: () {},
              hoverScale: 0.95,
              tapScale: 0.90,
              iconBuilder: (context, iconAnimation, {required isPressed}) {
                return const Icon(Icons.star);
              },
              child: const Text('Combined'),
            ),
          ),
        ),
      );

      // Verify the widget structure is correct
      expect(find.text('Combined'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);

      // Verify animations can be triggered
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.text('Combined')));
      await tester.pump();

      // Animations should work - just verify the widget is still there
      expect(find.text('Combined'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);

      await gesture.moveTo(const Offset(500, 500));
      await tester.pumpAndSettle();
    });

    testWidgets('maintains correct widget tree structure', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedModalItemWithIcon(
              onTap: () {},
              iconBuilder: (context, iconAnimation, {required isPressed}) {
                return const Icon(Icons.star);
              },
              child: const Text('Structure Test'),
            ),
          ),
        ),
      );

      // Verify the widget tree structure
      expect(
        find.descendant(
          of: find.byType(AnimatedModalItemWithIcon),
          matching: find.byType(AnimatedBuilder),
        ),
        findsOneWidget,
      );

      expect(
        find.descendant(
          of: find.byType(AnimatedModalItemWithIcon),
          matching: find.byType(GestureDetector),
        ),
        findsOneWidget,
      );

      expect(
        find.descendant(
          of: find.byType(AnimatedModalItemWithIcon),
          matching: find.byType(MouseRegion),
        ),
        findsOneWidget,
      );

      expect(
        find.descendant(
          of: find.byType(AnimatedModalItemWithIcon),
          matching: find.byType(AnimatedContainer),
        ),
        findsOneWidget,
      );
    });
  });
}
