import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/categories/ui/widgets/category_automatic_prompts.dart';

import '../../../../test_helper.dart';

void main() {
  group('CategoryAutomaticPrompts', () {
    final testPrompts = <AiConfigPrompt>[
      AiConfig.prompt(
        id: 'audio-prompt-1',
        name: 'Audio Summary',
        description: 'Generate summary from audio',
        systemMessage: 'System',
        userMessage: 'User',
        defaultModelId: 'model1',
        modelIds: const ['model1'],
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024, 1, 2),
        useReasoning: false,
        requiredInputData: const [InputDataType.audioFiles],
        aiResponseType: AiResponseType.audioTranscription,
      ) as AiConfigPrompt,
      AiConfig.prompt(
        id: 'audio-prompt-2',
        name: 'Audio Action Items',
        description: 'Extract action items from audio',
        systemMessage: 'System',
        userMessage: 'User',
        defaultModelId: 'model1',
        modelIds: const ['model1'],
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024, 1, 2),
        useReasoning: false,
        requiredInputData: const [InputDataType.audioFiles],
        aiResponseType: AiResponseType.audioTranscription,
      ) as AiConfigPrompt,
      AiConfig.prompt(
        id: 'image-prompt-1',
        name: 'Image Analysis',
        description: 'Analyze image content',
        systemMessage: 'System',
        userMessage: 'User',
        defaultModelId: 'model1',
        modelIds: const ['model1'],
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024, 1, 2),
        useReasoning: false,
        requiredInputData: const [InputDataType.images],
        aiResponseType: AiResponseType.imageAnalysis,
      ) as AiConfigPrompt,
      AiConfig.prompt(
        id: 'task-prompt-1',
        name: 'Task Summary',
        description: 'Generate task summary',
        systemMessage: 'System',
        userMessage: 'User',
        defaultModelId: 'model1',
        modelIds: const ['model1'],
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024, 1, 2),
        useReasoning: false,
        requiredInputData: const [InputDataType.task],
        aiResponseType: AiResponseType.taskSummary,
      ) as AiConfigPrompt,
    ];

    final testConfigs = [
      AutomaticPromptConfig(
        responseType: AiResponseType.audioTranscription,
        title: 'Audio Transcription',
        icon: Icons.mic_outlined,
        availablePrompts: [testPrompts[0], testPrompts[1]],
        selectedPromptIds: const ['audio-prompt-1'],
      ),
      AutomaticPromptConfig(
        responseType: AiResponseType.imageAnalysis,
        title: 'Image Analysis',
        icon: Icons.image_outlined,
        availablePrompts: [testPrompts[2]],
        selectedPromptIds: const [],
      ),
      AutomaticPromptConfig(
        responseType: AiResponseType.taskSummary,
        title: 'Task Summary',
        icon: Icons.summarize_outlined,
        availablePrompts: [testPrompts[3]],
        selectedPromptIds: const ['task-prompt-1'],
      ),
    ];

    testWidgets('displays loading state correctly', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryAutomaticPrompts(
            configs: const [],
            onPromptChanged: (_, __) {},
            isLoading: true,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(FilterChip), findsNothing);
    });

    testWidgets('displays error state correctly', (tester) async {
      const errorMessage = 'Failed to load prompts';

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryAutomaticPrompts(
            configs: const [],
            onPromptChanged: (_, __) {},
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

    testWidgets('displays all response type sections', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryAutomaticPrompts(
            configs: testConfigs,
            onPromptChanged: (_, __) {},
            isLoading: false,
          ),
        ),
      );

      // Verify all sections are displayed
      expect(find.text('Audio Transcription'), findsOneWidget);
      expect(find.text('Image Analysis'), findsNWidgets(2));
      expect(find.text('Task Summary'), findsNWidgets(2));

      // Verify icons
      expect(find.byIcon(Icons.mic_outlined), findsOneWidget);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byIcon(Icons.summarize_outlined), findsOneWidget);

      // Verify prompt chips
      expect(find.text('Audio Summary'), findsOneWidget);
      expect(find.text('Audio Action Items'), findsOneWidget);
      // 'Image Analysis' appears twice - as section title and chip name
      expect(find.text('Image Analysis'), findsNWidgets(2));
      // 'Task Summary' appears twice - as section title and chip name
      expect(find.text('Task Summary'), findsNWidgets(2));
    });

    testWidgets('displays correct chip selection states', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryAutomaticPrompts(
            configs: testConfigs,
            onPromptChanged: (_, __) {},
            isLoading: false,
          ),
        ),
      );

      // Get all filter chips
      final filterChips = tester
          .widgetList<FilterChip>(
            find.byType(FilterChip),
          )
          .toList();

      // Audio section: first chip selected, second not
      expect(filterChips[0].selected, isTrue); // Audio Summary
      expect(filterChips[1].selected, isFalse); // Audio Action Items

      // Image section: no selection
      expect(filterChips[2].selected, isFalse); // Image Analysis

      // Task section: selected
      expect(filterChips[3].selected, isTrue); // Task Summary
    });

    testWidgets('calls onPromptChanged when chip is selected', (tester) async {
      AiResponseType? changedType;
      List<String>? changedIds;

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryAutomaticPrompts(
            configs: testConfigs,
            onPromptChanged: (type, ids) {
              changedType = type;
              changedIds = ids;
            },
            isLoading: false,
          ),
        ),
      );

      // Tap on unselected chip (Audio Action Items)
      await tester.tap(find.text('Audio Action Items'));
      await tester.pump();

      expect(changedType, AiResponseType.audioTranscription);
      expect(changedIds, ['audio-prompt-2']);

      // Reset
      changedType = null;
      changedIds = null;

      // Tap on selected chip (Audio Summary) to deselect
      await tester.tap(find.text('Audio Summary'));
      await tester.pump();

      expect(changedType, AiResponseType.audioTranscription);
      expect(changedIds, <String>[]); // Empty list when deselecting
    });

    testWidgets('only allows one selection per response type', (tester) async {
      final callHistory = <(AiResponseType, List<String>)>[];

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryAutomaticPrompts(
            configs: testConfigs,
            onPromptChanged: (type, ids) {
              callHistory.add((type, ids));
            },
            isLoading: false,
          ),
        ),
      );

      // Select second audio prompt (should replace first)
      await tester.tap(find.text('Audio Action Items'));
      await tester.pump();

      expect(callHistory.last.$1, AiResponseType.audioTranscription);
      expect(callHistory.last.$2, ['audio-prompt-2']);
    });

    testWidgets('displays empty state for response type without prompts',
        (tester) async {
      final emptyConfig = [
        const AutomaticPromptConfig(
          responseType: AiResponseType.imageAnalysis,
          title: 'Image Analysis',
          icon: Icons.image_outlined,
          availablePrompts: [], // No prompts available
          selectedPromptIds: [],
        ),
      ];

      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryAutomaticPrompts(
            configs: emptyConfig,
            onPromptChanged: (_, __) {},
            isLoading: false,
          ),
        ),
      );

      expect(find.text('No prompts available for this type'), findsOneWidget);
      expect(find.byType(FilterChip), findsNothing);
    });

    testWidgets('has correct visual structure', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryAutomaticPrompts(
            configs: testConfigs,
            onPromptChanged: (_, __) {},
            isLoading: false,
          ),
        ),
      );

      // Find all containers (one per config)
      final containerFinder = find.descendant(
        of: find.byType(CategoryAutomaticPrompts),
        matching: find.byType(Container),
      );

      final containers = <Container>[];
      for (var i = 0; i < tester.widgetList(containerFinder).length; i++) {
        final container = tester.widget<Container>(containerFinder.at(i));
        if (container.decoration is BoxDecoration) {
          containers.add(container);
        }
      }

      expect(containers.length, 3);

      // Check each container has border and border radius
      for (final container in containers) {
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.border, isNotNull);
        expect(decoration.borderRadius, BorderRadius.circular(8));
      }
    });

    testWidgets('applies correct spacing between sections', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryAutomaticPrompts(
            configs: testConfigs,
            onPromptChanged: (_, __) {},
            isLoading: false,
          ),
        ),
      );

      // The widget wraps each config in a Padding widget
      // The implementation adds bottom padding for all except the last item
      final column = tester.widget<Column>(
        find
            .descendant(
              of: find.byType(CategoryAutomaticPrompts),
              matching: find.byType(Column),
            )
            .first,
      );

      expect(column.children.length, 3);

      // Verify the structure is correct
      for (var i = 0; i < column.children.length; i++) {
        expect(column.children[i], isA<Padding>());
        final padding = column.children[i] as Padding;

        if (i < column.children.length - 1) {
          // All but last should have bottom padding
          expect(padding.padding, const EdgeInsets.only(bottom: 16));
        } else {
          // Last should have no bottom padding
          expect(padding.padding, EdgeInsets.zero);
        }
      }
    });

    testWidgets('uses Wrap widget for chip layout', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryAutomaticPrompts(
            configs: testConfigs,
            onPromptChanged: (_, __) {},
            isLoading: false,
          ),
        ),
      );

      // Should have one Wrap widget per config with available prompts
      expect(find.byType(Wrap), findsNWidgets(3));

      // Verify Wrap spacing
      final wraps = tester.widgetList<Wrap>(find.byType(Wrap));
      for (final wrap in wraps) {
        expect(wrap.spacing, 8);
        expect(wrap.runSpacing, 8);
      }
    });

    testWidgets('responds to theme changes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: WidgetTestBench(
            child: CategoryAutomaticPrompts(
              configs: testConfigs,
              onPromptChanged: (_, __) {},
              isLoading: false,
            ),
          ),
        ),
      );

      // Verify it renders correctly in dark theme
      expect(find.byType(CategoryAutomaticPrompts), findsOneWidget);
      expect(find.byType(FilterChip), findsNWidgets(4));
    });

    testWidgets('AutomaticPromptConfig stores data correctly', (tester) async {
      final config = AutomaticPromptConfig(
        responseType: AiResponseType.audioTranscription,
        title: 'Test Title',
        icon: Icons.mic,
        availablePrompts: testPrompts,
        selectedPromptIds: const ['id1', 'id2'],
      );

      expect(config.responseType, AiResponseType.audioTranscription);
      expect(config.title, 'Test Title');
      expect(config.icon, Icons.mic);
      expect(config.availablePrompts, testPrompts);
      expect(config.selectedPromptIds, ['id1', 'id2']);
    });

    testWidgets('handles empty configs list', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: CategoryAutomaticPrompts(
            configs: const [],
            onPromptChanged: (_, __) {},
            isLoading: false,
          ),
        ),
      );

      // Should render without errors but show no content
      expect(find.byType(CategoryAutomaticPrompts), findsOneWidget);
      expect(find.byType(Container), findsNothing);
      expect(find.byType(FilterChip), findsNothing);
    });
  });
}
