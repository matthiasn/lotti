import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/ui/ai_popup_menu.dart';
import 'package:lotti/features/ai/ui/checklist/ai_checklist_list_tile.dart';
import 'package:lotti/features/ai/ui/task_summary/ai_task_summary_list_tile.dart';

import '../../../test_helper.dart';

void main() {
  group('AiPopUpMenu', () {
    testWidgets('renders AI assistant icon button', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const AiPopUpMenu(
            journalEntity: null,
            linkedFromId: null,
          ),
        ),
      );

      expect(find.byIcon(Icons.assistant_rounded), findsOneWidget);
    });

    testWidgets('shows AiTaskSummaryListTile when entity is Task',
        (tester) async {
      final now = DateTime.now();
      final task = Task(
        meta: Metadata(
          id: 'test-id',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        data: TaskData(
          status: TaskStatus.open(
            createdAt: DateTime.now(),
            id: 'test-id',
            utcOffset: 60,
          ),
          title: 'Test Task',
          dateFrom: now,
          dateTo: now,
          statusHistory: [],
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          AiPopUpMenu(
            journalEntity: task,
            linkedFromId: 'linked-id',
          ),
        ),
      );

      // Tap the AI assistant button
      await tester.tap(find.byIcon(Icons.assistant_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(AiTaskSummaryListTile), findsOneWidget);
      expect(find.byType(AiChecklistListTile), findsNothing);
    });

    testWidgets('shows AiChecklistListTile when entity is not Task',
        (tester) async {
      final journalEntry = JournalEntry(
        meta: Metadata(
          id: 'test-id',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          AiPopUpMenu(
            journalEntity: journalEntry,
            linkedFromId: 'linked-id',
          ),
        ),
      );

      // Tap the AI assistant button
      await tester.tap(find.byIcon(Icons.assistant_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(AiChecklistListTile), findsOneWidget);
      expect(find.byType(AiTaskSummaryListTile), findsNothing);
    });

    testWidgets('shows AiChecklistListTile when journalEntity is null',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const AiPopUpMenu(
            journalEntity: null,
            linkedFromId: null,
          ),
        ),
      );

      // Tap the AI assistant button
      await tester.tap(find.byIcon(Icons.assistant_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(AiChecklistListTile), findsOneWidget);
      expect(find.byType(AiTaskSummaryListTile), findsNothing);
    });
  });
}
