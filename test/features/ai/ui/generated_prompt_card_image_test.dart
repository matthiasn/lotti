import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/generated_prompt_card.dart';

import '../../../test_helper.dart';

void main() {
  group('GeneratedPromptCard - Image Prompt Generation', () {
    final testDateTime = DateTime(2025);

    final testImagePromptEntry = AiResponseEntry(
      meta: Metadata(
        id: 'test-image-prompt-id',
        dateFrom: testDateTime,
        dateTo: testDateTime,
        createdAt: testDateTime,
        updatedAt: testDateTime,
      ),
      data: const AiResponseData(
        model: 'gemini-2.5-pro',
        temperature: 0.7,
        systemMessage: 'System message for image prompt',
        prompt: 'Generate image prompt',
        thoughts: '',
        response: '''
## Summary
A vibrant isometric illustration of a half-completed fortress representing an authentication feature.

## Prompt
Digital illustration of a medieval fortress under construction, 60% complete with scaffolding visible. The completed sections feature golden lock mechanisms and ornate key patterns etched into the stone walls. Construction workers (represented as friendly robots) carry building blocks labeled "OAuth", "JWT", and "Session". A progress bar made of glowing blue energy floats above, showing 62% complete. Color palette: royal blue, gold, warm stone colors. Style: isometric digital art with soft shadows, inspired by Monument Valley game aesthetics. --ar 16:9 --v 6
''',
        type: AiResponseType.imagePromptGeneration,
      ),
    );

    testWidgets('displays image prompt header with palette icon and title',
        (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: GeneratedPromptCard(
            testImagePromptEntry,
            linkedFromId: 'test-id',
          ),
        ),
      );

      // Check for the palette icon (image prompt specific)
      expect(
        find.byIcon(AiResponseType.imagePromptGeneration.icon),
        findsOneWidget,
      );

      // Check for the image prompt title
      expect(find.text('AI Image Prompt'), findsOneWidget);
    });

    testWidgets('displays summary section by default', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: GeneratedPromptCard(
            testImagePromptEntry,
            linkedFromId: 'test-id',
          ),
        ),
      );

      // Summary should be visible
      expect(
        find.textContaining('vibrant isometric illustration'),
        findsOneWidget,
      );
    });

    testWidgets('shows copy button', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: GeneratedPromptCard(
            testImagePromptEntry,
            linkedFromId: 'test-id',
          ),
        ),
      );

      // Copy icon should be visible
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    });

    testWidgets('shows expand/collapse button', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: GeneratedPromptCard(
            testImagePromptEntry,
            linkedFromId: 'test-id',
          ),
        ),
      );

      // Expand icon should be visible
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('full prompt is hidden by default', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: GeneratedPromptCard(
            testImagePromptEntry,
            linkedFromId: 'test-id',
          ),
        ),
      );

      // Full prompt label should not be visible when collapsed
      expect(find.text('Full Image Prompt:'), findsNothing);

      // GptMarkdown for full prompt should not be visible
      expect(find.byType(GptMarkdown), findsNothing);
    });

    testWidgets('expands to show full prompt when chevron is tapped',
        (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: GeneratedPromptCard(
            testImagePromptEntry,
            linkedFromId: 'test-id',
          ),
        ),
      );

      // Tap the expand icon
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();

      // Pump a few frames to let the animation progress
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Full prompt label should now be visible (image-specific label)
      expect(find.text('Full Image Prompt:'), findsOneWidget);

      // GptMarkdown should now be visible with the prompt content
      expect(find.byType(GptMarkdown), findsOneWidget);
    });

    testWidgets('copy button triggers clipboard copy with image prompt',
        (tester) async {
      // Set up clipboard mock
      final clipboardData = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          clipboardData.add(args['text'] as String);
        }
        return null;
      });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: GeneratedPromptCard(
            testImagePromptEntry,
            linkedFromId: 'test-id',
          ),
        ),
      );

      // Tap the copy button
      await tester.tap(find.byIcon(Icons.copy_rounded));
      await tester.pump();

      // Verify clipboard was called with the image prompt content
      expect(clipboardData, isNotEmpty);
      expect(clipboardData.first, contains('medieval fortress'));
      expect(clipboardData.first, contains('--ar 16:9'));
    });

    testWidgets('shows image-specific snackbar after copying', (tester) async {
      // Set up clipboard mock
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        return null;
      });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: GeneratedPromptCard(
            testImagePromptEntry,
            linkedFromId: 'test-id',
          ),
        ),
      );

      // Tap the copy button
      await tester.tap(find.byIcon(Icons.copy_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Image-specific snackbar should appear
      expect(find.text('Image prompt copied to clipboard'), findsOneWidget);
    });

    testWidgets('parses Summary and Prompt sections correctly', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: GeneratedPromptCard(
            testImagePromptEntry,
            linkedFromId: 'test-id',
          ),
        ),
      );

      // Summary should be parsed and displayed
      expect(find.textContaining('vibrant isometric'), findsOneWidget);

      // Expand to see full prompt
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      // Full prompt should now be visible via GptMarkdown
      final gptMarkdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
      expect(gptMarkdown.data, contains('medieval fortress'));
      expect(gptMarkdown.data, contains('Monument Valley'));
    });

    testWidgets(
        'differentiates between coding prompt and image prompt correctly',
        (tester) async {
      final codingPromptEntry = testImagePromptEntry.copyWith(
        data: testImagePromptEntry.data.copyWith(
          type: AiResponseType.promptGeneration,
          response: '''
## Summary
Help with OAuth implementation.

## Prompt
Implement OAuth 2.0 in Flutter.
''',
        ),
      );

      // First render coding prompt
      await tester.pumpWidget(
        WidgetTestBench(
          child: GeneratedPromptCard(
            codingPromptEntry,
            linkedFromId: 'test-id',
          ),
        ),
      );

      // Should show coding prompt title
      expect(find.text('AI Coding Prompt'), findsOneWidget);
      expect(find.text('AI Image Prompt'), findsNothing);
      expect(
        find.byIcon(AiResponseType.promptGeneration.icon),
        findsOneWidget,
      );

      // Render image prompt
      await tester.pumpWidget(
        WidgetTestBench(
          child: GeneratedPromptCard(
            testImagePromptEntry,
            linkedFromId: 'test-id',
          ),
        ),
      );

      // Should show image prompt title
      expect(find.text('AI Image Prompt'), findsOneWidget);
      expect(find.text('AI Coding Prompt'), findsNothing);
      expect(
        find.byIcon(AiResponseType.imagePromptGeneration.icon),
        findsOneWidget,
      );
    });
  });
}
