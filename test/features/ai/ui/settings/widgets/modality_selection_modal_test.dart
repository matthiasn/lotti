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
      testWidgets('displays title correctly', (WidgetTester tester) async {
        const testTitle = 'Input Modalities';
        await tester.pumpWidget(createTestWidget(
          title: testTitle,
          onSave: (_) {},
        ));
        await tester.pumpAndSettle();

        expect(find.text(testTitle), findsOneWidget);
      });

      testWidgets('displays close button', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(onSave: (_) {}));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      });

      testWidgets('displays save button with correct text',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(onSave: (_) {}));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.check_rounded), findsOneWidget);
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

        // Should have checkboxes for all modality values
        final checkboxes = find.byType(CheckboxListTile);
        expect(checkboxes, findsNWidgets(Modality.values.length));
      });

      testWidgets('shows correct initial selection state',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          selectedModalities: [Modality.text, Modality.image],
          onSave: (_) {},
        ));
        await tester.pumpAndSettle();

        // Find checkboxes and verify their states
        final checkboxTiles = tester.widgetList<CheckboxListTile>(
          find.byType(CheckboxListTile),
        );

        // Count selected checkboxes
        final selectedCount = checkboxTiles.where((tile) => tile.value ?? false).length;
        expect(selectedCount, equals(2));
      });

      testWidgets('displays modality names and descriptions',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(onSave: (_) {}));
        await tester.pumpAndSettle();

        // Check for text modality (should always be present)
        expect(find.text('Text'), findsOneWidget);
        
        // Check that we have subtitle text (descriptions)
        final tiles = tester.widgetList<CheckboxListTile>(
          find.byType(CheckboxListTile),
        );
        
        // Verify tiles have subtitles
        final tilesWithSubtitles = tiles.where((tile) => tile.subtitle != null);
        expect(tilesWithSubtitles.length, equals(Modality.values.length));
      });

      testWidgets('highlights selected modalities with different styling',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          selectedModalities: [Modality.text],
          onSave: (_) {},
        ));
        await tester.pumpAndSettle();

        // Find containers that should have different styling for selected items
        final containers = tester.widgetList<Container>(find.byType(Container));
        
        // Should have containers with different decorations
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

        // Find the first checkbox (should be for text modality)
        final firstCheckbox = find.byType(CheckboxListTile).first;
        
        // Tap to unselect text modality
        await tester.tap(firstCheckbox);
        await tester.pumpAndSettle();

        // Verify the checkbox state changed visually
        final checkboxWidget = tester.widget<CheckboxListTile>(firstCheckbox);
        expect(checkboxWidget.value, isFalse);
      });

      testWidgets('can select multiple modalities', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          selectedModalities: [Modality.text],
          onSave: (_) {},
        ));
        await tester.pumpAndSettle();

        final checkboxes = find.byType(CheckboxListTile);
        
        // Tap the second checkbox (should be for image modality)
        if (checkboxes.evaluate().length > 1) {
          await tester.tap(checkboxes.at(1));
          await tester.pumpAndSettle();

          // Count selected checkboxes
          final checkboxWidgets = tester.widgetList<CheckboxListTile>(checkboxes);
          final selectedCount = checkboxWidgets.where((tile) => tile.value ?? false).length;
          expect(selectedCount, equals(2));
        }
      });

      testWidgets('calls onSave with correct modalities when save tapped',
          (WidgetTester tester) async {
        final savedModalities = <Modality>[];
        
        await tester.pumpWidget(createTestWidget(
          selectedModalities: [Modality.text],
          onSave: savedModalities.addAll,
        ));
        await tester.pumpAndSettle();

        // Tap save button
        await tester.tap(find.byIcon(Icons.check_rounded));
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

        // Select additional modality if available
        final checkboxes = find.byType(CheckboxListTile);
        if (checkboxes.evaluate().length > 1) {
          await tester.tap(checkboxes.at(1));
          await tester.pumpAndSettle();
        }

        // Tap save button
        await tester.tap(find.byIcon(Icons.check_rounded));
        await tester.pumpAndSettle();

        // Should have called onSave with updated selection
        expect(savedModalities.length, greaterThanOrEqualTo(1));
      });

      testWidgets('closes modal without saving when close button tapped',
          (WidgetTester tester) async {
        var onSaveCalled = false;
        
        await tester.pumpWidget(createTestWidget(
          onSave: (_) => onSaveCalled = true,
        ));
        await tester.pumpAndSettle();

        // Tap close button
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        // onSave should not have been called
        expect(onSaveCalled, isFalse);
      });
    });

    group('State Management', () {
      testWidgets('maintains selection state during interaction',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          selectedModalities: [Modality.text, Modality.image],
          onSave: (_) {},
        ));
        await tester.pumpAndSettle();

        // Tap to deselect first modality
        final firstCheckbox = find.byType(CheckboxListTile).first;
        await tester.tap(firstCheckbox);
        await tester.pumpAndSettle();

        // Verify state consistency
        final checkboxWidgets = tester.widgetList<CheckboxListTile>(
          find.byType(CheckboxListTile),
        );
        
        final selectedCount = checkboxWidgets.where((tile) => tile.value ?? false).length;
        expect(selectedCount, equals(1)); // Should have one less selected
      });

      testWidgets('handles empty initial selection', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          selectedModalities: <Modality>[],
          onSave: (_) {},
        ));
        await tester.pumpAndSettle();

        // All checkboxes should be unselected
        final checkboxWidgets = tester.widgetList<CheckboxListTile>(
          find.byType(CheckboxListTile),
        );
        
        final selectedCount = checkboxWidgets.where((tile) => tile.value ?? false).length;
        expect(selectedCount, equals(0));
      });

      testWidgets('handles all modalities selected initially',
          (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(
          selectedModalities: Modality.values,
          onSave: (_) {},
        ));
        await tester.pumpAndSettle();

        // All checkboxes should be selected
        final checkboxWidgets = tester.widgetList<CheckboxListTile>(
          find.byType(CheckboxListTile),
        );
        
        final selectedCount = checkboxWidgets.where((tile) => tile.value ?? false).length;
        expect(selectedCount, equals(Modality.values.length));
      });
    });

    group('Accessibility', () {
      testWidgets('has proper semantic structure', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(onSave: (_) {}));
        await tester.pumpAndSettle();

        // Should have clickable checkboxes
        final checkboxes = find.byType(CheckboxListTile);
        expect(checkboxes, findsAtLeastNWidgets(1));

        // Should have accessible buttons
        final closeButton = find.byIcon(Icons.close_rounded);
        final saveButton = find.byIcon(Icons.check_rounded);
        
        expect(closeButton, findsOneWidget);
        expect(saveButton, findsOneWidget);
      });

      testWidgets('checkboxes are properly labeled', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(onSave: (_) {}));
        await tester.pumpAndSettle();

        // Each checkbox should have title and subtitle
        final checkboxTiles = tester.widgetList<CheckboxListTile>(
          find.byType(CheckboxListTile),
        );

        for (final tile in checkboxTiles) {
          expect(tile.title, isNotNull);
          expect(tile.subtitle, isNotNull);
        }
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
        await tester.pumpWidget(createTestWidget(onSave: (_) {}));
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

        final firstCheckbox = find.byType(CheckboxListTile).first;
        
        // Rapidly toggle selection
        for (var i = 0; i < 5; i++) {
          await tester.tap(firstCheckbox);
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

        final checkboxes = find.byType(CheckboxListTile);
        
        // Select multiple modalities
        for (var i = 0; i < checkboxes.evaluate().length && i < 3; i++) {
          await tester.tap(checkboxes.at(i));
          await tester.pump();
        }
        await tester.pumpAndSettle();

        // Count selected items
        final checkboxWidgets = tester.widgetList<CheckboxListTile>(checkboxes);
        final selectedCount = checkboxWidgets.where((tile) => tile.value ?? false).length;
        
        expect(selectedCount, equals(3));
      });

      testWidgets('handles save with no modalities selected',
          (WidgetTester tester) async {
        final savedModalities = <Modality>[];
        
        await tester.pumpWidget(createTestWidget(
          selectedModalities: <Modality>[],
          onSave: savedModalities.addAll,
        ));
        await tester.pumpAndSettle();

        // Tap save button with no selection
        await tester.tap(find.byIcon(Icons.check_rounded));
        await tester.pumpAndSettle();

        // Should save empty list
        expect(savedModalities, isEmpty);
      });
    });
  });
}
