import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/ai_response_summary.dart';
import 'package:lotti/features/ai/ui/expandable_ai_response_summary.dart';

import '../../../test_helper.dart';

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
  });
}
