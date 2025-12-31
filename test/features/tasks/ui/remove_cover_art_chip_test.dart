import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/ui/remove_cover_art_chip.dart';
import 'package:lotti/l10n/app_localizations.dart';

import '../../../helpers/fake_entry_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Task buildTask({String? coverArtId}) {
    final now = DateTime(2025, 12, 31, 12);
    return Task(
      meta: Metadata(
        id: 'task-1',
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: 'status-1',
          createdAt: now,
          utcOffset: 0,
        ),
        dateFrom: now,
        dateTo: now,
        statusHistory: const [],
        title: 'Test Task',
        coverArtId: coverArtId,
      ),
    );
  }

  group('RemoveCoverArtChip', () {
    testWidgets('renders nothing when task has no coverArtId', (tester) async {
      final task = buildTask(); // No coverArtId

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            createEntryControllerOverride(task),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: RemoveCoverArtChip(taskId: 'task-1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should render SizedBox.shrink when no cover art
      expect(find.byType(GestureDetector), findsNothing);
    });

    testWidgets('renders nothing when entry is not a Task', (tester) async {
      final now = DateTime(2025, 12, 31, 12);
      final textEntry = JournalEntry(
        meta: Metadata(
          id: 'entry-1',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
        ),
        entryText: const EntryText(plainText: 'Not a task'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            createEntryControllerOverride(textEntry),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: RemoveCoverArtChip(taskId: 'entry-1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should render nothing when not a Task
      expect(find.byType(GestureDetector), findsNothing);
    });

    testWidgets('widget can be constructed with coverArtId', (tester) async {
      // Basic construction test - verifies widget accepts parameters
      final task = buildTask(coverArtId: 'image-123');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            createEntryControllerOverride(task),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: RemoveCoverArtChip(taskId: 'task-1'),
            ),
          ),
        ),
      );
      // Just pump once - widget should build without errors
      await tester.pump();

      // Widget should exist in tree
      expect(find.byType(RemoveCoverArtChip), findsOneWidget);
    });
  });
}
