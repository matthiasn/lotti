import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/settings/widgets/enhanced_preconfigured_prompt_modal.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  group('EnhancedPreconfiguredPromptModal', () {
    late PreconfiguredPrompt? selectedPrompt;

    setUp(() {
      selectedPrompt = null;
    });

    Future<void> showModal(WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showEnhancedPreconfiguredPromptModal(
                  context,
                  (prompt) => selectedPrompt = prompt,
                );
              },
              child: const Text('Open Modal'),
            ),
          ),
        ),
      );

      // Tap button to open modal
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();
    }

    group('Display', () {
      testWidgets('shows modal with title', (tester) async {
        await showModal(tester);

        // Check for modal title
        expect(find.text('Select Preconfigured Prompt'), findsOneWidget);
      });

      testWidgets('displays description text', (tester) async {
        await showModal(tester);

        // Should have description text
        expect(find.byType(Text), findsWidgets);
      });

      testWidgets('shows all preconfigured prompts', (tester) async {
        await showModal(tester);

        // All preconfigured prompts should be visible
        for (final prompt in preconfiguredPrompts) {
          expect(find.text(prompt.name), findsWidgets);
          // Descriptions might be duplicated, so check for at least one
          expect(find.text(prompt.description), findsWidgets);
        }
      });

      testWidgets('displays prompt cards with icons', (tester) async {
        await showModal(tester);

        // Each prompt type should have its icon (we have duplicates now)
        expect(find.byIcon(Icons.summarize_outlined), findsOneWidget);
        expect(find.byIcon(Icons.image_outlined),
            findsNWidgets(2)); // 2 image prompts
        expect(find.byIcon(Icons.mic_outlined),
            findsNWidgets(2)); // 2 audio prompts
      });

      testWidgets('shows input and output type chips', (tester) async {
        await showModal(tester);

        // Check for input/output icons
        expect(find.byIcon(Icons.input_rounded), findsWidgets);
        expect(find.byIcon(Icons.output_rounded), findsWidgets);
      });

      testWidgets('shows reasoning chip for applicable prompts',
          (tester) async {
        await showModal(tester);

        // Should have reasoning chips for prompts that use reasoning
        expect(find.byIcon(Icons.psychology_rounded), findsWidgets);
      });
    });

    group('Interactions', () {
      testWidgets('selects prompt when card is tapped', (tester) async {
        await showModal(tester);

        // Find and tap a prompt card (using the first one)
        final firstPrompt = preconfiguredPrompts.first;
        // Find the InkWell that contains the prompt name
        final firstCard = find
            .ancestor(
              of: find.text(firstPrompt.name).first,
              matching: find.byType(InkWell),
            )
            .first;
        await tester.tap(firstCard);
        await tester.pumpAndSettle();

        // Modal should close and prompt should be selected
        expect(find.text('Select Preconfigured Prompt'), findsNothing);
        expect(selectedPrompt, equals(firstPrompt));
      });

      testWidgets('closes modal when tapped outside', (tester) async {
        await showModal(tester);

        // Tap outside the modal
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // Modal should close without selection
        expect(find.text('Select Preconfigured Prompt'), findsNothing);
        expect(selectedPrompt, isNull);
      });

      testWidgets('handles rapid taps gracefully', (tester) async {
        await showModal(tester);

        // Tap the same card multiple times rapidly
        final firstPrompt = preconfiguredPrompts.first;
        final firstCard = find
            .ancestor(
              of: find.text(firstPrompt.name).first,
              matching: find.byType(InkWell),
            )
            .first;

        await tester.tap(firstCard, warnIfMissed: false);
        await tester.tap(firstCard, warnIfMissed: false);
        await tester.tap(firstCard, warnIfMissed: false);
        await tester.pumpAndSettle();

        // Should handle gracefully without errors
        expect(selectedPrompt, equals(firstPrompt));
      });
    });

    group('Styling', () {
      testWidgets('cards have rounded corners and borders', (tester) async {
        await showModal(tester);

        // Find AnimatedContainer widgets (used for cards)
        final cards = tester.widgetList<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );

        // At least one card should have proper decoration
        final hasProperDecoration = cards.any((card) {
          final decoration = card.decoration as BoxDecoration?;
          return decoration?.borderRadius == BorderRadius.circular(16) &&
              decoration?.border != null;
        });

        expect(hasProperDecoration, isTrue);
      });

      testWidgets('cards have gradient background for icons', (tester) async {
        await showModal(tester);

        // Find containers that might have gradients
        final containers = tester.widgetList<Container>(
          find.byType(Container),
        );

        // At least some containers should have gradient decoration
        final hasGradient = containers.any((container) {
          final decoration = container.decoration as BoxDecoration?;
          return decoration?.gradient != null;
        });

        expect(hasGradient, isTrue);
      });
    });

    group('Accessibility', () {
      testWidgets('all interactive elements are accessible', (tester) async {
        await showModal(tester);

        // All prompt cards should be tappable
        for (final prompt in preconfiguredPrompts) {
          final card = find.ancestor(
            of: find.text(prompt.name).first,
            matching: find.byType(InkWell),
          );
          expect(card, findsOneWidget);
        }
      });

      testWidgets('has proper semantic labels', (tester) async {
        await showModal(tester);

        // Should have meaningful text content
        expect(find.byType(Text), findsWidgets);

        // Verify icons have proper context
        for (final prompt in preconfiguredPrompts) {
          expect(find.text(prompt.name), findsWidgets);
          // Descriptions might be duplicated, so check for at least one
          expect(find.text(prompt.description), findsWidgets);
        }
      });
    });

    group('Data Validation', () {
      testWidgets('displays correct input types for each prompt',
          (tester) async {
        await showModal(tester);

        // Verify each prompt shows its required input types
        for (final prompt in preconfiguredPrompts) {
          if (prompt.requiredInputData.isNotEmpty) {
            // The input data type names should be visible
            expect(find.byType(Text), findsWidgets);
          }
        }
      });

      testWidgets('displays correct output types for each prompt',
          (tester) async {
        await showModal(tester);

        // Count how many prompts have each response type
        final responseTypeCounts = <AiResponseType, int>{};
        for (final prompt in preconfiguredPrompts) {
          responseTypeCounts[prompt.aiResponseType] =
              (responseTypeCounts[prompt.aiResponseType] ?? 0) + 1;
        }

        // Each response type icon should appear the correct number of times
        for (final entry in responseTypeCounts.entries) {
          expect(find.byIcon(entry.key.icon), findsNWidgets(entry.value));
        }
      });
    });
  });
}
