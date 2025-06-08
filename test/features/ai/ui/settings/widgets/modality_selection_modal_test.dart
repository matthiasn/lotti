import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/widgets/modality_selection_modal.dart';

import '../../../test_utils.dart';

void main() {
  group('ModalitySelectionModal', () {
    setUpAll(AiTestSetup.registerFallbackValues);

    Widget createTestWidget({
      required ValueChanged<List<Modality>> onSave,
      String title = 'Select Modalities',
      List<Modality> selectedModalities = const [Modality.text],
    }) {
      return AiTestWidgets.createTestWidget(
        child: Scaffold(
          body: ModalitySelectionModal(
            title: title,
            selectedModalities: selectedModalities,
            onSave: onSave,
          ),
        ),
      );
    }

    group('Modal Structure', () {
      testWidgets('displays modal content correctly', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          onSave: (_) {},
        ));
        await tester.pumpAndSettle();

        // The modal content should render (title is now in Wolt header)
        expect(find.byType(ModalitySelectionModal), findsOneWidget);
      });

      testWidgets('has proper widget structure', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(onSave: (_) {}));
        await tester.pumpAndSettle();

        // Should have proper structure with padding and columns
        expect(find.byType(ModalitySelectionModal), findsOneWidget);
        expect(find.byType(Padding), findsAtLeastNWidgets(1));
      });

      testWidgets('displays save button with correct text',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          onSave: (_) {},
          selectedModalities: [], // No selections, so only save button has check icon
        ));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.check_rounded), findsOneWidget); // Only save button
        expect(find.text('Save'), findsOneWidget);
      });

      testWidgets('has proper modal styling', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(onSave: (_) {}));
        await tester.pumpAndSettle();

        // Check for rounded corners container
        final containers = find.byType(Container);
        expect(containers, findsAtLeastNWidgets(1));

        // Check for ListView with modality options
        expect(find.byType(ListView), findsOneWidget);
      });
    });

    group('Modality Options Display', () {
      testWidgets('displays all modality options', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(onSave: (_) {}));
        await tester.pumpAndSettle();

        // Should have text for all modalities
        expect(find.text('Text'), findsOneWidget);
        expect(find.text('Image'), findsOneWidget);
        expect(find.text('Audio'), findsOneWidget);
        
        // Should have icons for all modalities
        expect(find.byIcon(Icons.text_format_rounded), findsOneWidget);
        expect(find.byIcon(Icons.image_rounded), findsOneWidget);
        expect(find.byIcon(Icons.audio_file_rounded), findsOneWidget);
      });

      testWidgets('shows correct initial selection state',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          selectedModalities: [Modality.text, Modality.image],
          onSave: (_) {},
        ));
        await tester.pumpAndSettle();

        // Should show checkmarks for selected modalities (plus one in save button)
        final checkmarkIcons = find.byIcon(Icons.check_rounded);
        expect(checkmarkIcons, findsNWidgets(3)); // text, image selected + save button
      });

      testWidgets('displays modality names and descriptions',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(onSave: (_) {}));
        await tester.pumpAndSettle();

        // Check for text modality (should always be present)
        expect(find.text('Text'), findsOneWidget);
        
        // Should have modality cards with proper icons
        expect(find.byIcon(Icons.text_format_rounded), findsOneWidget);
        expect(find.byIcon(Icons.image_rounded), findsOneWidget);
        expect(find.byIcon(Icons.audio_file_rounded), findsOneWidget);
      });

      testWidgets('highlights selected modalities with different styling',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          selectedModalities: [Modality.text],
          onSave: (_) {},
        ));
        await tester.pumpAndSettle();

        // Should show checkmark for selected modality (plus one in save button)
        expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
        
        // Should have styled containers with decorations
        final containers = tester.widgetList<Container>(find.byType(Container));
        expect(containers.length, greaterThan(3));
      });
    });

    group('User Interactions', () {
      testWidgets('toggles modality selection when tapped',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          selectedModalities: [Modality.text],
          onSave: (_) {},
        ));
        await tester.pumpAndSettle();

        // Initially should have one checkmark (for text) plus save button
        expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));

        // Find and tap the Text modality card to unselect it
        final textCard = find.ancestor(
          of: find.text('Text'),
          matching: find.byType(InkWell),
        );
        await tester.tap(textCard);
        await tester.pumpAndSettle();

        // Should now have only save button checkmark (text unselected)
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      });

      testWidgets('can select multiple modalities', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          selectedModalities: [Modality.text],
          onSave: (_) {},
        ));
        await tester.pumpAndSettle();

        // Initially should have one checkmark plus save button
        expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
        
        // Find and tap the Image modality card to select it
        final imageCard = find.ancestor(
          of: find.text('Image'),
          matching: find.byType(InkWell),
        );
        await tester.tap(imageCard);
        await tester.pumpAndSettle();

        // Should now have three checkmarks (text, image selected + save button)
        expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
      });

      testWidgets('calls onSave with correct modalities when save tapped',
          (WidgetTester tester) async {
        final savedModalities = <Modality>[];
        
        await tester.pumpWidget(createTestWidget(
          selectedModalities: [Modality.text],
          onSave: savedModalities.addAll,
        ));
        await tester.pumpAndSettle();

        // Tap save button by text
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Verify callback was called with initial selection
        expect(savedModalities, contains(Modality.text));
      });

      testWidgets('calls onSave with updated modalities after changes',
          (WidgetTester tester) async {
        final savedModalities = <Modality>[];
        
        await tester.pumpWidget(createTestWidget(
          selectedModalities: [Modality.text],
          onSave: savedModalities.addAll,
        ));
        await tester.pumpAndSettle();

        // Find and tap the Image modality card to select it
        final imageCard = find.ancestor(
          of: find.text('Image'),
          matching: find.byType(InkWell),
        );
        await tester.tap(imageCard);
        await tester.pumpAndSettle();

        // Tap save button by text
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Should have called onSave with updated selection
        expect(savedModalities.length, greaterThanOrEqualTo(1));
      });

      // Note: Close button test is not applicable since the close button is part of
      // the Wolt modal wrapper, not the ModalitySelectionModal widget itself.
    });

    group('State Management', () {
      testWidgets('maintains selection state during interaction',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          selectedModalities: [Modality.text, Modality.image],
          onSave: (_) {},
        ));
        await tester.pumpAndSettle();

        // Initially should have two checkmarks (for text and image) plus save button
        expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));

        // Tap to deselect text modality
        final textCard = find.ancestor(
          of: find.text('Text'),
          matching: find.byType(InkWell),
        );
        await tester.tap(textCard);
        await tester.pumpAndSettle();

        // Should now have one checkmark (image) plus save button
        expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
      });

      testWidgets('handles empty initial selection', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          selectedModalities: <Modality>[],
          onSave: (_) {},
        ));
        await tester.pumpAndSettle();

        // Should only have save button checkmark, no selected modalities
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
        
        // Should have all modality text labels visible
        expect(find.text('Text'), findsOneWidget);
        expect(find.text('Image'), findsOneWidget);
        expect(find.text('Audio'), findsOneWidget);
      });

      testWidgets('handles all modalities selected initially',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          selectedModalities: Modality.values,
          onSave: (_) {},
        ));
        await tester.pumpAndSettle();

        // Should have checkmarks for all modalities plus save button
        expect(find.byIcon(Icons.check_rounded), findsNWidgets(Modality.values.length + 1));
      });
    });

    group('Accessibility', () {
      testWidgets('has proper semantic structure', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(onSave: (_) {}));
        await tester.pumpAndSettle();

        // Should have clickable InkWell areas
        final inkWells = find.byType(InkWell);
        expect(inkWells, findsAtLeastNWidgets(3)); // One for each modality

        // Should have save button (close button is part of Wolt modal wrapper)
        final saveButton = find.byIcon(Icons.check_rounded);
        expect(saveButton, findsAtLeastNWidgets(1)); // At least one for save button
      });

      testWidgets('modality options are properly labeled', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(onSave: (_) {}));
        await tester.pumpAndSettle();

        // Should have text labels for all modalities
        expect(find.text('Text'), findsOneWidget);
        expect(find.text('Image'), findsOneWidget);
        expect(find.text('Audio'), findsOneWidget);
        
        // Should have icons for all modalities
        expect(find.byIcon(Icons.text_format_rounded), findsOneWidget);
        expect(find.byIcon(Icons.image_rounded), findsOneWidget);
        expect(find.byIcon(Icons.audio_file_rounded), findsOneWidget);
      });
    });

    group('Visual Design', () {
      testWidgets('uses proper spacing and layout', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(onSave: (_) {}));
        await tester.pumpAndSettle();

        // Should have proper spacing with SizedBox widgets
        expect(find.byType(SizedBox), findsAtLeastNWidgets(1));

        // Should have proper padding
        expect(find.byType(Padding), findsAtLeastNWidgets(1));
      });

      testWidgets('has consistent visual hierarchy', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          selectedModalities: <Modality>[], // No selections to avoid multiple checkmarks
          onSave: (_) {},
        ));
        await tester.pumpAndSettle();

        // Should have header, content, and footer sections
        expect(find.byType(Column), findsAtLeastNWidgets(1));
        expect(find.byType(ListView), findsOneWidget);
        // Save button is an ElevatedButton.icon inside the component
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      });

      testWidgets('applies proper theming', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(onSave: (_) {}));
        await tester.pumpAndSettle();

        // Should have styled containers with decorations
        final containers = tester.widgetList<Container>(find.byType(Container));
        final styledContainers = containers.where(
          (container) => container.decoration != null,
        );
        
        expect(styledContainers.length, greaterThan(0));
      });
    });

    group('Edge Cases', () {
      testWidgets('handles rapid selection changes', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          selectedModalities: [Modality.text],
          onSave: (_) {},
        ));
        await tester.pumpAndSettle();

        final textCard = find.ancestor(
          of: find.text('Text'),
          matching: find.byType(InkWell),
        );
        
        // Rapidly toggle selection
        for (var i = 0; i < 5; i++) {
          await tester.tap(textCard);
          await tester.pump();
        }
        await tester.pumpAndSettle();

        // Should still be responsive and not crash
        expect(find.byType(ModalitySelectionModal), findsOneWidget);
      });

      testWidgets('maintains state consistency after multiple changes',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          selectedModalities: <Modality>[],
          onSave: (_) {},
        ));
        await tester.pumpAndSettle();

        // Select all three modalities
        final textCard = find.ancestor(
          of: find.text('Text'),
          matching: find.byType(InkWell),
        );
        final imageCard = find.ancestor(
          of: find.text('Image'),
          matching: find.byType(InkWell),
        );
        final audioCard = find.ancestor(
          of: find.text('Audio'),
          matching: find.byType(InkWell),
        );
        
        await tester.tap(textCard);
        await tester.pump();
        await tester.tap(imageCard);
        await tester.pump();
        await tester.tap(audioCard);
        await tester.pump();
        await tester.pumpAndSettle();

        // Should have 3 selected checkmarks plus save button
        expect(find.byIcon(Icons.check_rounded), findsNWidgets(4));
      });

      testWidgets('handles save with no modalities selected',
          (WidgetTester tester) async {
        final savedModalities = <Modality>[];
        
        await tester.pumpWidget(createTestWidget(
          selectedModalities: <Modality>[],
          onSave: savedModalities.addAll,
        ));
        await tester.pumpAndSettle();

        // Tap save button with no selection by text
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Should save empty list
        expect(savedModalities, isEmpty);
      });
    });
  });
}
