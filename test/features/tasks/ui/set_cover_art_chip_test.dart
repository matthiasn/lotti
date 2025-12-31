import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/ui/set_cover_art_chip.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/widgets/cards/subtle_action_chip.dart';

import '../../../helpers/fake_entry_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Task buildTask({String? coverArtId, String id = 'task-1'}) {
    final now = DateTime(2025, 12, 31, 12);
    return Task(
      meta: Metadata(
        id: id,
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

  group('SetCoverArtChip', () {
    testWidgets('renders nothing when linkedFromId is null', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SetCoverArtChip(
                imageId: 'image-1',
                linkedFromId: null,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should render SizedBox.shrink when linkedFromId is null
      expect(find.byType(SubtleActionChip), findsNothing);
    });

    testWidgets('renders nothing when parent is not a Task', (tester) async {
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
              body: SetCoverArtChip(
                imageId: 'image-1',
                linkedFromId: 'entry-1',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should render SizedBox.shrink when parent is not a Task
      expect(find.byType(SubtleActionChip), findsNothing);
    });

    testWidgets('widget can be constructed with task parent', (tester) async {
      final task = buildTask();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            createEntryControllerOverride(task),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SetCoverArtChip(
                imageId: 'image-1',
                linkedFromId: 'task-1',
              ),
            ),
          ),
        ),
      );
      // Just pump once to verify widget builds without errors
      await tester.pump();

      expect(find.byType(SetCoverArtChip), findsOneWidget);
    });

    testWidgets('widget can be constructed when image is current cover',
        (tester) async {
      final task = buildTask(coverArtId: 'image-1');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            createEntryControllerOverride(task),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SetCoverArtChip(
                imageId: 'image-1',
                linkedFromId: 'task-1',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SetCoverArtChip), findsOneWidget);
    });

    testWidgets('widget can be constructed with different image id',
        (tester) async {
      final task = buildTask(coverArtId: 'other-image');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            createEntryControllerOverride(task),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SetCoverArtChip(
                imageId: 'image-1',
                linkedFromId: 'task-1',
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(SetCoverArtChip), findsOneWidget);
    });
  });
}
