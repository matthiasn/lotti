import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/settings/preconfigured_prompt_selection_modal.dart';
import 'package:lotti/features/ai/util/preconfigured_prompts.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';

// Mock for NavigatorObserver to verify navigation behavior
class MockNavigatorObserver extends Mock implements NavigatorObserver {}

// Fake Route for Mocktail fallback
class FakeRoute<T> extends Fake implements Route<T> {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeRoute<dynamic>());
  });

  Widget buildTestWidget({NavigatorObserver? navigatorObserver}) {
    return MaterialApp(
      navigatorObservers: navigatorObserver != null ? [navigatorObserver] : [],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        FormBuilderLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showPreconfiguredPromptSelectionModal(context),
            child: const Text('Show Modal'),
          ),
        ),
      ),
    );
  }

  group('showPreconfiguredPromptSelectionModal', () {
    testWidgets('displays modal with correct title',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Select Preconfigured Prompt'), findsOneWidget);
    });

    testWidgets('displays all preconfigured prompts',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Check that all preconfigured prompts are displayed
      for (final prompt in preconfiguredPrompts) {
        expect(find.text(prompt.name), findsOneWidget);
      }
    });

    testWidgets('displays correct icons for each prompt type',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Check specific icons for known prompt types
      expect(find.byIcon(Icons.summarize_outlined),
          findsOneWidget); // Task Summary
      expect(find.byIcon(Icons.checklist_outlined),
          findsOneWidget); // Action Items
      expect(
          find.byIcon(Icons.image_outlined), findsOneWidget); // Image Analysis
      expect(find.byIcon(Icons.mic_outlined),
          findsOneWidget); // Audio Transcription
    });

    testWidgets('returns selected prompt when tapped',
        (WidgetTester tester) async {
      PreconfiguredPrompt? selectedPrompt;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            FormBuilderLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selectedPrompt =
                      await showPreconfiguredPromptSelectionModal(context);
                },
                child: const Text('Show Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Tap on the Task Summary prompt
      await tester.tap(find.text('Task Summary'));
      await tester.pumpAndSettle();

      expect(selectedPrompt, equals(taskSummaryPrompt));
    });

    testWidgets('returns null when dismissed', (WidgetTester tester) async {
      PreconfiguredPrompt? selectedPrompt;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            FormBuilderLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selectedPrompt =
                      await showPreconfiguredPromptSelectionModal(context);
                },
                child: const Text('Show Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Dismiss the modal by tapping outside
      await tester.tapAt(const Offset(50, 50));
      await tester.pumpAndSettle();

      expect(selectedPrompt, isNull);
    });

    testWidgets('modal is dismissible by default', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Modal should be visible
      expect(find.text('Select Preconfigured Prompt'), findsOneWidget);

      // Tap outside to dismiss
      await tester.tapAt(const Offset(50, 50));
      await tester.pumpAndSettle();

      // Modal should be dismissed
      expect(find.text('Select Preconfigured Prompt'), findsNothing);
    });
  });

  group('AiResponseType icon display', () {
    testWidgets('displays correct icons for each response type',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());

      // We test this indirectly by checking the icons in the modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Verify each prompt type has its expected icon
      final taskSummaryButton = find.widgetWithText(TextButton, 'Task Summary');
      final taskSummaryIcon = find.descendant(
        of: taskSummaryButton,
        matching: find.byIcon(Icons.summarize_outlined),
      );
      expect(taskSummaryIcon, findsOneWidget);

      final actionItemsButton =
          find.widgetWithText(TextButton, 'Action Item Suggestions');
      final actionItemsIcon = find.descendant(
        of: actionItemsButton,
        matching: find.byIcon(Icons.checklist_outlined),
      );
      expect(actionItemsIcon, findsOneWidget);

      final imageAnalysisButton =
          find.widgetWithText(TextButton, 'Image Analysis');
      final imageAnalysisIcon = find.descendant(
        of: imageAnalysisButton,
        matching: find.byIcon(Icons.image_outlined),
      );
      expect(imageAnalysisIcon, findsOneWidget);

      final audioTranscriptionButton =
          find.widgetWithText(TextButton, 'Audio Transcription');
      final audioTranscriptionIcon = find.descendant(
        of: audioTranscriptionButton,
        matching: find.byIcon(Icons.mic_outlined),
      );
      expect(audioTranscriptionIcon, findsOneWidget);
    });
  });

  group('PreconfiguredPromptTile', () {
    const testPrompt = PreconfiguredPrompt(
      name: 'Test Prompt',
      systemMessage: 'Test system message',
      userMessage: 'Test user message',
      requiredInputData: [InputDataType.task, InputDataType.images],
      aiResponseType: AiResponseType.taskSummary,
      useReasoning: true,
      description: 'Test description for the prompt',
    );

    testWidgets('displays prompt information correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          PreconfiguredPromptTile(
            prompt: testPrompt,
            onTap: () {},
          ),
        ),
      );

      // Check that all prompt information is displayed
      expect(find.text('Test Prompt'), findsOneWidget);
      expect(find.text('Test description for the prompt'), findsOneWidget);
      expect(find.byIcon(Icons.summarize_outlined),
          findsOneWidget); // Icon for task summary response type
    });

    testWidgets('displays required input data chips',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          PreconfiguredPromptTile(
            prompt: testPrompt,
            onTap: () {},
          ),
        ),
      );

      // Check that input type chips are displayed
      expect(find.text('Task'), findsOneWidget);
      expect(find.text('Images'), findsOneWidget);
    });

    testWidgets('displays reasoning chip when useReasoning is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          PreconfiguredPromptTile(
            prompt: testPrompt,
            onTap: () {},
          ),
        ),
      );

      // Note: The reasoning chip text comes from localization, so we check for the chip widget
      final chips = find.byType(Chip);
      expect(
          chips, findsAtLeastNWidgets(3)); // 2 input types + 1 reasoning chip
    });

    testWidgets('does not display reasoning chip when useReasoning is false',
        (WidgetTester tester) async {
      const promptWithoutReasoning = PreconfiguredPrompt(
        name: 'Test Prompt',
        systemMessage: 'Test system message',
        userMessage: 'Test user message',
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.taskSummary,
        useReasoning: false,
        description: 'Test description',
      );

      await tester.pumpWidget(
        makeTestableWidget(
          PreconfiguredPromptTile(
            prompt: promptWithoutReasoning,
            onTap: () {},
          ),
        ),
      );

      final chips = find.byType(Chip);
      expect(chips, findsOneWidget); // Only 1 input type chip
    });

    testWidgets('calls onTap when tapped', (WidgetTester tester) async {
      var tapped = false;

      await tester.pumpWidget(
        makeTestableWidget(
          PreconfiguredPromptTile(
            prompt: testPrompt,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(Card));
      expect(tapped, isTrue);
    });

    testWidgets('displays correct icons for different response types',
        (WidgetTester tester) async {
      // Test task summary response type
      const taskPrompt = PreconfiguredPrompt(
        name: 'Task Summary',
        systemMessage: 'System',
        userMessage: 'User',
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.taskSummary,
        useReasoning: false,
        description: 'Description',
      );

      await tester.pumpWidget(
        makeTestableWidget(
          PreconfiguredPromptTile(
            prompt: taskPrompt,
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.summarize_outlined), findsOneWidget);
    });

    group('_getInputTypeLabel', () {
      testWidgets('displays correct labels for input types',
          (WidgetTester tester) async {
        const promptWithAllInputTypes = PreconfiguredPrompt(
          name: 'Test Prompt',
          systemMessage: 'System',
          userMessage: 'User',
          requiredInputData: [
            InputDataType.task,
            InputDataType.tasksList,
            InputDataType.audioFiles,
            InputDataType.images,
          ],
          aiResponseType: AiResponseType.taskSummary,
          useReasoning: false,
          description: 'Description',
        );

        await tester.pumpWidget(
          makeTestableWidget(
            PreconfiguredPromptTile(
              prompt: promptWithAllInputTypes,
              onTap: () {},
            ),
          ),
        );

        // Check that all input type labels are displayed correctly
        expect(find.text('Task'), findsOneWidget);
        expect(find.text('Tasks List'), findsOneWidget);
        expect(find.text('Audio Files'), findsOneWidget);
        expect(find.text('Images'), findsOneWidget);
      });
    });
  });

  group('Integration Tests', () {
    testWidgets('real preconfigured prompts work correctly in modal',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            FormBuilderLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showPreconfiguredPromptSelectionModal(context),
                child: const Text('Show Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Test that we can find and interact with real prompts
      expect(find.text('Task Summary'), findsOneWidget);
      expect(find.text('Action Item Suggestions'), findsOneWidget);
      expect(find.text('Image Analysis'), findsOneWidget);
      expect(find.text('Audio Transcription'), findsOneWidget);

      // Verify the modal has the expected structure
      expect(find.text('Select Preconfigured Prompt'), findsOneWidget);
      expect(find.byType(TextButton),
          findsAtLeastNWidgets(4)); // One for each prompt
    });

    testWidgets('prompt tile displays real prompt data correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          PreconfiguredPromptTile(
            prompt: taskSummaryPrompt,
            onTap: () {},
          ),
        ),
      );

      // Verify real prompt data is displayed
      expect(find.text('Task Summary'), findsOneWidget);
      expect(
          find.text(
              'Generate a comprehensive summary of a task including progress, remaining work, and insights'),
          findsOneWidget);
      expect(find.byIcon(Icons.summarize_outlined), findsOneWidget);
      expect(find.text('Task'), findsOneWidget); // Input type

      // Should not show reasoning chip since taskSummaryPrompt.useReasoning is false
      final chips = find.byType(Chip);
      expect(chips, findsOneWidget); // Only the Task input type chip
    });
  });
}
