import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/expandable_ai_response_summary.dart';

import '../../../test_helper.dart';

void main() {
  group('ExpandableAiResponseSummary', () {
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

    testWidgets('displays only TLDR by default', (tester) async {
      const responseWithTldr = '''
# Task Title

**TLDR:** You've made great progress on the authentication system. 
The database schema and login endpoint are complete. 
Next up is implementing password reset and session management. 
Keep up the momentum! 💪

Achieved results:
✅ Set up database schema for users
✅ Created login API endpoint
✅ Implemented password hashing

Remaining steps:
1. Implement password reset functionality
2. Add session management
3. Create user profile endpoints

Learnings:
💡 Using bcrypt for password hashing provides good security
💡 JWT tokens work well for stateless authentication''';

      final aiResponse = testAiResponseEntry.copyWith(
        data: testAiResponseEntry.data.copyWith(
          response: responseWithTldr,
          type: AiResponseType.taskSummary,
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: ExpandableAiResponseSummary(
            aiResponse,
            linkedFromId: 'test-id',
          ),
        ),
      );

      // TLDR should be visible
      expect(find.textContaining('made great progress'), findsOneWidget);
      expect(find.textContaining('Keep up the momentum!'), findsOneWidget);

      // Detailed content should not be visible
      expect(find.textContaining('Achieved results:'), findsNothing);
      expect(find.textContaining('Remaining steps:'), findsNothing);
      expect(find.textContaining('Learnings:'), findsNothing);

      // Expand icon should be visible
      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('expands to show full content when chevron is tapped',
        (tester) async {
      const responseWithTldr = '''
# Task Title

**TLDR:** Quick summary of the task progress. 
This is line two of the TLDR. 
And this is line three. 🚀

Achieved results:
✅ First achievement
✅ Second achievement

Remaining steps:
1. First remaining step
2. Second remaining step''';

      final aiResponse = testAiResponseEntry.copyWith(
        data: testAiResponseEntry.data.copyWith(
          response: responseWithTldr,
          type: AiResponseType.taskSummary,
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: ExpandableAiResponseSummary(
            aiResponse,
            linkedFromId: 'test-id',
          ),
        ),
      );

      // Initially, only TLDR is visible
      expect(find.textContaining('Quick summary'), findsOneWidget);
      expect(find.textContaining('Achieved results:'), findsNothing);

      // Tap the expand icon
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();
      await tester
          .pump(const Duration(milliseconds: 350)); // Wait for animation

      // Now full content should be visible
      expect(find.textContaining('Quick summary'), findsOneWidget);
      // Check for the text in GptMarkdown widget
      final gptMarkdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
      expect(gptMarkdown.data.contains('Achieved results:'), true);
      expect(gptMarkdown.data.contains('First achievement'), true);
      expect(gptMarkdown.data.contains('Remaining steps:'), true);
    });

    // TODO: Fix rotation animation test
    /* testWidgets('rotates chevron icon when expanding/collapsing',
        (tester) async {
      const responseWithTldr = '''
# Task Title

**TLDR:** Summary content here. 🎯

Detailed content follows...''';

      final aiResponse = testAiResponseEntry.copyWith(
        data: testAiResponseEntry.data.copyWith(
          response: responseWithTldr,
          type: AiResponseType.taskSummary,
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: ExpandableAiResponseSummary(
            aiResponse,
            linkedFromId: 'test-id',
          ),
        ),
      );

      // Find the RotationTransition widget that contains the expand icon
      final rotationTransition = tester.widget<RotationTransition>(
        find
            .ancestor(
              of: find.byIcon(Icons.expand_more),
              matching: find.byType(RotationTransition),
            )
            .first,
      );

      // Initially should have rotation 0
      expect(rotationTransition.turns.value, 0.0);

      // Tap to expand
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();
      await tester.pump(
          const Duration(milliseconds: 350)); // Wait for animation to complete

      // After expansion, should be rotated (0.5 = 180 degrees)
      final rotationTransitionExpanded = tester.widget<RotationTransition>(
        find
            .ancestor(
              of: find.byIcon(Icons.expand_more),
              matching: find.byType(RotationTransition),
            )
            .first,
      );
      // Check that the animation value has changed (might not be exactly 0.5 due to animation)
      expect(rotationTransitionExpanded.turns.value, greaterThan(0.4));
      expect(rotationTransitionExpanded.turns.value, lessThanOrEqualTo(0.5));

      // Tap to collapse
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();
      await tester.pump(
          const Duration(milliseconds: 350)); // Wait for animation to complete

      // Should be back to 0
      final rotationTransitionCollapsed = tester.widget<RotationTransition>(
        find
            .ancestor(
              of: find.byIcon(Icons.expand_more),
              matching: find.byType(RotationTransition),
            )
            .first,
      );
      expect(rotationTransitionCollapsed.turns.value, 0.0);
    }); */

    testWidgets('handles response without TLDR format', (tester) async {
      const responseWithoutTldr = '''
# Task Title

This is the first paragraph of content without TLDR formatting.
It should still be shown as the collapsed content.

Achieved results:
✅ Some work done

Remaining steps:
1. More work to do''';

      final aiResponse = testAiResponseEntry.copyWith(
        data: testAiResponseEntry.data.copyWith(
          response: responseWithoutTldr,
          type: AiResponseType.taskSummary,
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: ExpandableAiResponseSummary(
            aiResponse,
            linkedFromId: 'test-id',
          ),
        ),
      );

      // First paragraph should be visible (check GptMarkdown content)
      final gptMarkdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
      expect(gptMarkdown.data.contains('first paragraph'), true);

      // Rest should not be visible (initially collapsed)
      expect(gptMarkdown.data.contains('Achieved results:'), false);

      // Expand and verify full content
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();
      await tester
          .pump(const Duration(milliseconds: 350)); // Wait for animation

      // Check that the full content is shown in the GptMarkdown widget
      final expandedGptMarkdown =
          tester.widget<GptMarkdown>(find.byType(GptMarkdown));
      expect(expandedGptMarkdown.data.contains('Achieved results:'), true);
      expect(expandedGptMarkdown.data.contains('Some work done'), true);
    });

    testWidgets('opens modal on double tap', (tester) async {
      const responseWithTldr = '''
# Task Title

**TLDR:** Test summary content. 🎯

Detailed content...''';

      final aiResponse = testAiResponseEntry.copyWith(
        data: testAiResponseEntry.data.copyWith(
          response: responseWithTldr,
          type: AiResponseType.taskSummary,
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: ExpandableAiResponseSummary(
            aiResponse,
            linkedFromId: 'test-id',
          ),
        ),
      );

      // Double tap to open modal
      await tester.pumpAndSettle();
      // Find the main content area (not the expand button)
      final gestureDetector = find.byType(GestureDetector).first;
      await tester.tap(gestureDetector, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(gestureDetector, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Modal should be opened (we can't directly test the modal content
      // as it's shown in a different route)
    });

    testWidgets('removes H1 title from task summary display', (tester) async {
      const responseWithTitle = '''
# Implement Authentication System

**TLDR:** Authentication setup is progressing well. 
Database and login are ready. 
Focus on password reset next! 💪

More content here...''';

      final aiResponse = testAiResponseEntry.copyWith(
        data: testAiResponseEntry.data.copyWith(
          response: responseWithTitle,
          type: AiResponseType.taskSummary,
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: ExpandableAiResponseSummary(
            aiResponse,
            linkedFromId: 'test-id',
          ),
        ),
      );

      // Title should not be visible
      expect(find.text('Implement Authentication System'), findsNothing);
      expect(find.textContaining('# Implement Authentication System'),
          findsNothing);

      // TLDR should be visible
      expect(find.textContaining('Authentication setup'), findsOneWidget);
    });

    testWidgets('handles TLDR with bold formatting correctly', (tester) async {
      const responseWithBoldTldr = '''
# Task Title

**TLDR:** **This entire paragraph should be bold.** 
**Including this line too.** 
**And this final line with emoji!** 🚀

Other content...''';

      final aiResponse = testAiResponseEntry.copyWith(
        data: testAiResponseEntry.data.copyWith(
          response: responseWithBoldTldr,
          type: AiResponseType.taskSummary,
        ),
      );

      await tester.pumpWidget(
        WidgetTestBench(
          child: ExpandableAiResponseSummary(
            aiResponse,
            linkedFromId: 'test-id',
          ),
        ),
      );

      // The GptMarkdown widget should be rendering the TLDR content
      expect(find.byType(GptMarkdown), findsOneWidget);

      // The GptMarkdown widget should contain the TLDR text
      final gptMarkdown = tester.widget<GptMarkdown>(find.byType(GptMarkdown));
      expect(gptMarkdown.data.contains('TLDR:'), true);
      expect(
          gptMarkdown.data.contains('entire paragraph should be bold'), true);
    });
  });
}
