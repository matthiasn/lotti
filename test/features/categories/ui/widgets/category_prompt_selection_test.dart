import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/categories/ui/widgets/category_prompt_selection.dart';
import 'package:lotti/widgets/ui/empty_state_widget.dart';

import '../../../../test_helper.dart';
import '../../../ai/test_utils.dart';

void main() {
  group('CategoryPromptSelection', () {
    final testPrompts = <AiConfigPrompt>[
      AiConfig.prompt(
        id: 'prompt1',
        name: 'Task Summary',
        description: 'Generate a summary of the task',
        systemMessage: 'System message',
        userMessage: 'User message',
        defaultModelId: 'model1',
        modelIds: ['model1'],
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024, 1, 2),
        useReasoning: false,
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.taskSummary,
      ) as AiConfigPrompt,
      AiConfig.prompt(
        id: 'prompt2',
        name: 'Action Items',
        description: 'Update checklist items based on task content',
        systemMessage: 'System message',
        userMessage: 'User message',
        defaultModelId: 'model1',
        modelIds: ['model1'],
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024, 1, 2),
        useReasoning: false,
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.checklistUpdates,
      ) as AiConfigPrompt,
      AiConfig.prompt(
        id: 'prompt3',
        name: 'Image Analysis',
        systemMessage: 'System message',
        userMessage: 'User message',
        defaultModelId: 'model1',
        modelIds: ['model1'],
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024, 1, 2),
        useReasoning: false,
        requiredInputData: [InputDataType.images],
        aiResponseType: AiResponseType.imageAnalysis,
      ) as AiConfigPrompt,
    ];

    testWidgets('displays loading state correctly', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryPromptSelection(
            prompts: const [],
            allowedPromptIds: const [],
            onPromptToggled: (_, {required isAllowed}) {},
            isLoading: true,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNothing);
    });

    testWidgets('displays error state correctly', (tester) async {
      const errorMessage = 'Failed to load prompts';

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryPromptSelection(
            prompts: const [],
            allowedPromptIds: const [],
            onPromptToggled: (_, {required isAllowed}) {},
            isLoading: false,
            error: errorMessage,
          ),
        ),
      );

      expect(find.text(errorMessage), findsOneWidget);

      // Verify error text has error color
      final errorText = tester.widget<Text>(find.text(errorMessage));
      final context = tester.element(find.text(errorMessage));
      expect(errorText.style?.color, Theme.of(context).colorScheme.error);
    });

    testWidgets('displays empty state when no prompts', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryPromptSelection(
            prompts: const [],
            allowedPromptIds: const [],
            onPromptToggled: (_, {required isAllowed}) {},
            isLoading: false,
          ),
        ),
      );

      expect(find.byType(EmptyStateWidget), findsOneWidget);
      expect(find.byIcon(Icons.psychology_outlined), findsOneWidget);
      expect(find.text('No prompts available'), findsOneWidget);
      expect(find.text('Create AI prompts first to configure them here'),
          findsOneWidget);
    });

    testWidgets('displays prompts correctly', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryPromptSelection(
            prompts: testPrompts,
            allowedPromptIds: const ['prompt1'],
            onPromptToggled: (_, {required isAllowed}) {},
            isLoading: false,
          ),
        ),
      );

      // Verify header text
      expect(find.text('Select which prompts are allowed for this category'),
          findsOneWidget);

      // Verify all prompts are displayed
      expect(find.byType(CheckboxListTile), findsNWidgets(3));
      expect(find.text('Task Summary'), findsOneWidget);
      expect(find.text('Action Items'), findsOneWidget);
      expect(find.text('Image Analysis'), findsOneWidget);

      // Verify descriptions
      expect(find.text('Generate a summary of the task'), findsOneWidget);
      expect(find.text('Update checklist items based on task content'),
          findsOneWidget);

      // Verify checkbox states
      final checkboxes = tester
          .widgetList<CheckboxListTile>(
            find.byType(CheckboxListTile),
          )
          .toList();
      expect(checkboxes[0].value, isTrue); // prompt1 is allowed
      expect(checkboxes[1].value, isFalse); // prompt2 is not allowed
      expect(checkboxes[2].value, isFalse); // prompt3 is not allowed
    });

    testWidgets('calls onPromptToggled when checkbox is tapped',
        (tester) async {
      String? toggledPromptId;
      bool? toggledValue;

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryPromptSelection(
            prompts: testPrompts,
            allowedPromptIds: const ['prompt1'],
            onPromptToggled: (promptId, {required isAllowed}) {
              toggledPromptId = promptId;
              toggledValue = isAllowed;
            },
            isLoading: false,
          ),
        ),
      );

      // Tap on the second checkbox (currently unchecked)
      await tester.tap(find.byType(CheckboxListTile).at(1));
      await tester.pump();

      expect(toggledPromptId, 'prompt2');
      expect(toggledValue, isTrue);

      // Reset
      toggledPromptId = null;
      toggledValue = null;

      // Tap on the first checkbox (currently checked)
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pump();

      expect(toggledPromptId, 'prompt1');
      expect(toggledValue, isFalse);
    });

    testWidgets('handles prompts without descriptions', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryPromptSelection(
            prompts: testPrompts,
            allowedPromptIds: const [],
            onPromptToggled: (_, {required isAllowed}) {},
            isLoading: false,
          ),
        ),
      );

      // Image Analysis prompt has no description
      final checkboxes = tester
          .widgetList<CheckboxListTile>(
            find.byType(CheckboxListTile),
          )
          .toList();

      expect(checkboxes[0].subtitle, isNotNull); // Has description
      expect(checkboxes[1].subtitle, isNotNull); // Has description
      expect(checkboxes[2].subtitle, isNull); // No description
    });

    testWidgets('has correct visual structure', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryPromptSelection(
            prompts: testPrompts,
            allowedPromptIds: const [],
            onPromptToggled: (_, {required isAllowed}) {},
            isLoading: false,
          ),
        ),
      );

      // Verify container with border
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(CategoryPromptSelection),
              matching: find.byType(Container),
            )
            .last,
      );

      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.border, isNotNull);
      expect(decoration.borderRadius, BorderRadius.circular(8));
    });

    testWidgets('subtitle text has correct overflow behavior', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryPromptSelection(
            prompts: [
              AiConfig.prompt(
                id: 'long-desc',
                name: 'Long Description Prompt',
                description:
                    'This is a very long description that should be truncated with ellipsis when it exceeds the available space in the list tile',
                systemMessage: 'System message',
                userMessage: 'User message',
                defaultModelId: 'model1',
                modelIds: ['model1'],
                createdAt: DateTime(2024),
                updatedAt: DateTime(2024, 1, 2),
                useReasoning: false,
                requiredInputData: [],
                aiResponseType: AiResponseType.taskSummary,
              ) as AiConfigPrompt,
            ],
            allowedPromptIds: const [],
            onPromptToggled: (_, {required isAllowed}) {},
            isLoading: false,
          ),
        ),
      );

      final subtitleText = tester.widget<Text>(
        find
            .descendant(
              of: find.byType(CheckboxListTile),
              matching: find.byType(Text),
            )
            .at(1), // Second text is the subtitle
      );

      expect(subtitleText.maxLines, 1);
      expect(subtitleText.overflow, TextOverflow.ellipsis);
    });

    testWidgets('handles multiple prompts with different states',
        (tester) async {
      final manyPrompts = <AiConfigPrompt>[
        ...List.generate(
          10,
          (index) => AiConfig.prompt(
            id: 'prompt$index',
            name: 'Prompt $index',
            description: 'Description for prompt $index',
            systemMessage: 'System message',
            userMessage: 'User message',
            defaultModelId: 'model1',
            modelIds: ['model1'],
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024, 1, 2),
            useReasoning: false,
            requiredInputData: [],
            aiResponseType: AiResponseType.taskSummary,
          ) as AiConfigPrompt,
        ),
      ];

      // Allow prompts 0, 3, 6, 9
      final allowedIds = ['prompt0', 'prompt3', 'prompt6', 'prompt9'];

      await tester.pumpWidget(
        WidgetTestBench(
          child: SingleChildScrollView(
            child: CategoryPromptSelection(
              prompts: manyPrompts,
              allowedPromptIds: allowedIds,
              onPromptToggled: (_, {required isAllowed}) {},
              isLoading: false,
            ),
          ),
        ),
      );

      // Verify correct number of checkboxes
      expect(find.byType(CheckboxListTile), findsNWidgets(10));

      // Verify checkbox states
      final checkboxes = tester
          .widgetList<CheckboxListTile>(
            find.byType(CheckboxListTile),
          )
          .toList();

      for (var i = 0; i < checkboxes.length; i++) {
        final expectedValue = allowedIds.contains('prompt$i');
        expect(checkboxes[i].value, expectedValue,
            reason:
                'Checkbox $i should be ${expectedValue ? 'checked' : 'unchecked'}');
      }
    });

    testWidgets('responds to theme changes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: WidgetTestBench(
            child: CategoryPromptSelection(
              prompts: testPrompts,
              allowedPromptIds: const [],
              onPromptToggled: (_, {required isAllowed}) {},
              isLoading: false,
            ),
          ),
        ),
      );

      // Verify it renders correctly in dark theme
      expect(find.byType(CategoryPromptSelection), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(3));
    });

    testWidgets('handles null onChanged from CheckboxListTile', (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryPromptSelection(
            prompts: testPrompts,
            allowedPromptIds: const [],
            onPromptToggled: (_, {required isAllowed}) {
              callCount++;
            },
            isLoading: false,
          ),
        ),
      );

      // This simulates the edge case where onChanged is called with null
      // In the actual widget, this is handled by the null check
      final checkboxes = tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );

      // The onChanged callback should handle null gracefully
      expect(checkboxes.first.onChanged, isNotNull);
      checkboxes.first.onChanged!(null);

      // Should not have called our callback
      expect(callCount, 0);
    });
  });

  group('CategoryPromptSelection provider filter', () {
    final testModels = <AiConfigModel>[
      AiTestDataFactory.createTestModel(
        id: 'model-anthropic',
        name: 'Claude Sonnet',
        providerModelId: 'claude-sonnet-4-6',
        inferenceProviderId: 'provider-anthropic',
      ),
      AiTestDataFactory.createTestModel(
        id: 'model-gemini',
        name: 'Gemini Pro',
        providerModelId: 'gemini-pro',
        inferenceProviderId: 'provider-gemini',
      ),
    ];

    final testProviders = <AiConfigInferenceProvider>[
      AiTestDataFactory.createTestProvider(
        id: 'provider-anthropic',
        name: 'Anthropic',
        baseUrl: 'https://api.anthropic.com',
        apiKey: 'key',
      ),
      AiTestDataFactory.createTestProvider(
        id: 'provider-gemini',
        name: 'Gemini',
        type: InferenceProviderType.gemini,
        baseUrl: 'https://api.gemini.com',
        apiKey: 'key',
      ),
    ];

    final promptAnthropic = AiTestDataFactory.createTestPrompt(
      id: 'prompt-a1',
      name: 'Anthropic Prompt',
      description: 'Uses Anthropic',
      defaultModelId: 'model-anthropic',
      modelIds: ['model-anthropic'],
    );

    final promptGemini = AiTestDataFactory.createTestPrompt(
      id: 'prompt-g1',
      name: 'Gemini Prompt',
      description: 'Uses Gemini',
      defaultModelId: 'model-gemini',
      modelIds: ['model-gemini'],
    );

    final promptGemini2 = AiTestDataFactory.createTestPrompt(
      id: 'prompt-g2',
      name: 'Gemini Prompt 2',
      description: 'Also uses Gemini',
      defaultModelId: 'model-gemini',
      modelIds: ['model-gemini'],
    );

    final allPrompts = [promptAnthropic, promptGemini, promptGemini2];

    Future<void> pumpFilterWidget(
      WidgetTester tester, {
      List<AiConfigPrompt>? prompts,
      List<AiConfigModel>? models,
      List<AiConfigInferenceProvider>? providers,
      List<String> allowedPromptIds = const [],
      void Function(String, {required bool isAllowed})? onPromptToggled,
    }) {
      return tester.pumpWidget(
        WidgetTestBench(
          child: SingleChildScrollView(
            child: CategoryPromptSelection(
              prompts: prompts ?? allPrompts,
              models: models ?? testModels,
              providers: providers ?? testProviders,
              allowedPromptIds: allowedPromptIds,
              onPromptToggled: onPromptToggled ?? (_, {required isAllowed}) {},
              isLoading: false,
            ),
          ),
        ),
      );
    }

    testWidgets('does not show filter when only one provider', (tester) async {
      await pumpFilterWidget(
        tester,
        prompts: [promptAnthropic],
        providers: [testProviders.first],
      );

      expect(find.byType(FilterChip), findsNothing);
      expect(find.byType(CheckboxListTile), findsOneWidget);
    });

    testWidgets('shows filter chips when multiple providers', (tester) async {
      await pumpFilterWidget(tester);

      // "All" + "Anthropic" + "Gemini" = 3 chips
      expect(find.byType(FilterChip), findsNWidgets(3));
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Anthropic'), findsOneWidget);
      expect(find.text('Gemini'), findsOneWidget);

      // All prompts visible by default
      expect(find.byType(CheckboxListTile), findsNWidgets(3));
    });

    testWidgets('selecting provider chip filters prompts', (tester) async {
      await pumpFilterWidget(tester);

      // Tap "Anthropic" chip
      await tester.tap(find.text('Anthropic'));
      await tester.pump();

      // Only Anthropic prompt visible
      expect(find.byType(CheckboxListTile), findsOneWidget);
      expect(find.text('Anthropic Prompt'), findsOneWidget);
      expect(find.text('Gemini Prompt'), findsNothing);
    });

    testWidgets('selecting Gemini chip shows only Gemini prompts',
        (tester) async {
      await pumpFilterWidget(tester);

      await tester.tap(find.text('Gemini'));
      await tester.pump();

      expect(find.byType(CheckboxListTile), findsNWidgets(2));
      expect(find.text('Gemini Prompt'), findsOneWidget);
      expect(find.text('Gemini Prompt 2'), findsOneWidget);
      expect(find.text('Anthropic Prompt'), findsNothing);
    });

    testWidgets('tapping All chip shows all prompts again', (tester) async {
      await pumpFilterWidget(tester);

      // Filter to Anthropic
      await tester.tap(find.text('Anthropic'));
      await tester.pump();
      expect(find.byType(CheckboxListTile), findsOneWidget);

      // Reset to All
      await tester.tap(find.text('All'));
      await tester.pump();
      expect(find.byType(CheckboxListTile), findsNWidgets(3));
    });

    testWidgets('All chip is selected by default', (tester) async {
      await pumpFilterWidget(tester);

      final allChip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'All'),
      );
      expect(allChip.selected, isTrue);

      final anthropicChip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'Anthropic'),
      );
      expect(anthropicChip.selected, isFalse);
    });

    testWidgets('does not show filter when no models/providers provided',
        (tester) async {
      await pumpFilterWidget(
        tester,
        models: const [],
        providers: const [],
      );

      expect(find.byType(FilterChip), findsNothing);
      expect(find.byType(CheckboxListTile), findsNWidgets(3));
    });

    testWidgets('toggling prompt while filtered calls onPromptToggled',
        (tester) async {
      String? toggledId;

      await pumpFilterWidget(
        tester,
        onPromptToggled: (promptId, {required isAllowed}) {
          toggledId = promptId;
        },
      );

      // Filter to Gemini
      await tester.tap(find.text('Gemini'));
      await tester.pump();

      // Tap the first Gemini prompt checkbox
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pump();

      expect(toggledId, 'prompt-g1');
    });
  });
}
