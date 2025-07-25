import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
1. Add password reset functionality
2. Implement session management
3. Add OAuth integration

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
      await tester.pump(); // Start the animation

      // Pump a few frames to let the animation progress
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Now full content should be visible
      expect(find.textContaining('Quick summary'), findsOneWidget);
      // Check that the expanded content is visible
      expect(find.textContaining('Achieved results:'), findsOneWidget);
      expect(find.textContaining('First achievement'), findsOneWidget);
      expect(find.textContaining('Remaining steps:'), findsOneWidget);
    });

    testWidgets('handles response without TLDR format', (tester) async {
      const responseWithoutTldr = '''
This is just the first paragraph of content.

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

      // First paragraph should be visible
      expect(find.textContaining('first paragraph'), findsOneWidget);

      // Rest should not be visible (initially collapsed)
      expect(find.textContaining('Achieved results:'), findsNothing);

      // Expand and verify full content
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump(); // Start the animation

      // Pump a few frames to let the animation progress
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Check that the full content is now visible
      expect(find.textContaining('Achieved results:'), findsOneWidget);
      expect(find.textContaining('Some work done'), findsOneWidget);
    });

    testWidgets('removes H1 title from task summary display', (tester) async {
      const responseWithTitle = '''
# Task Title to be Removed

**TLDR:** This summary should be visible. 📋

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
      expect(find.text('Task Title to be Removed'), findsNothing);
      expect(find.text('# Task Title to be Removed'), findsNothing);

      // TLDR should be visible
      expect(find.textContaining('This summary should be visible'),
          findsOneWidget);
    });

    testWidgets('handles TLDR with bold formatting correctly', (tester) async {
      const responseWithBoldTldr = '''
# Task Title

**TLDR:** **This entire paragraph should be bold. 
Including this second line. 
And this third line with emoji 🎉**

Additional content after TLDR...''';

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

      // TLDR content should be visible
      expect(find.textContaining('entire paragraph should be bold'),
          findsOneWidget);
    });
  });
}
