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
  group('GeneratedPromptCard', () {
    final testDateTime = DateTime(2025);

    final testAiResponseEntry = AiResponseEntry(
      meta: Metadata(
        id: 'test-id',
        dateFrom: testDateTime,
        dateTo: testDateTime,
        createdAt: testDateTime,
        updatedAt: testDateTime,
      ),
      data: const AiResponseData(
        model: 'gemini-2.5-pro',
        temperature: 0.7,
        systemMessage: 'System message',
        prompt: 'User prompt',
        thoughts: '',
        response: '''
## Summary
This prompt helps implement a new authentication feature with OAuth integration.

## Prompt
I need help implementing OAuth 2.0 authentication in my Flutter app.

Requirements:
- Support Google and GitHub providers
- Implement secure token storage
- Handle refresh tokens properly

Please provide step-by-step guidance.
''',
        type: AiResponseType.promptGeneration,
      ),
    );

    testWidgets('displays header with icon and title', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: GeneratedPromptCard(
            testAiResponseEntry,
            linkedFromId: 'test-id',
          ),
        ),
      );

      // Check for the icon
      expect(
        find.byIcon(AiResponseType.promptGeneration.icon),
        findsOneWidget,
      );

      // Check for the title text
      expect(find.text('AI Coding Prompt'), findsOneWidget);
    });

    testWidgets('displays summary section by default', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: GeneratedPromptCard(
            testAiResponseEntry,
            linkedFromId: 'test-id',
          ),
        ),
      );

      // Summary should be visible
      expect(
        find.textContaining('implement a new authentication feature'),
        findsOneWidget,
      );
    });

    testWidgets('shows copy button with correct tooltip', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: GeneratedPromptCard(
            testAiResponseEntry,
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
            testAiResponseEntry,
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
            testAiResponseEntry,
            linkedFromId: 'test-id',
          ),
        ),
      );

      // Full prompt label should not be visible when collapsed
      expect(find.text('Full Prompt:'), findsNothing);

      // GptMarkdown for full prompt should not be visible
      expect(find.byType(GptMarkdown), findsNothing);
    });

    testWidgets('expands to show full prompt when chevron is tapped',
        (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: GeneratedPromptCard(
            testAiResponseEntry,
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

      // Full prompt label should now be visible
      expect(find.text('Full Prompt:'), findsOneWidget);

      // GptMarkdown should now be visible with the prompt content
      expect(find.byType(GptMarkdown), findsOneWidget);
    });

    testWidgets('collapses back when chevron is tapped again', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: GeneratedPromptCard(
            testAiResponseEntry,
            linkedFromId: 'test-id',
          ),
        ),
      );

      // First tap to expand
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      // Full prompt should be visible
      expect(find.text('Full Prompt:'), findsOneWidget);

      // Second tap to collapse
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      // Full prompt label should be hidden again
      expect(find.text('Full Prompt:'), findsNothing);
    });

    testWidgets('copy button triggers clipboard copy', (tester) async {
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

      await tester.pumpWidget(
        WidgetTestBench(
          child: GeneratedPromptCard(
            testAiResponseEntry,
            linkedFromId: 'test-id',
          ),
        ),
      );

      // Tap the copy button
      await tester.tap(find.byIcon(Icons.copy_rounded));
      await tester.pump();

      // Verify clipboard was called with the prompt content
      expect(clipboardData, isNotEmpty);
      expect(clipboardData.first, contains('OAuth 2.0 authentication'));

      // Clean up
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('shows snackbar after copying', (tester) async {
      // Set up clipboard mock
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        return null;
      });

      await tester.pumpWidget(
        WidgetTestBench(
          child: GeneratedPromptCard(
            testAiResponseEntry,
            linkedFromId: 'test-id',
          ),
        ),
      );

      // Tap the copy button
      await tester.tap(find.byIcon(Icons.copy_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Snackbar should appear
      expect(find.text('Prompt copied to clipboard'), findsOneWidget);

      // Clean up
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('handles response without proper format', (tester) async {
      final aiResponseNoFormat = testAiResponseEntry.copyWith(
        data: testAiResponseEntry.data.copyWith(
          response: 'Just a plain text response without Summary/Prompt format.',
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: GeneratedPromptCard(
            aiResponseNoFormat,
            linkedFromId: 'test-id',
          ),
        ),
      );

      // Should still display the first line as summary
      expect(
        find.textContaining('Just a plain text response'),
        findsOneWidget,
      );
    });

    testWidgets('parses Summary and Prompt sections correctly', (tester) async {
      const responseWithSections = '''
## Summary
Brief summary here.

## Prompt
Full detailed prompt here with multiple lines.
And more content.
''';

      final aiResponse = testAiResponseEntry.copyWith(
        data: testAiResponseEntry.data.copyWith(
          response: responseWithSections,
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: GeneratedPromptCard(
            aiResponse,
            linkedFromId: 'test-id',
          ),
        ),
      );

      // Summary should be parsed and displayed
      expect(find.textContaining('Brief summary here'), findsOneWidget);

      // Expand to see full prompt
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      // Full prompt should now be visible via GptMarkdown
      final gptMarkdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
      expect(gptMarkdown.data, contains('Full detailed prompt here'));
      expect(gptMarkdown.data, contains('And more content'));
    });
  });
}
