import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/ai_response_summary_modal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../../../test_helper.dart';

// Mock the clipboard for testing
class MockClipboard extends Mock implements ClipboardReader, ClipboardWriter {}

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

      // Should show model information
      expect(find.text('Model: gpt-4'), findsOneWidget);
      expect(find.text('Temperature: 0.7'), findsOneWidget);

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

      // Check that it renders model information
      expect(find.text('Model: gpt-3.5'), findsOneWidget);
      expect(find.text('Temperature: 0.0'), findsOneWidget);
    });
  });
}
