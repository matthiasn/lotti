import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/components/dropdowns/design_system_dropdown.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/link_task_modal.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/relationship_type_selector.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/widgets/picker/entity_picker_sheet.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/entity_factories.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';

void main() {
  group('LinkTaskModal', () {
    late MockJournalDb mockJournalDb;
    late MockFts5Db mockFts5Db;
    late MockPersistenceLogic mockPersistenceLogic;
    late MockUpdateNotifications mockUpdateNotifications;

    final now = DateTime(2025, 12, 31, 12);

    Task buildTask({
      String id = 'task-1',
      String title = 'Test Task',
      TaskStatus? status,
    }) => TestTaskFactory.create(
      id: id,
      title: title,
      status: status,
      createdAt: now,
      dateFrom: now,
      dateTo: now,
    );

    // Pumps a button that opens the modal, taps it, and settles.
    Future<void> openModal(
      WidgetTester tester, {
      Set<ExistingRelation> existingRelations = const {},
      MediaQueryData? mediaQueryData,
      MockJournalRepository? journalRepo,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            if (journalRepo != null)
              journalRepositoryProvider.overrideWithValue(journalRepo),
          ],
          child: WidgetTestBench(
            mediaQueryData: mediaQueryData,
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingRelations: existingRelations,
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
    }

    // Drives the relationship dropdown by its own callback. The panel expands
    // inline inside a Wolt-hosted modal, where hit-testing an expanded row is
    // unreliable — this repo's established pattern for such controls.
    Future<void> pickRelation(WidgetTester tester, String label) async {
      final dropdown = tester.widget<DesignSystemDropdown>(
        find.byType(DesignSystemDropdown),
      );
      dropdown.onItemPressed!(
        dropdown.items.firstWhere((item) => item.label == label),
      );
      await tester.pump();
    }

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

    setUp(() async {
      // _selectTask awaits a HapticFeedback call before popping — under the
      // test binding that never resolves without a mock handler (see
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

      // Default: return empty task list
      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => <JournalEntity>[]);

      // Default: FTS returns empty
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

    testWidgets('renders title "Link existing task..."', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingRelations: const {},
                  );
                },
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );

      // Tap to open modal
      await tester.tap(find.text('Open Modal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Link existing task...'), findsOneWidget);
    });

    testWidgets('renders search field with hint', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingRelations: const {},
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

      // DesignSystemSearch renders the hint both as a visible overlay and as
      // the (transparent) TextField hint, so allow more than one match.
      expect(find.text('Search tasks...'), findsWidgets);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    });

    testWidgets(
      'opens via the shared Wolt responsive modal, not a '
      'DraggableScrollableSheet reveal',
      (tester) async {
        await openModal(tester);

        // ModalUtils.showSinglePageModal's own responsive dialog/bottom-sheet
        // breakpoint logic is covered by test/widgets/modal/modal_utils_test.dart
        // — this just confirms LinkTaskModal no longer sizes itself via the
        // old, unprecedented DraggableScrollableSheet reveal.
        expect(find.byType(DraggableScrollableSheet), findsNothing);
      },
    );

    testWidgets(
      'renders correctly on a wide desktop viewport too — the same '
      'responsive modal path every other task-page picker uses',
      (tester) async {
        // Desktop sizing crosses WoltModalConfig.pageBreakpoint (560), so
        // ModalUtils.showSinglePageModal resolves to its dialog variant.
        await openModal(
          tester,
          mediaQueryData: const MediaQueryData(size: Size(1280, 900)),
        );

        expect(find.text('Link existing task...'), findsOneWidget);
        expect(find.byType(DraggableScrollableSheet), findsNothing);
      },
    );

    testWidgets('displays tasks from database', (tester) async {
      final testTasks = [
        buildTask(title: 'First Task'),
        buildTask(id: 'task-2', title: 'Second Task'),
      ];

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => testTasks);

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingRelations: const {},
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

      expect(find.text('First Task'), findsOneWidget);
      expect(find.text('Second Task'), findsOneWidget);
    });

    testWidgets('excludes current task from results', (tester) async {
      final testTasks = [
        buildTask(id: 'current-task', title: 'Current Task'),
        buildTask(id: 'other-task', title: 'Other Task'),
      ];

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => testTasks);

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingRelations: const {},
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

      // Current task should be filtered out
      expect(find.text('Current Task'), findsNothing);
      expect(find.text('Other Task'), findsOneWidget);
    });

    testWidgets('excludes already linked tasks from results', (tester) async {
      final testTasks = [
        buildTask(id: 'linked-task', title: 'Already Linked'),
        buildTask(id: 'available-task', title: 'Available Task'),
      ];

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => testTasks);

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingRelations: {
                      const ExistingRelation(
                        taskId: 'linked-task',
                        relation: DirectedRelation(EntryLinkType.basic),
                      ),
                    },
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

      // Already linked task should be filtered out
      expect(find.text('Already Linked'), findsNothing);
      expect(find.text('Available Task'), findsOneWidget);
    });

    testWidgets('shows status icons for tasks', (tester) async {
      final testTasks = [
        buildTask(
          title: 'Open Task',
          status: TaskStatus.open(id: 's1', createdAt: now, utcOffset: 0),
        ),
        buildTask(
          id: 'task-2',
          title: 'In Progress Task',
          status: TaskStatus.inProgress(id: 's2', createdAt: now, utcOffset: 0),
        ),
      ];

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => testTasks);

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingRelations: const {},
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

      // Status icons should be present
      expect(find.byIcon(taskIconFromStatusString('OPEN')), findsOneWidget);
      expect(
        find.byIcon(taskIconFromStatusString('IN PROGRESS')),
        findsOneWidget,
      );
    });

    testWidgets('shows no tasks message when no tasks available', (
      tester,
    ) async {
      // Default mock returns empty list
      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingRelations: const {},
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

      expect(find.text('No tasks available to link'), findsOneWidget);
    });

    testWidgets(
      'filters tasks by search query immediately — no debounce, results '
      'update on the very next pump after typing',
      (tester) async {
        final testTasks = [
          buildTask(title: 'Apple Task'),
          buildTask(id: 'task-2', title: 'Banana Task'),
          buildTask(id: 'task-3', title: 'Cherry Task'),
        ];

        when(
          () => mockJournalDb.getTasks(
            starredStatuses: any(named: 'starredStatuses'),
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: any(named: 'categoryIds'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => testTasks);

        await tester.pumpWidget(
          ProviderScope(
            child: WidgetTestBench(
              child: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    await LinkTaskModal.show(
                      context: context,
                      currentTaskId: 'current-task',
                      existingRelations: const {},
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

        // All tasks should be visible initially
        expect(find.text('Apple Task'), findsOneWidget);
        expect(find.text('Banana Task'), findsOneWidget);
        expect(find.text('Cherry Task'), findsOneWidget);

        // Enter search query. _onSearchChanged fires per keystroke and awaits
        // the FTS future directly (no debounce timer), so a single pump after
        // typing must already show the filtered list.
        await tester.enterText(find.byType(TextField), 'banana');
        await tester.pump();

        // Only matching task should be visible
        expect(find.text('Apple Task'), findsNothing);
        expect(find.text('Banana Task'), findsOneWidget);
        expect(find.text('Cherry Task'), findsNothing);
      },
    );

    testWidgets('shows no tasks found when search has no matches', (
      tester,
    ) async {
      final testTasks = [
        buildTask(title: 'Apple Task'),
      ];

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => testTasks);

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingRelations: const {},
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

      // Enter search query with no matches
      await tester.enterText(find.byType(TextField), 'xyz123');
      await tester.pump();

      expect(find.text('No tasks found'), findsOneWidget);
    });

    testWidgets(
      'transitions from a populated list to the "No tasks found" empty state '
      'when a search query eliminates every result',
      (tester) async {
        stubTasks([buildTask(title: 'Apple Task')]);

        await openModal(tester);

        // Before searching: the task is shown and neither empty-state message
        // (initial vs. no-match) is present.
        expect(find.text('Apple Task'), findsOneWidget);
        expect(find.text('No tasks available to link'), findsNothing);
        expect(find.text('No tasks found'), findsNothing);

        // A query with no FTS5 match (default stub) and no title-substring
        // match filters the single task out.
        await tester.enterText(find.byType(TextField), 'xyz123');
        await tester.pump();

        // After searching: the list collapses to the *non-empty-query* empty
        // state (noTasksFound), distinct from the initial noTasksToLink state.
        expect(find.text('Apple Task'), findsNothing);
        expect(find.text('No tasks found'), findsOneWidget);
        expect(find.text('No tasks available to link'), findsNothing);
      },
    );

    testWidgets('clear button clears search text', (tester) async {
      final testTasks = [
        buildTask(),
      ];

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => testTasks);

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingRelations: const {},
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

      // Enter search text
      await tester.enterText(find.byType(TextField), 'search text');
      await tester.pump();

      // Clear button should appear
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);

      // Tap clear button
      await tester.tap(find.byIcon(Icons.cancel_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Search field should be empty
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
    });

    testWidgets('tapping task creates link and closes modal', (tester) async {
      final testTask = buildTask(id: 'task-to-link', title: 'Task to Link');

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [testTask]);

      when(
        () => mockPersistenceLogic.createLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
          // ignore: avoid_redundant_argument_values
          linkType: EntryLinkType.basic,
        ),
      ).thenAnswer((_) async => true);

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingRelations: const {},
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

      // Tap the task
      await tester.tap(find.text('Task to Link'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verify link was created as a plain (basic) link, the default
      verify(
        () => mockPersistenceLogic.createLink(
          fromId: 'current-task',
          toId: 'task-to-link',
          // ignore: avoid_redundant_argument_values
          linkType: EntryLinkType.basic,
        ),
      ).called(1);
      // The modal actually pops on success, not just createLink firing.
      expect(find.text('Link existing task...'), findsNothing);
    });

    testWidgets(
      'a committed link is confirmed with an Undo that removes exactly the '
      'relation just written',
      (tester) async {
        final repo = MockJournalRepository();
        when(
          () => repo.removeTypedLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
            linkType: any(named: 'linkType'),
          ),
        ).thenAnswer((_) async => 1);
        stubTasks([buildTask(id: 'blocker-task', title: 'Blocker Task')]);
        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
            linkType: EntryLinkType.blocks,
          ),
        ).thenAnswer((_) async => true);

        await openModal(tester, journalRepo: repo);
        await pickRelation(tester, 'Is blocked by');
        await tester.tap(find.text('Blocker Task'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Names the relation and the task, so the confirmation says what was
        // actually written rather than just "linked".
        expect(find.text('Is blocked by: Blocker Task'), findsWidgets);

        await tester.tap(find.text('Undo').last);
        await tester.pump();

        // The exact triple the link was created under — not a broader removal
        // that could take out another relationship the pair also holds.
        verify(
          () => repo.removeTypedLink(
            fromId: 'blocker-task',
            toId: 'current-task',
            linkType: 'BlocksLink',
          ),
        ).called(1);
      },
    );

    testWidgets(
      'a rejected link is not confirmed and offers no undo',
      (tester) async {
        stubTasks([buildTask(id: 'blocker-task', title: 'Blocker Task')]);
        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
            linkType: EntryLinkType.blocks,
          ),
        ).thenAnswer((_) async => false);

        await openModal(tester);
        await pickRelation(tester, 'Blocks');
        await tester.tap(find.text('Blocker Task'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Undo'), findsNothing);
        expect(
          find.text(
            'This would create a blocking cycle — choose a different task.',
          ),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'a task already linked by one relation stays a candidate for a '
      'different one — a pair may hold several relationships',
      (tester) async {
        stubTasks([buildTask(id: 'linked-task', title: 'Already Linked')]);

        await openModal(
          tester,
          existingRelations: {
            const ExistingRelation(
              taskId: 'linked-task',
              relation: DirectedRelation(EntryLinkType.basic),
            ),
          },
        );

        // Excluded while the duplicate relation is selected...
        expect(find.text('Already Linked'), findsNothing);

        // ...and offered again as soon as a different one is.
        await pickRelation(tester, 'Blocks');
        expect(find.text('Already Linked'), findsOneWidget);
      },
    );

    testWidgets(
      'direction counts as part of the relation — the inverse of an existing '
      'link is still offerable',
      (tester) async {
        stubTasks([buildTask(id: 'blocker-task', title: 'Blocker Task')]);

        await openModal(
          tester,
          existingRelations: {
            const ExistingRelation(
              taskId: 'blocker-task',
              relation: DirectedRelation(EntryLinkType.blocks),
            ),
          },
        );

        await pickRelation(tester, 'Blocks');
        expect(find.text('Blocker Task'), findsNothing);

        await pickRelation(tester, 'Is blocked by');
        expect(find.text('Blocker Task'), findsOneWidget);
      },
    );

    testWidgets(
      'defaults to the plain link, offered as one directed-relation control',
      (tester) async {
        await openModal(tester);

        final dropdown = tester.widget<DesignSystemDropdown>(
          find.byType(DesignSystemDropdown),
        );
        expect(dropdown.inputLabel, 'Relates to');
        // Type and direction are a single list, so there is no second control.
        expect(find.byType(DesignSystemDropdown), findsOneWidget);
        expect(find.byType(DsSegmentedToggle<bool>), findsNothing);
      },
    );

    testWidgets(
      'picking a directed relation updates the control value in place',
      (tester) async {
        await openModal(tester);

        await pickRelation(tester, 'Is blocked by');

        final dropdown = tester.widget<DesignSystemDropdown>(
          find.byType(DesignSystemDropdown),
        );
        expect(dropdown.inputLabel, 'Is blocked by');
        expect(find.byType(DesignSystemDropdown), findsOneWidget);
      },
    );

    testWidgets(
      'selecting "Blocks" creates a blocks link in the primary direction',
      (tester) async {
        final testTask = buildTask(id: 'blocker-task', title: 'Blocker Task');
        when(
          () => mockJournalDb.getTasks(
            starredStatuses: any(named: 'starredStatuses'),
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: any(named: 'categoryIds'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [testTask]);
        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
            linkType: EntryLinkType.blocks,
          ),
        ).thenAnswer((_) async => true);

        await openModal(tester);
        await pickRelation(tester, 'Blocks');

        await tester.tap(find.text('Blocker Task'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        verify(
          () => mockPersistenceLogic.createLink(
            fromId: 'current-task',
            toId: 'blocker-task',
            linkType: EntryLinkType.blocks,
          ),
        ).called(1);
      },
    );

    testWidgets(
      'selecting the inverse phrasing swaps fromId/toId before persisting',
      (tester) async {
        final testTask = buildTask(id: 'blocker-task', title: 'Blocker Task');
        when(
          () => mockJournalDb.getTasks(
            starredStatuses: any(named: 'starredStatuses'),
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: any(named: 'categoryIds'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [testTask]);
        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
            linkType: EntryLinkType.blocks,
          ),
        ).thenAnswer((_) async => true);

        await openModal(tester);
        await pickRelation(tester, 'Is blocked by');

        await tester.tap(find.text('Blocker Task'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // "Is blocked by" + picking blocker-task ⇒ blocker-task is the
        // blocker (fromId), current-task is blocked (toId).
        verify(
          () => mockPersistenceLogic.createLink(
            fromId: 'blocker-task',
            toId: 'current-task',
            linkType: EntryLinkType.blocks,
          ),
        ).called(1);
      },
    );

    testWidgets(
      'a rejected cycle guard shows an error and keeps the modal open',
      (tester) async {
        final testTask = buildTask(id: 'blocker-task', title: 'Blocker Task');
        when(
          () => mockJournalDb.getTasks(
            starredStatuses: any(named: 'starredStatuses'),
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: any(named: 'categoryIds'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [testTask]);
        when(
          () => mockPersistenceLogic.createLink(
            fromId: any(named: 'fromId'),
            toId: any(named: 'toId'),
            linkType: EntryLinkType.blocks,
          ),
        ).thenAnswer((_) async => false);

        await openModal(tester);
        await pickRelation(tester, 'Blocks');

        await tester.tap(find.text('Blocker Task'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Blocker Task'), findsOneWidget);
        // The Wolt-hosted picker can transiently mount two SnackBar widget
        // instances for a single logical show (a benign rendering artifact
        // also seen in edit_link_type_modal_test.dart) — assert on content.
        expect(
          find.text(
            'This would create a blocking cycle — choose a different task.',
          ),
          findsWidgets,
        );
      },
    );

    testWidgets('shows status labels for blocked tasks', (tester) async {
      final blockedTask = buildTask(
        title: 'Blocked Task',
        status: TaskStatus.blocked(
          id: 's1',
          createdAt: now,
          utcOffset: 0,
          reason: 'Test reason',
        ),
      );

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [blockedTask]);

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingRelations: const {},
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

      expect(find.text('Blocked'), findsOneWidget);
      expect(find.byIcon(taskIconFromStatusString('BLOCKED')), findsOneWidget);
    });

    testWidgets('shows status labels for on hold tasks', (tester) async {
      final onHoldTask = buildTask(
        title: 'On Hold Task',
        status: TaskStatus.onHold(
          id: 's1',
          createdAt: now,
          utcOffset: 0,
          reason: 'Test reason',
        ),
      );

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [onHoldTask]);

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingRelations: const {},
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

      expect(find.text('On Hold'), findsOneWidget);
      expect(find.byIcon(taskIconFromStatusString('ON HOLD')), findsOneWidget);
    });

    testWidgets('shows status labels for groomed tasks', (tester) async {
      final groomedTask = buildTask(
        title: 'Groomed Task',
        status: TaskStatus.groomed(id: 's1', createdAt: now, utcOffset: 0),
      );

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [groomedTask]);

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingRelations: const {},
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

      expect(find.text('Groomed'), findsOneWidget);
      expect(find.byIcon(taskIconFromStatusString('GROOMED')), findsOneWidget);
    });

    testWidgets('FTS5 matches are used for filtering', (tester) async {
      final testTasks = [
        buildTask(title: 'Apple Task'),
        buildTask(id: 'task-2', title: 'Banana Task'),
      ];

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => testTasks);

      // FTS5 returns task-2 as a match
      when(
        () => mockFts5Db.watchFullTextMatches('special'),
      ).thenAnswer((_) => Stream.value(['task-2']));

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingRelations: const {},
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

      // Enter search that matches via FTS5. Unlike the plain-substring case,
      // this needs a second pump: the FTS5 fetch is now kicked off as a
      // build-time side effect of TaskSearchPickerBody's entriesBuilder (one
      // rebuild hop further from the keystroke than the old direct
      // onChanged-triggered fetch), so the result lands one frame later.
      await tester.enterText(find.byType(TextField), 'special');
      await tester.pump();
      await tester.pump();

      // Task-2 should be visible because FTS5 matched it
      expect(find.text('Banana Task'), findsOneWidget);
    });

    testWidgets('handles FTS5 error gracefully', (tester) async {
      final testTasks = [
        buildTask(),
      ];

      when(
        () => mockJournalDb.getTasks(
          starredStatuses: any(named: 'starredStatuses'),
          taskStatuses: any(named: 'taskStatuses'),
          categoryIds: any(named: 'categoryIds'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => testTasks);

      // FTS5 throws an error
      when(
        () => mockFts5Db.watchFullTextMatches(any()),
      ).thenAnswer((_) => Stream.error(Exception('FTS5 error')));

      await tester.pumpWidget(
        ProviderScope(
          child: WidgetTestBench(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await LinkTaskModal.show(
                    context: context,
                    currentTaskId: 'current-task',
                    existingRelations: const {},
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

      // Enter search
      await tester.enterText(find.byType(TextField), 'test');
      await tester.pump();

      // Should fallback to title matching
      expect(find.text('Test Task'), findsOneWidget);
    });

    testWidgets(
      'ignores a stale FTS5 result that resolves after a newer query',
      (tester) async {
        final testTasks = [
          buildTask(title: 'Apple Task'),
          buildTask(id: 'task-2', title: 'Banana Task'),
        ];

        when(
          () => mockJournalDb.getTasks(
            starredStatuses: any(named: 'starredStatuses'),
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: any(named: 'categoryIds'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => testTasks);

        final staleController = StreamController<List<String>>();
        when(
          () => mockFts5Db.watchFullTextMatches('stale'),
        ).thenAnswer((_) => staleController.stream);
        when(
          () => mockFts5Db.watchFullTextMatches('fresh'),
        ).thenAnswer((_) => Stream.value(['task-2']));

        await openModal(tester);

        // Type the query whose FTS5 lookup will resolve LATE...
        await tester.enterText(find.byType(TextField), 'stale');
        await tester.pump();
        // ...then type a newer query whose lookup resolves immediately.
        await tester.enterText(find.byType(TextField), 'fresh');
        await tester.pump();
        await tester.pump();

        // Now let the stale lookup resolve, after the fresh one already did.
        staleController.add(['task-1']);
        await staleController.close();
        await tester.pump();

        // The fresh query's match must win — the stale result must not
        // overwrite it.
        expect(find.text('Banana Task'), findsOneWidget);
        expect(find.text('Apple Task'), findsNothing);
      },
    );

    testWidgets(
      'shows no-tasks message when loading tasks throws (catch branch)',
      (tester) async {
        // getTasks throws -> _loadTasks catch sets _isLoading = false and
        // leaves _tasks empty, so the empty-state message is shown.
        when(
          () => mockJournalDb.getTasks(
            starredStatuses: any(named: 'starredStatuses'),
            taskStatuses: any(named: 'taskStatuses'),
            categoryIds: any(named: 'categoryIds'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(Exception('db failure'));

        await openModal(tester);

        // Loading spinner must be gone (catch branch flipped _isLoading)...
        expect(find.byType(CircularProgressIndicator), findsNothing);
        // ...and the empty list yields the "no tasks" message.
        expect(find.text('No tasks available to link'), findsOneWidget);
      },
    );

    // Covers the done/rejected arms of both _getStatusLabel and
    // _getStatusIcon, which the other status tests do not exercise.
    final terminalStatuses = <String, ({TaskStatus status, IconData icon})>{
      'Done': (
        status: TaskStatus.done(id: 's-done', createdAt: now, utcOffset: 0),
        icon: taskIconFromStatusString('DONE'),
      ),
      'Rejected': (
        status: TaskStatus.rejected(
          id: 's-rejected',
          createdAt: now,
          utcOffset: 0,
        ),
        icon: taskIconFromStatusString('REJECTED'),
      ),
    };

    for (final entry in terminalStatuses.entries) {
      final label = entry.key;
      final status = entry.value.status;
      final icon = entry.value.icon;

      testWidgets('shows $label status label and icon', (tester) async {
        stubTasks([buildTask(title: '$label Task', status: status)]);

        await openModal(tester);

        expect(find.text(label), findsOneWidget);
        // Rejected's icon (Icons.close_rounded) is also the Wolt modal's own
        // close button — scope to the picker list so the two don't collide.
        expect(
          find.descendant(
            of: find.byType(EntityPickerSheet),
            matching: find.byIcon(icon),
          ),
          findsOneWidget,
        );
      });
    }
  });
}
