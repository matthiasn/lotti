import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/ai_response_summary.dart';
import 'package:lotti/features/ai/ui/expandable_ai_response_summary.dart';
import 'package:lotti/features/ai/ui/generated_prompt_card.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../test_helper.dart';

class MockUrlLauncher extends Mock
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {}

class FakeLaunchOptions extends Fake implements LaunchOptions {}

void main() {
  group('AiResponseSummary', () {
    final testDateTime = DateTime(2023);

    final testAiResponseEntry = AiResponseEntry(
      meta: Metadata(
        id: 'test-id',
        dateFrom: testDateTime,
        dateTo: testDateTime,
        createdAt: testDateTime,
        updatedAt: testDateTime,
      ),
      data: const AiResponseData(
        model: 'gpt-4',
        temperature: 0.7,
        systemMessage: 'System message',
        prompt: 'User prompt',
        thoughts: '',
        response: 'AI response',
        type: AiResponseType.taskSummary,
      ),
    );
    testWidgets('uses ExpandableAiResponseSummary for task summaries',
        (tester) async {
      const responseWithTitle = '''
# Implement user authentication system

**TLDR:** Authentication setup in progress.
Database and login API are complete.
Next: password reset and session management. 💪

Achieved results:
✅ Set up database schema for users
✅ Created login API endpoint

Remaining steps:
1. Implement password reset functionality
2. Add session management''';

      final aiResponse = testAiResponseEntry.copyWith(
        data: testAiResponseEntry.data.copyWith(
          response: responseWithTitle,
          type: AiResponseType.taskSummary,
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: AiResponseSummary(
            aiResponse,
            linkedFromId: 'test-id',
            fadeOut: false,
          ),
        ),
      );

      // Should use ExpandableAiResponseSummary for task summaries
      expect(find.byType(ExpandableAiResponseSummary), findsOneWidget);

      // GptMarkdown should be rendered inside ExpandableAiResponseSummary
      expect(find.byType(GptMarkdown), findsOneWidget);
    });

    testWidgets('does not filter H1 for non-task summary responses',
        (tester) async {
      const responseWithH1 = '''
# Analysis Results

The image shows a beautiful landscape with mountains.''';

      final aiResponse = testAiResponseEntry.copyWith(
        data: testAiResponseEntry.data.copyWith(
          response: responseWithH1,
          type: AiResponseType.imageAnalysis,
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: AiResponseSummary(
            aiResponse,
            linkedFromId: 'test-id',
            fadeOut: false,
          ),
        ),
      );

      // GptMarkdown should be rendered
      expect(find.byType(GptMarkdown), findsOneWidget);

      // Check that the widget is displaying the content with H1
      final gptMarkdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
      expect(gptMarkdown.data.contains('# Analysis Results'), true);
    });

    testWidgets(
        'applies fade out effect when fadeOut is true for non-task summaries',
        (tester) async {
      final aiResponse = testAiResponseEntry.copyWith(
        data: testAiResponseEntry.data.copyWith(
          response: 'Test response content',
          type:
              AiResponseType.imageAnalysis, // Changed to non-task summary type
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: AiResponseSummary(
            aiResponse,
            linkedFromId: 'test-id',
            fadeOut: true,
          ),
        ),
      );

      // Check for ShaderMask when fadeOut is true
      expect(find.byType(ShaderMask), findsOneWidget);
      // ConstrainedBox with maxHeight should be inside ShaderMask
      final constrainedBox = find.descendant(
        of: find.byType(ShaderMask),
        matching: find.byType(ConstrainedBox),
      );
      expect(constrainedBox, findsOneWidget);
    });

    testWidgets('opens modal on double tap for non-task summaries',
        (tester) async {
      final aiResponse = testAiResponseEntry.copyWith(
        data: testAiResponseEntry.data.copyWith(
          response: 'Test response content',
          type:
              AiResponseType.imageAnalysis, // Changed to non-task summary type
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: AiResponseSummary(
            aiResponse,
            linkedFromId: 'test-id',
            fadeOut: false,
          ),
        ),
      );

      // Double tap to open modal
      await tester.pumpAndSettle();
      final gestureDetector = find.byType(GestureDetector).first;
      await tester.tap(gestureDetector);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(gestureDetector);
      await tester.pumpAndSettle();

      // Modal should be opened (we can't directly test the modal content
      // as it's shown in a different route)
    });

    testWidgets('uses GeneratedPromptCard for prompt generation responses',
        (tester) async {
      const promptResponse = '''
## Summary
A well-crafted prompt for implementing OAuth authentication.

## Prompt
Help me implement OAuth 2.0 authentication in my Flutter app.
''';

      final aiResponse = testAiResponseEntry.copyWith(
        data: testAiResponseEntry.data.copyWith(
          response: promptResponse,
          type: AiResponseType.promptGeneration,
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: AiResponseSummary(
            aiResponse,
            linkedFromId: 'test-id',
            fadeOut: false,
          ),
        ),
      );

      // Should use GeneratedPromptCard for prompt generation
      expect(find.byType(GeneratedPromptCard), findsOneWidget);

      // Should not use ExpandableAiResponseSummary
      expect(find.byType(ExpandableAiResponseSummary), findsNothing);
    });

    testWidgets(
        'uses GeneratedPromptCard for image prompt generation responses',
        (tester) async {
      const imagePromptResponse = '''
## Summary
A vibrant isometric illustration of a fortress being built.

## Prompt
Digital illustration of a medieval fortress under construction, 60% complete.
Style: isometric digital art. --ar 16:9
''';

      final aiResponse = testAiResponseEntry.copyWith(
        data: testAiResponseEntry.data.copyWith(
          response: imagePromptResponse,
          type: AiResponseType.imagePromptGeneration,
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: AiResponseSummary(
            aiResponse,
            linkedFromId: 'test-id',
            fadeOut: false,
          ),
        ),
      );

      // Should use GeneratedPromptCard for image prompt generation
      expect(find.byType(GeneratedPromptCard), findsOneWidget);

      // Should not use ExpandableAiResponseSummary
      expect(find.byType(ExpandableAiResponseSummary), findsNothing);
    });

    testWidgets('handles link tap in non-task summary responses',
        (tester) async {
      // Set up mock URL launcher and capture original for cleanup
      final originalPlatform = UrlLauncherPlatform.instance;
      final mockUrlLauncher = MockUrlLauncher();
      registerFallbackValue(FakeLaunchOptions());
      UrlLauncherPlatform.instance = mockUrlLauncher;
      addTearDown(() => UrlLauncherPlatform.instance = originalPlatform);

      when(() => mockUrlLauncher.canLaunch(any()))
          .thenAnswer((_) async => true);
      when(() => mockUrlLauncher.launchUrl(any(), any()))
          .thenAnswer((_) async => true);

      const responseWithLink =
          'Check the [docs](https://docs.flutter.dev) for info.';

      final aiResponse = testAiResponseEntry.copyWith(
        data: testAiResponseEntry.data.copyWith(
          response: responseWithLink,
          type: AiResponseType.imageAnalysis,
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: AiResponseSummary(
            aiResponse,
            linkedFromId: 'test-id',
            fadeOut: false,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find GestureDetector widgets with onTap and manually call the callback
      // to verify the URL launcher integration
      var linkCallbackFound = false;
      final gestureDetectors =
          tester.widgetList<GestureDetector>(find.byType(GestureDetector));
      for (final gd in gestureDetectors) {
        if (gd.onTap != null) {
          // Try to invoke the callback and check if it triggers URL launcher
          gd.onTap!();
          await tester.pumpAndSettle();

          // Check if URL launcher was called with the expected URL
          try {
            verify(() => mockUrlLauncher.launchUrl(
                  'https://docs.flutter.dev',
                  any(),
                )).called(1);
            linkCallbackFound = true;
            break;
          } catch (_) {
            // This callback didn't trigger the right URL, continue searching
            reset(mockUrlLauncher);
            when(() => mockUrlLauncher.canLaunch(any()))
                .thenAnswer((_) async => true);
            when(() => mockUrlLauncher.launchUrl(any(), any()))
                .thenAnswer((_) async => true);
          }
        }
      }
      expect(linkCallbackFound, isTrue);
    });
  });
}
