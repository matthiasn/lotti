import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/ai_response_summary_modal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../test_helper.dart';

class MockUrlLauncher extends Mock
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {}

class FakeLaunchOptions extends Fake implements LaunchOptions {}

// Note: We don't need to implement the mocks for clipboard functionality since
// we're only testing for the presence of UI elements

void main() {
  const testId = 'test-ai-response-id';
  final testDateTime = DateTime(2023);

  final testAiResponse = AiResponseEntry(
    meta: Metadata(
      id: testId,
      dateFrom: testDateTime,
      dateTo: testDateTime,
      createdAt: testDateTime,
      updatedAt: testDateTime,
    ),
    data: const AiResponseData(
      model: 'gpt-4',
      temperature: 0.7,
      systemMessage: '# System Message\nYou are a helpful assistant.',
      prompt: '# User Prompt\nWhat is the meaning of life?',
      thoughts:
          '# Thinking Process\nThis is a philosophical question that has been debated for centuries.',
      response:
          '# Response\nThe meaning of life is subjective and varies from person to person.',
      type: AiResponseType.taskSummary,
    ),
  );

  group('AiResponseSummaryModalContent', () {
    testWidgets('renders all tabs', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: AiResponseSummaryModalContent(
            testAiResponse,
            linkedFromId: 'linked-id',
          ),
        ),
      );

      // Check for the tab bar
      expect(find.text('Setup'), findsOneWidget);
      expect(find.text('Input'), findsOneWidget);
      expect(find.text('Thoughts'), findsOneWidget);
      expect(find.text('Response'), findsOneWidget);

      // Verify GptMarkdown widgets are used in all tabs
      expect(find.byType(GptMarkdown), findsWidgets);
    });

    testWidgets('displays model information in Setup tab', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: AiResponseSummaryModalContent(
            testAiResponse,
            linkedFromId: 'linked-id',
          ),
        ),
      );

      // Tab to Setup
      await tester.tap(find.text('Setup'));
      await tester.pumpAndSettle();

      // Should show model information (label and value are separate)
      expect(find.text('Model'), findsOneWidget);
      expect(find.text('gpt-4'), findsOneWidget);
      expect(find.text('Temperature'), findsOneWidget);
      expect(find.text('0.7'), findsOneWidget);

      // Verify GptMarkdown is used for system message
      expect(find.byType(GptMarkdown), findsAtLeastNWidgets(1));
    });

    testWidgets('can navigate between tabs', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: AiResponseSummaryModalContent(
            testAiResponse,
            linkedFromId: 'linked-id',
          ),
        ),
      );

      // Verify we can navigate to each tab
      for (final tab in ['Setup', 'Input', 'Thoughts', 'Response']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();

        // Each tab should contain a GptMarkdown widget
        expect(find.byType(GptMarkdown), findsAtLeastNWidgets(1));
      }
    });

    testWidgets('has GestureDetector for copying text in Input tab',
        (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: AiResponseSummaryModalContent(
            testAiResponse,
            linkedFromId: 'linked-id',
          ),
        ),
      );

      // Navigate to Input tab
      await tester.tap(find.text('Input'));
      await tester.pumpAndSettle();

      // There should be a GestureDetector somewhere in the widget tree
      expect(
        find.descendant(
          of: find.byType(TabBarView),
          matching: find.byType(GestureDetector),
        ),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('has SelectionArea for text selection', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: AiResponseSummaryModalContent(
            testAiResponse,
            linkedFromId: 'linked-id',
          ),
        ),
      );

      // Verify each tab has SelectionArea
      for (final tabName in ['Setup', 'Input', 'Thoughts', 'Response']) {
        await tester.tap(find.text(tabName));
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(TabBarView),
            matching: find.byType(SelectionArea),
          ),
          findsAtLeastNWidgets(1),
        );
      }
    });

    testWidgets('displays token usage when available', (tester) async {
      final aiResponseWithUsage = AiResponseEntry(
        meta: Metadata(
          id: 'usage-id',
          dateFrom: testDateTime,
          dateTo: testDateTime,
          createdAt: testDateTime,
          updatedAt: testDateTime,
        ),
        data: const AiResponseData(
          model: 'gemini-3-flash',
          temperature: 0.6,
          systemMessage: 'System',
          prompt: 'Prompt',
          thoughts: 'Thoughts',
          response: 'Response',
          inputTokens: 1000,
          outputTokens: 500,
          thoughtsTokens: 250,
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: AiResponseSummaryModalContent(
            aiResponseWithUsage,
            linkedFromId: 'linked-id',
          ),
        ),
      );

      // Navigate to Setup tab
      await tester.tap(find.text('Setup'));
      await tester.pumpAndSettle();

      // Should show Performance section
      expect(find.text('Performance'), findsOneWidget);
      expect(find.text('Token Usage'), findsOneWidget);

      // Should show token counts (Input label appears both in tabs and in usage)
      expect(find.text('Input'), findsAtLeastNWidgets(1));
      expect(find.text('1000'), findsOneWidget);
      expect(find.text('Output'), findsOneWidget);
      expect(find.text('500'), findsOneWidget);
      expect(find.text('250'), findsOneWidget); // Thoughts tokens
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('1500'), findsOneWidget);
    });

    testWidgets('displays duration when available', (tester) async {
      final aiResponseWithDuration = AiResponseEntry(
        meta: Metadata(
          id: 'duration-id',
          dateFrom: testDateTime,
          dateTo: testDateTime,
          createdAt: testDateTime,
          updatedAt: testDateTime,
        ),
        data: const AiResponseData(
          model: 'gemini-3-flash',
          temperature: 0.6,
          systemMessage: 'System',
          prompt: 'Prompt',
          thoughts: 'Thoughts',
          response: 'Response',
          durationMs: 2500,
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: AiResponseSummaryModalContent(
            aiResponseWithDuration,
            linkedFromId: 'linked-id',
          ),
        ),
      );

      // Navigate to Setup tab
      await tester.tap(find.text('Setup'));
      await tester.pumpAndSettle();

      // Should show Performance section with duration
      expect(find.text('Performance'), findsOneWidget);
      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('2.5s'), findsOneWidget);
    });

    testWidgets('formats duration in minutes when >= 60s', (tester) async {
      final aiResponseWithLongDuration = AiResponseEntry(
        meta: Metadata(
          id: 'long-duration-id',
          dateFrom: testDateTime,
          dateTo: testDateTime,
          createdAt: testDateTime,
          updatedAt: testDateTime,
        ),
        data: const AiResponseData(
          model: 'gemini-3-pro',
          temperature: 0.6,
          systemMessage: 'System',
          prompt: 'Prompt',
          thoughts: 'Thoughts',
          response: 'Response',
          durationMs: 95000, // 1m 35s
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: AiResponseSummaryModalContent(
            aiResponseWithLongDuration,
            linkedFromId: 'linked-id',
          ),
        ),
      );

      // Navigate to Setup tab
      await tester.tap(find.text('Setup'));
      await tester.pumpAndSettle();

      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('1m 35s'), findsOneWidget);
    });

    testWidgets('formats duration in ms when < 1s', (tester) async {
      final aiResponseWithShortDuration = AiResponseEntry(
        meta: Metadata(
          id: 'short-duration-id',
          dateFrom: testDateTime,
          dateTo: testDateTime,
          createdAt: testDateTime,
          updatedAt: testDateTime,
        ),
        data: const AiResponseData(
          model: 'gemini-3-flash',
          temperature: 0.6,
          systemMessage: 'System',
          prompt: 'Prompt',
          thoughts: 'Thoughts',
          response: 'Response',
          durationMs: 450,
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: AiResponseSummaryModalContent(
            aiResponseWithShortDuration,
            linkedFromId: 'linked-id',
          ),
        ),
      );

      // Navigate to Setup tab
      await tester.tap(find.text('Setup'));
      await tester.pumpAndSettle();

      expect(find.text('Duration'), findsOneWidget);
      expect(find.text('450ms'), findsOneWidget);
    });

    testWidgets('does not show Performance section without usage data',
        (tester) async {
      final aiResponseNoUsage = AiResponseEntry(
        meta: Metadata(
          id: 'no-usage-id',
          dateFrom: testDateTime,
          dateTo: testDateTime,
          createdAt: testDateTime,
          updatedAt: testDateTime,
        ),
        data: const AiResponseData(
          model: 'gpt-4',
          temperature: 0.7,
          systemMessage: 'System',
          prompt: 'Prompt',
          thoughts: 'Thoughts',
          response: 'Response',
          // No inputTokens, outputTokens, or durationMs
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: AiResponseSummaryModalContent(
            aiResponseNoUsage,
            linkedFromId: 'linked-id',
          ),
        ),
      );

      // Navigate to Setup tab
      await tester.tap(find.text('Setup'));
      await tester.pumpAndSettle();

      // Should NOT show Performance section
      expect(find.text('Performance'), findsNothing);
      expect(find.text('Token Usage'), findsNothing);
    });

    testWidgets('renders with minimal data', (tester) async {
      final minimalAiResponse = AiResponseEntry(
        meta: Metadata(
          id: 'minimal-id',
          dateFrom: testDateTime,
          dateTo: testDateTime,
          createdAt: testDateTime,
          updatedAt: testDateTime,
        ),
        data: const AiResponseData(
          model: 'gpt-3.5',
          temperature: 0,
          systemMessage: 'System',
          prompt: 'Prompt',
          thoughts: 'Thoughts',
          response: 'Response',
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: AiResponseSummaryModalContent(
            minimalAiResponse,
            linkedFromId: null,
          ),
        ),
      );

      // Tab to Setup tab
      await tester.tap(find.text('Setup'));
      await tester.pumpAndSettle();

      // Check that it renders model information (label and value are separate)
      expect(find.text('Model'), findsOneWidget);
      expect(find.text('gpt-3.5'), findsOneWidget);
      expect(find.text('Temperature'), findsOneWidget);
      expect(find.text('0.0'), findsOneWidget);
    });

    testWidgets('handles link tap in Response tab', (tester) async {
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

      final aiResponseWithLink = AiResponseEntry(
        meta: Metadata(
          id: 'link-id',
          dateFrom: testDateTime,
          dateTo: testDateTime,
          createdAt: testDateTime,
          updatedAt: testDateTime,
        ),
        data: const AiResponseData(
          model: 'gpt-4',
          temperature: 0.7,
          systemMessage: 'System',
          prompt: 'Prompt',
          thoughts: 'Thoughts',
          response:
              'Check the [documentation](https://docs.flutter.dev) for details.',
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: AiResponseSummaryModalContent(
            aiResponseWithLink,
            linkedFromId: 'linked-id',
          ),
        ),
      );

      // Navigate to Response tab (it's the default)
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
