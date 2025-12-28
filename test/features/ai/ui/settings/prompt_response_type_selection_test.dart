import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/settings/prompt_response_type_selection.dart';

import '../../../../test_helper.dart';

void main() {
  group('ResponseTypeSelectionModal', () {
    testWidgets('displays all response type options with correct icons',
        (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ResponseTypeSelectionModal(
                selectedType: null,
                onSave: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all response types are displayed (using localized names from extension)
      expect(find.text('Task Summary'), findsOneWidget);
      expect(find.text('Image Analysis'), findsOneWidget);
      expect(find.text('Audio Transcription'), findsOneWidget);
      expect(find.text('Checklist Updates'), findsOneWidget);
      expect(find.text('Generated Prompt'), findsOneWidget);
      expect(find.text('Image Prompt'), findsOneWidget);

      // Verify icons are displayed for each type
      expect(find.byIcon(Icons.summarize_rounded), findsOneWidget);
      expect(find.byIcon(Icons.image_search_rounded), findsOneWidget);
      expect(find.byIcon(Icons.transcribe_rounded), findsOneWidget);
      expect(find.byIcon(Icons.checklist_rtl_rounded), findsOneWidget);
      expect(find.byIcon(Icons.auto_fix_high_outlined), findsOneWidget);
      expect(find.byIcon(Icons.palette_outlined), findsOneWidget);
    });

    testWidgets('imagePromptGeneration shows palette icon when selected',
        (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ResponseTypeSelectionModal(
                selectedType: AiResponseType.imagePromptGeneration,
                onSave: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the palette icon is displayed for image prompt generation
      expect(find.byIcon(Icons.palette_outlined), findsOneWidget);
      // Verify Image Prompt text is shown
      expect(find.text('Image Prompt'), findsOneWidget);
    });

    testWidgets('selects type when option is tapped', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ResponseTypeSelectionModal(
                selectedType: null,
                onSave: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially no selection indicator should show the inner circle
      // (RadioSelectionIndicator shows inner circle only when selected)
      var selectedIndicators = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).shape == BoxShape.circle &&
            widget.constraints?.maxWidth == 10,
      );
      expect(selectedIndicators, findsNothing);

      // Tap on Task Summary option
      await tester.tap(find.text('Task Summary'));
      await tester.pump();

      // Now one selection indicator should show the inner circle
      selectedIndicators = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).shape == BoxShape.circle &&
            widget.constraints?.maxWidth == 10,
      );
      expect(selectedIndicators, findsOneWidget);
    });

    testWidgets('shows preselected type as selected', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ResponseTypeSelectionModal(
                selectedType: AiResponseType.promptGeneration,
                onSave: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // One selection indicator should show the inner circle for the preselected type
      final selectedIndicators = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).shape == BoxShape.circle &&
            widget.constraints?.maxWidth == 10,
      );
      expect(selectedIndicators, findsOneWidget);
    });
  });
}
