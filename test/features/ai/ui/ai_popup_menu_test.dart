import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/ui/ai_popup_menu.dart';
import 'package:lotti/features/ai/ui/image_analysis/ai_image_analysis_list_tile.dart';
import 'package:lotti/features/ai/ui/task_summary/ai_task_summary_list_tile.dart';

import '../../../test_data/test_data.dart';
import '../../../test_helper.dart';

void main() {
  group('AiPopUpMenu', () {
    testWidgets('renders AI assistant icon button', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          AiPopUpMenu(
            journalEntity: testTask,
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
      expect(find.byType(AiImageAnalysisListTile), findsNothing);
    });

    testWidgets('shows AiImageAnalysisListTile when entity has image',
        (tester) async {
      final journalEntry = JournalImage(
        meta: Metadata(
          id: 'test-id',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: ImageData(
          capturedAt: DateTime.now(),
          imageId: 'test-id',
          imageFile: 'test-file',
          imageDirectory: '',
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

      expect(find.byType(AiImageAnalysisListTile), findsOneWidget);
      expect(find.byType(AiTaskSummaryListTile), findsNothing);
    });

    testWidgets('shows no AI options when journalEntity is not Task or Image',
        (tester) async {
      await tester.pumpWidget(
        createTestApp(
          AiPopUpMenu(
            journalEntity: testAudioEntry,
            linkedFromId: null,
          ),
        ),
      );

      // Tap the AI assistant button
      await tester.tap(find.byIcon(Icons.assistant_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(AiImageAnalysisListTile), findsNothing);
      expect(find.byType(AiTaskSummaryListTile), findsNothing);
    });
  });
}
