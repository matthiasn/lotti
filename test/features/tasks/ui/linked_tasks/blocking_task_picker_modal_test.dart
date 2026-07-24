import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/blocking_task_picker_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/entity_factories.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';

void main() {
  group('BlockingTaskPickerModal', () {
    late MockJournalDb mockJournalDb;
    late MockFts5Db mockFts5Db;
    late MockPersistenceLogic mockPersistenceLogic;
    late MockUpdateNotifications mockUpdateNotifications;

    final now = DateTime(2026, 5, 1, 12);
    const blockedTaskId = 'blocked-task';

    Task buildTask({
      required String id,
      required String title,
    }) => TestTaskFactory.create(
      id: id,
      title: title,
      createdAt: now,
      dateFrom: now,
      dateTo: now,
    );

    void stubTasks(List<Task> tasks) {
      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => tasks);
    }

    void stubExistingBlockers(List<EntryLink> links) {
      when(
        () => mockJournalDb.typedLinksForTaskIds(
          any(),
          types: any(named: 'types'),
        ),
      ).thenAnswer((_) async => links);
    }

    // Returns a completer that resolves with BlockingTaskPickerModal.show's
    // result once the sheet pops — the show() future itself can't be awaited
    // directly without blocking on the sheet closing, so callers that need
    // the eventual result (rather than just opening the sheet) await
    // `completer.future` after driving further interaction.
    Future<Completer<Task?>> openModal(WidgetTester tester) async {
      final completer = Completer<Task?>();
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  completer.complete(
                    await BlockingTaskPickerModal.show(
                      context: context,
                      blockedTaskId: blockedTaskId,
                    ),
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Modal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      return completer;
    }

    setUp(() async {
      // _selectBlocker awaits a HapticFeedback call before popping — under
      // the test binding that never resolves without a mock handler (see
      // test/README.md's "Platform-channel calls in widgets" section).
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            return null;
          });

      await getIt.reset();

      mockJournalDb = MockJournalDb();
      mockFts5Db = MockFts5Db();
      mockPersistenceLogic = MockPersistenceLogic();
      mockUpdateNotifications = MockUpdateNotifications();

      when(
        () => mockUpdateNotifications.updateStream,
      ).thenAnswer((_) => const Stream.empty());

      stubTasks(const []);
      stubExistingBlockers(const []);

      // TaskLinkGroupsController (used to compute existingBlockerIds) bulk-
      // resolves the other side of each link via this query.
      when(
        () => mockJournalDb.getJournalEntitiesForIdsUnordered(any()),
      ).thenAnswer((_) async => <JournalEntity>[]);

      when(
        () => mockFts5Db.watchFullTextMatches(any()),
      ).thenAnswer((_) => Stream.value(<String>[]));

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<Fts5Db>(mockFts5Db)
        ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications);
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      await getIt.reset();
    });

    testWidgets('renders the title and a Skip button', (tester) async {
      await openModal(tester);

      expect(find.text("What's blocking this task?"), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets(
      'tapping Skip closes the modal without creating a link',
      (tester) async {
        final completer = await openModal(tester);

        await tester.tap(find.text('Skip'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        verifyNever(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
            linkType: EntryLinkType.blocks,
          ),
        );
        expect(
          find.byKey(const Key('blocking_task_picker_modal_handle')),
          findsNothing,
        );
        expect(await completer.future, isNull);
      },
    );

    testWidgets(
      'excludes the blocked task and existing open blockers from the '
      'candidate list',
      (tester) async {
        stubTasks([
          buildTask(id: 'candidate', title: 'Candidate Task'),
          buildTask(id: 'existing-blocker', title: 'Existing Blocker'),
        ]);
        final existingBlocker = buildTask(
          id: 'existing-blocker',
          title: 'Existing Blocker',
        );
        stubExistingBlockers([
          EntryLink.blocks(
            id: 'link-1',
            fromId: 'existing-blocker',
            toId: blockedTaskId,
            createdAt: now,
            updatedAt: now,
            vectorClock: null,
          ),
        ]);
        when(
          () => mockJournalDb.getJournalEntitiesForIdsUnordered({
            'existing-blocker',
          }),
        ).thenAnswer((_) async => [existingBlocker]);

        await openModal(tester);

        expect(find.text('Candidate Task'), findsOneWidget);
        expect(find.text('Existing Blocker'), findsNothing);
      },
    );

    testWidgets(
      'selecting a task creates a blocks link with it as the blocker and '
      'pops with the chosen task',
      (tester) async {
        final blocker = buildTask(id: 'blocker-1', title: 'Blocker Task');
        stubTasks([blocker]);
        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
            linkType: EntryLinkType.blocks,
          ),
        ).thenAnswer((_) async => true);

        final completer = await openModal(tester);

        await tester.tap(find.text('Blocker Task'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        verify(
          () => mockPersistenceLogic.createLink(
            fromId: 'blocker-1',
            toId: blockedTaskId,
            linkType: EntryLinkType.blocks,
          ),
        ).called(1);

        final result = await completer.future;
        expect(result?.meta.id, 'blocker-1');
      },
    );

    testWidgets(
      'a rejected cycle guard shows an error and keeps the modal open',
      (tester) async {
        final blocker = buildTask(id: 'blocker-1', title: 'Blocker Task');
        stubTasks([blocker]);
        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
            linkType: EntryLinkType.blocks,
          ),
        ).thenAnswer((_) async => false);

        await openModal(tester);

        await tester.tap(find.text('Blocker Task'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Blocker Task'), findsOneWidget);
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );
  });
}
