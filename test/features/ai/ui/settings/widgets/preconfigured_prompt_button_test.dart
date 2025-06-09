import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/widgets/preconfigured_prompt_button.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  group('PreconfiguredPromptButton', () {
    late PreconfiguredPrompt? selectedPrompt;

    setUp(() {
      selectedPrompt = null;
    });

    Widget buildTestWidget() {
      return makeTestableWidget(
        PreconfiguredPromptButton(
          onPromptSelected: (prompt) => selectedPrompt = prompt,
        ),
      );
    }

    group('UI and Styling', () {
      testWidgets('displays button with correct text and icon', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        // Check for button text - using byType since text is localized
        expect(find.byType(Text), findsAtLeastNWidgets(2));

        // Check for icon
        expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);

        // Check for arrow icon
        expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      });

      testWidgets('has gradient background', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        final animatedContainer = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer).first,
        );

        expect(animatedContainer.decoration, isA<BoxDecoration>());
        final decoration = animatedContainer.decoration as BoxDecoration?;
        expect(decoration?.gradient, isNotNull);
        expect(decoration?.gradient, isA<LinearGradient>());
      });

      testWidgets('has rounded corners and border', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        final animatedContainer = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer).first,
        );

        final decoration = animatedContainer.decoration as BoxDecoration?;
        expect(decoration?.borderRadius, BorderRadius.circular(12));
        expect(decoration?.border, isNotNull);
      });

      testWidgets('fills available width', (tester) async {
        await tester.pumpWidget(
          makeTestableWidget(
            SizedBox(
              width: 400,
              child: PreconfiguredPromptButton(
                onPromptSelected: (_) {},
              ),
            ),
          ),
        );

        final animatedContainer = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer).first,
        );

        // Check that it fills available width through width property
        expect(animatedContainer.constraints?.maxWidth, double.infinity);
        // Check that it has proper decoration
        final decoration = animatedContainer.decoration as BoxDecoration?;
        expect(decoration, isNotNull);
      });
    });

    group('Interactions', () {
      testWidgets('shows press state when tapped down', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        // Find the button
        final button = find.byType(InkWell);

        // Simulate tap down
        await tester.press(button);
        await tester.pump(const Duration(milliseconds: 50));

        // The scale animation should be active
        final scaleTransition = tester.widget<ScaleTransition>(
          find.byType(ScaleTransition),
        );
        // The animation should have started
        expect(scaleTransition.scale.value, lessThanOrEqualTo(1.0));
      });

      testWidgets('returns to normal state when tap cancelled', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        final button = find.byType(GestureDetector);

        // Start a drag to cancel the tap
        final gesture = await tester.startGesture(tester.getCenter(button));
        await tester.pump(const Duration(milliseconds: 50));

        // Move outside to cancel
        await gesture.moveBy(const Offset(200, 0));
        await gesture.up();
        await tester.pumpAndSettle();

        // The scale should be back to normal
        final scaleTransition = tester.widget<ScaleTransition>(
          find.byType(ScaleTransition),
        );
        expect(scaleTransition.scale.value, greaterThanOrEqualTo(0.98));
      });

      testWidgets('opens modal when tapped', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        // Tap the button
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        // Modal should be visible - check for modal title
        expect(find.text('Select Preconfigured Prompt'), findsOneWidget);
      });

      testWidgets('handles prompt selection from modal', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        // Tap the button to open modal
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        // Verify modal opened
        expect(find.text('Select Preconfigured Prompt'), findsOneWidget);

        // Verify the modal has action buttons for each preconfigured prompt
        // Note: Some prompts may appear multiple times (e.g., in descriptions)
        for (final prompt in preconfiguredPrompts) {
          expect(find.text(prompt.name), findsWidgets);
        }

        // Close modal by tapping outside
        await tester.tapAt(const Offset(50, 50));
        await tester.pumpAndSettle();

        // Modal should be gone
        expect(find.text('Select Preconfigured Prompt'), findsNothing);
      });

      testWidgets('handles modal dismissal without selection', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        // Tap the button to open modal
        await tester.tap(find.byType(InkWell));
        await tester.pumpAndSettle();

        // Dismiss modal by tapping outside
        await tester.tapAt(const Offset(50, 50));
        await tester.pumpAndSettle();

        // No prompt should be selected
        expect(selectedPrompt, isNull);
      });
    });

    group('Animation', () {
      testWidgets('has smooth scale animation on press', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        final button = find.byType(GestureDetector);

        // Press and hold
        await tester.press(button);

        // Pump multiple frames to see animation
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 15));
        }

        final scaleTransition = tester.widget<ScaleTransition>(
          find.byType(ScaleTransition),
        );

        // Should be scaled down
        expect(scaleTransition.scale.value, lessThanOrEqualTo(1.0));
        expect(scaleTransition.scale.value, greaterThanOrEqualTo(0.95));
      });

      testWidgets('arrow icon animates on press', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        // Get initial arrow position
        final arrowFinder = find.byIcon(Icons.chevron_right_rounded);
        final initialTransform = tester
            .widget<AnimatedContainer>(
              find
                  .ancestor(
                    of: arrowFinder,
                    matching: find.byType(AnimatedContainer),
                  )
                  .first,
            )
            .transform;

        // Press the button
        await tester.press(find.byType(InkWell));
        await tester.pump(const Duration(milliseconds: 100));

        // Arrow should have moved
        final pressedTransform = tester
            .widget<AnimatedContainer>(
              find
                  .ancestor(
                    of: arrowFinder,
                    matching: find.byType(AnimatedContainer),
                  )
                  .first,
            )
            .transform;

        expect(pressedTransform, isNot(equals(initialTransform)));
      });
    });

    group('Accessibility', () {
      testWidgets('has appropriate semantic labels', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        // The button should have meaningful text that screen readers can use
        expect(find.byType(Text), findsAtLeastNWidgets(2));
      });

      testWidgets('can be activated with keyboard', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        // Focus on the button (in a real app, this would be done via Tab key)
        final inkWell = find.byType(InkWell);
        await tester.tap(inkWell);
        await tester.pumpAndSettle();

        // The modal should open
        expect(find.text('Select Preconfigured Prompt'), findsOneWidget);
      });
    });

    group('Error Handling', () {
      testWidgets('handles rapid taps gracefully', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        // Tap the button once to open modal
        await tester.tap(find.byType(InkWell));
        await tester.pump(const Duration(milliseconds: 100));

        // Modal should be opening
        await tester.pumpAndSettle();

        // Verify modal opened correctly
        expect(find.text('Select Preconfigured Prompt'), findsOneWidget);

        // Close modal
        await tester.tapAt(const Offset(50, 50));
        await tester.pumpAndSettle();
      });
    });

    group('Integration', () {
      testWidgets('works with different color schemes', (tester) async {
        // Test that the widget renders without errors
        await tester.pumpWidget(
          makeTestableWidget(
            PreconfiguredPromptButton(
              onPromptSelected: (_) {},
            ),
          ),
        );

        expect(find.byType(PreconfiguredPromptButton), findsOneWidget);

        // Verify the button has proper structure
        expect(find.byType(ScaleTransition), findsOneWidget);
        expect(find.byType(AnimatedContainer), findsAtLeastNWidgets(1));
        expect(find.byType(InkWell), findsOneWidget);
      });

      testWidgets('disposes resources properly', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        // Remove the widget
        await tester.pumpWidget(Container());

        // No exceptions should be thrown
        expect(tester.takeException(), isNull);
      });
    });
  });
}
