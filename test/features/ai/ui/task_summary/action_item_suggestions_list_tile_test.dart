import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/ui/task_summary/action_item_suggestions_list_tile.dart';
import 'package:lotti/features/ai/ui/task_summary/ai_task_summary_list_tile.dart';

import '../../../../test_helper.dart';

void main() {
  group('AiTaskSummaryListTile', () {
    late JournalEntity mockTask;

    setUp(() {
      final now = DateTime.now();
      mockTask = Task(
        meta: Metadata(
          id: 'test-task-id',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: TaskData(
          status: TaskStatus.open(
            createdAt: now,
            id: 'test-task-id',
            utcOffset: 60,
          ),
          title: 'Test Task',
          dateFrom: now,
          dateTo: now,
          statusHistory: [],
        ),
      );
    });

    testWidgets('renders with correct icon and title', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: ActionItemSuggestionsListTile(
            journalEntity: mockTask,
            linkedFromId: 'linked-id',
            onTap: null,
          ),
        ),
      );

      // Verify the widget renders correctly
      expect(find.byIcon(Icons.chat_rounded), findsOneWidget);
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });

    testWidgets('handles null linkedFromId correctly', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: AiTaskSummaryListTile(
            journalEntity: mockTask,
            onTap: null,
          ),
        ),
      );

      // Verify the widget renders correctly with null linkedFromId
      expect(find.byType(AiTaskSummaryListTile), findsOneWidget);
      expect(find.byIcon(Icons.chat_rounded), findsOneWidget);
    });

    testWidgets('is tappable', (tester) async {
      await tester.pumpWidget(
        WidgetTestBench(
          child: AiTaskSummaryListTile(
            journalEntity: mockTask,
            linkedFromId: 'linked-id',
            onTap: () {},
          ),
        ),
      );

      // Verify the widget is tappable
      expect(tester.widget<ListTile>(find.byType(ListTile)).onTap, isNotNull);
    });
  });
}
