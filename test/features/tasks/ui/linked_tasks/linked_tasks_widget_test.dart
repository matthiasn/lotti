import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/state/linked_from_entries_controller.dart';
import 'package:lotti/features/tasks/state/linked_tasks_controller.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/link_task_modal.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_tasks_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../features/categories/test_utils.dart';
import '../../../../helpers/fake_entry_controller.dart';
import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../../../widget_test_utils.dart';

void main() {
  final now = DateTime(2025, 12, 31, 12);

  Task buildTask({
    String id = 'task-1',
    String title = 'Test Task',
    TaskStatus? status,
  }) {
    return Task(
      meta: Metadata(
        id: id,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      ),
      data: TaskData(
        status:
            status ??
            TaskStatus.open(
              id: 'status-1',
              createdAt: now,
              utcOffset: 0,
            ),
        dateFrom: now,
        dateTo: now,
        statusHistory: const [],
        title: title,
      ),
    );
  }

  Future<MockJournalRepository> pumpWidget(
    WidgetTester tester, {
    required List<JournalEntity> incoming,
    required List<Task> outgoing,
    bool manageMode = false,
    MediaQueryData? mediaQueryData,
    List<Override> extraOverrides = const [],
  }) async {
    final journalRepo = MockJournalRepository();
    when(
      () => journalRepo.removeLink(
        fromId: any(named: 'fromId'),
        toId: any(named: 'toId'),
      ),
    ).thenAnswer((_) async => 1);

    final outgoingLinks = outgoing
        .map(
          (t) => EntryLink.basic(
            id: 'link-${t.meta.id}',
            fromId: 'task-main',
            toId: t.meta.id,
            createdAt: now,
            updatedAt: now,
            vectorClock: null,
          ),
        )
        .toList();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          linkedTasksControllerProvider(taskId: 'task-main').overrideWith(
            manageMode
                ? MockLinkedTasksControllerManageMode.new
                : LinkedTasksController.new,
          ),
          outgoingLinkedTasksProvider('task-main').overrideWith(
            (ref) => outgoing,
          ),
          linkedFromEntriesControllerProvider(id: 'task-main').overrideWith(
            () => MockLinkedFromEntriesController(incoming),
          ),
          linkedEntriesControllerProvider(id: 'task-main').overrideWith(
            () => MockLinkedEntriesController(outgoingLinks),
          ),
          journalRepositoryProvider.overrideWithValue(journalRepo),
          ...extraOverrides,
        ],
        child: WidgetTestBench(
          mediaQueryData: mediaQueryData,
          child: const LinkedTasksWidget(taskId: 'task-main'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return journalRepo;
  }

  late MockNavService mockNavService;
  late MockFts5Db mockFts5Db;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockVectorClockService mockVectorClockService;
  late TestGetItMocks getItMocks;

  setUpAll(registerAllFallbackValues);

  setUp(() async {
    mockNavService = MockNavService();
    mockFts5Db = MockFts5Db();
    mockPersistenceLogic = MockPersistenceLogic();
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockVectorClockService = MockVectorClockService();

    when(
      () => mockFts5Db.watchFullTextMatches(any()),
    ).thenAnswer((_) => Stream.value(<String>[]));

    getItMocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<NavService>(mockNavService)
          ..registerSingleton<Fts5Db>(mockFts5Db)
          ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
          ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
          ..registerSingleton<VectorClockService>(mockVectorClockService)
          // Eagerly read by EntryController's field initializer; the
          // create-new-linked-task flow reads entryControllerProvider to
          // inherit the parent category.
          ..registerSingleton<EditorStateService>(MockEditorStateService());
      },
    );

    when(
      () => getItMocks.journalDb.getTasks(
        starredStatuses: any(named: 'starredStatuses'),
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => <JournalEntity>[]);

    // Project inheritance runs after creating a linked task; with no project
    // for the source task it returns early without touching the VC service.
    when(
      () => getItMocks.journalDb.getProjectForTask(any()),
    ).thenAnswer((_) async => null);
  });

  tearDown(() async {
    await tearDownTestGetIt();
  });

  group('LinkedTasksWidget rendering', () {
    testWidgets('hides entirely when no linked tasks', (tester) async {
      await pumpWidget(tester, incoming: [], outgoing: []);

      expect(find.text('Linked Tasks'), findsNothing);
      expect(find.byType(SvgPicture), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('shows title and count badge for linked tasks', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        incoming: [buildTask(id: 'in-1', title: 'Incoming')],
        outgoing: [
          buildTask(id: 'out-1', title: 'Outgoing 1'),
          buildTask(id: 'out-2', title: 'Outgoing 2'),
        ],
      );

      expect(find.text('Linked Tasks'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets(
      'badge count reflects only Task entities, not generic entries',
      (tester) async {
        final task = buildTask(title: 'Real Task');
        final textEntry = JournalEntry(
          meta: Metadata(
            id: 'text-entry',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
          ),
          entryText: const EntryText(plainText: 'Some text'),
        );

        await pumpWidget(
          tester,
          incoming: [task, textEntry],
          outgoing: [],
        );

        expect(find.text('Real Task'), findsOneWidget);
        expect(find.text('Some text'), findsNothing);
        expect(find.text('1'), findsOneWidget);
      },
    );

    testWidgets(
      'renders to-row for outgoing tasks with subdirectory_arrow_right',
      (tester) async {
        await pumpWidget(
          tester,
          incoming: [],
          outgoing: [buildTask(id: 'out-1', title: 'Outgoing Task')],
        );

        expect(find.text('to'), findsOneWidget);
        expect(find.text('Outgoing Task'), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);

        final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
        // Asset glyphs are wired via SvgAssetLoader; verify the loader points
        // at the outgoing arrow asset.
        expect(
          svg.bytesLoader.toString(),
          contains('subdirectory_arrow_right'),
        );
      },
    );

    testWidgets(
      'renders from-row for incoming tasks with subdirectory_arrow_left',
      (tester) async {
        await pumpWidget(
          tester,
          incoming: [buildTask(id: 'in-1', title: 'Incoming Task')],
          outgoing: [],
        );

        expect(find.text('from'), findsOneWidget);
        expect(find.text('Incoming Task'), findsOneWidget);

        final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
        expect(svg.bytesLoader.toString(), contains('subdirectory_arrow_left'));
      },
    );

    testWidgets('renders both directions and a divider between rows', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        incoming: [buildTask(id: 'in-1', title: 'Incoming Task')],
        outgoing: [
          buildTask(id: 'out-1', title: 'Outgoing 1'),
          buildTask(id: 'out-2', title: 'Outgoing 2'),
        ],
      );

      expect(find.text('Outgoing 1'), findsOneWidget);
      expect(find.text('Outgoing 2'), findsOneWidget);
      expect(find.text('Incoming Task'), findsOneWidget);
      expect(find.text('to'), findsNWidgets(2));
      expect(find.text('from'), findsOneWidget);
      // Three rows → two dividers between them.
      expect(find.byType(Divider), findsNWidgets(2));
    });

    testWidgets('shows completed glyph for done and rejected tasks', (
      tester,
    ) async {
      final doneTask = buildTask(
        id: 'done-1',
        title: 'Done Task',
        status: TaskStatus.done(
          id: 's-d',
          createdAt: now,
          utcOffset: 0,
        ),
      );
      final rejectedTask = buildTask(
        id: 'rejected-1',
        title: 'Rejected Task',
        status: TaskStatus.rejected(
          id: 's-r',
          createdAt: now,
          utcOffset: 0,
        ),
      );
      await pumpWidget(
        tester,
        incoming: [],
        outgoing: [doneTask, rejectedTask],
      );

      expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
      expect(find.byIcon(Icons.circle_outlined), findsNothing);
    });

    testWidgets('shows open glyph for open, in-progress, blocked tasks', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        incoming: [],
        outgoing: [
          buildTask(id: 't-open', title: 'Open'),
          buildTask(
            id: 't-prog',
            title: 'In Progress',
            status: TaskStatus.inProgress(
              id: 's-p',
              createdAt: now,
              utcOffset: 0,
            ),
          ),
          buildTask(
            id: 't-block',
            title: 'Blocked',
            status: TaskStatus.blocked(
              id: 's-b',
              createdAt: now,
              utcOffset: 0,
              reason: 'waiting',
            ),
          ),
        ],
      );

      expect(find.byIcon(Icons.circle_outlined), findsNWidgets(3));
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('long titles are truncated with ellipsis', (tester) async {
      const longTitle =
          'A really long task title that should overflow the row and be '
          'truncated with an ellipsis when it would otherwise wrap past the '
          'maximum number of lines allowed in the row layout';
      await pumpWidget(
        tester,
        incoming: [],
        outgoing: [buildTask(id: 'out-1', title: longTitle)],
      );

      final titleWidget = tester.widget<Text>(find.text(longTitle));
      expect(titleWidget.maxLines, 2);
      expect(titleWidget.overflow, TextOverflow.ellipsis);
    });
  });

  group('LinkedTasksWidget expand/collapse', () {
    testWidgets('resets to expanded when the parent swaps the taskId', (
      tester,
    ) async {
      final taskA = buildTask(id: 'a-out', title: 'Task A linked');
      final taskB = buildTask(id: 'b-out', title: 'Task B linked');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-a').overrideWith(
              LinkedTasksController.new,
            ),
            linkedTasksControllerProvider(taskId: 'task-b').overrideWith(
              LinkedTasksController.new,
            ),
            outgoingLinkedTasksProvider(
              'task-a',
            ).overrideWith((ref) => [taskA]),
            outgoingLinkedTasksProvider(
              'task-b',
            ).overrideWith((ref) => [taskB]),
            linkedFromEntriesControllerProvider(id: 'task-a').overrideWith(
              () => MockLinkedFromEntriesController([]),
            ),
            linkedFromEntriesControllerProvider(id: 'task-b').overrideWith(
              () => MockLinkedFromEntriesController([]),
            ),
            linkedEntriesControllerProvider(id: 'task-a').overrideWith(
              MockLinkedEntriesController.new,
            ),
            linkedEntriesControllerProvider(id: 'task-b').overrideWith(
              MockLinkedEntriesController.new,
            ),
          ],
          child: const WidgetTestBench(
            child: LinkedTasksWidget(taskId: 'task-a'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Collapse for task-a.
      await tester.tap(find.text('Linked Tasks'));
      await tester.pumpAndSettle();
      expect(find.text('Task A linked'), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // Swap to task-b without recreating the widget tree above.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider(taskId: 'task-a').overrideWith(
              LinkedTasksController.new,
            ),
            linkedTasksControllerProvider(taskId: 'task-b').overrideWith(
              LinkedTasksController.new,
            ),
            outgoingLinkedTasksProvider(
              'task-a',
            ).overrideWith((ref) => [taskA]),
            outgoingLinkedTasksProvider(
              'task-b',
            ).overrideWith((ref) => [taskB]),
            linkedFromEntriesControllerProvider(id: 'task-a').overrideWith(
              () => MockLinkedFromEntriesController([]),
            ),
            linkedFromEntriesControllerProvider(id: 'task-b').overrideWith(
              () => MockLinkedFromEntriesController([]),
            ),
            linkedEntriesControllerProvider(id: 'task-a').overrideWith(
              MockLinkedEntriesController.new,
            ),
            linkedEntriesControllerProvider(id: 'task-b').overrideWith(
              MockLinkedEntriesController.new,
            ),
          ],
          child: const WidgetTestBench(
            child: LinkedTasksWidget(taskId: 'task-b'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // didUpdateWidget should have reset _expanded back to true for task-b.
      expect(find.text('Task B linked'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });

    testWidgets('starts expanded and toggles on header tap', (tester) async {
      await pumpWidget(
        tester,
        incoming: [],
        outgoing: [buildTask(id: 'out-1', title: 'Outgoing Task')],
      );

      expect(find.text('Outgoing Task'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);

      await tester.tap(find.text('Linked Tasks'));
      await tester.pumpAndSettle();

      expect(find.text('Outgoing Task'), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await tester.tap(find.text('Linked Tasks'));
      await tester.pumpAndSettle();

      expect(find.text('Outgoing Task'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });
  });

  group('LinkedTasksWidget overflow menu', () {
    testWidgets(
      'shows link/create/manage actions when there are linked tasks',
      (tester) async {
        await pumpWidget(
          tester,
          incoming: [],
          outgoing: [buildTask(id: 'out-1')],
        );

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        expect(find.text('Link existing task...'), findsOneWidget);
        expect(find.text('Create new linked task...'), findsOneWidget);
        expect(find.text('Manage links...'), findsOneWidget);
      },
    );

    testWidgets('manage action toggles manage mode UI', (tester) async {
      await pumpWidget(
        tester,
        incoming: [],
        outgoing: [buildTask(id: 'out-1', title: 'Outgoing Task')],
      );

      // Default chevron in browse mode.
      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manage links...'));
      await tester.pumpAndSettle();

      // Chevron replaced by the unlink X.
      expect(find.byIcon(Icons.arrow_forward_ios), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Toggling again returns to browse mode.
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets(
      'tapping "Link existing task..." opens the LinkTaskModal',
      (tester) async {
        await pumpWidget(
          tester,
          incoming: [],
          outgoing: [buildTask(id: 'out-1', title: 'Outgoing Task')],
        );

        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Link existing task...'));
        await tester.pumpAndSettle();

        // Modal renders the LinkTaskModal as a draggable bottom sheet.
        expect(find.byType(LinkTaskModal), findsOneWidget);
      },
    );

    testWidgets('row tap is disabled in manage mode to avoid '
        'accidental navigation while unlinking', (tester) async {
      await pumpWidget(
        tester,
        incoming: [],
        outgoing: [buildTask(id: 'out-1', title: 'Outgoing Task')],
        manageMode: true,
      );

      // The row InkWell wrapping the title has its onTap nulled out in manage
      // mode. The header InkWell is unrelated; find the InkWell ancestor of
      // the task title.
      final rowInkWell = tester.widget<InkWell>(
        find
            .ancestor(
              of: find.text('Outgoing Task'),
              matching: find.byType(InkWell),
            )
            .first,
      );
      expect(rowInkWell.onTap, isNull);
    });
  });

  group('LinkedTasksWidget create new linked task', () {
    // Builds the parent task whose detail view hosts the card. Its category id
    // is what _createNewLinkedTask forwards to createTask().
    Task parentTaskWithCategory(String? categoryId) {
      return Task(
        meta: Metadata(
          id: 'task-main',
          createdAt: now,
          updatedAt: now,
          dateFrom: now,
          dateTo: now,
          categoryId: categoryId,
        ),
        data: TaskData(
          status: TaskStatus.open(id: 's', createdAt: now, utcOffset: 0),
          dateFrom: now,
          dateTo: now,
          statusHistory: const [],
          title: 'Parent',
        ),
      );
    }

    // Stubs PersistenceLogic.createTaskEntry to return [created] (or null) and
    // captures the linkedId/categoryId it was invoked with for assertions.
    void stubCreateTaskEntry(Task? created) {
      when(
        () => mockPersistenceLogic.createTaskEntry(
          data: any(named: 'data'),
          entryText: any(named: 'entryText'),
          linkedId: any(named: 'linkedId'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer((_) async => created);
    }

    List<Override> createFlowOverrides({
      required String? parentCategoryId,
      CategoryDefinition? newTaskCategory,
    }) {
      when(
        () => mockEntitiesCacheService.getCategoryById(any()),
      ).thenReturn(newTaskCategory);
      return [
        createEntryControllerOverride(parentTaskWithCategory(parentCategoryId)),
        taskAgentServiceProvider.overrideWithValue(MockTaskAgentService()),
      ];
    }

    Future<void> tapCreateNewLinkedTask(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create new linked task...'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'forwards the parent category id and linkedId to createTask',
      (tester) async {
        final created = buildTask(id: 'new-task', title: 'New');
        stubCreateTaskEntry(created);

        await pumpWidget(
          tester,
          incoming: [],
          outgoing: [buildTask(id: 'out-1', title: 'Outgoing Task')],
          extraOverrides: createFlowOverrides(
            parentCategoryId: 'cat-1',
            // No defaultTemplateId → autoAssignCategoryAgent returns early
            // without invoking the agent service.
            newTaskCategory: CategoryTestUtils.createTestCategory(id: 'cat-1'),
          ),
        );

        await tapCreateNewLinkedTask(tester);

        final captured = verify(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            linkedId: captureAny(named: 'linkedId'),
            categoryId: captureAny(named: 'categoryId'),
          ),
        ).captured;
        expect(captured, ['task-main', 'cat-1']);
      },
    );

    testWidgets(
      'auto-assigns a category agent when the new task category has a '
      'default template',
      (tester) async {
        // The new task carries the parent category id in its metadata; the
        // agent service is invoked when that category has a defaultTemplateId.
        final created = Task(
          meta: Metadata(
            id: 'new-task',
            createdAt: now,
            updatedAt: now,
            dateFrom: now,
            dateTo: now,
            categoryId: 'cat-1',
          ),
          data: TaskData(
            status: TaskStatus.open(id: 's', createdAt: now, utcOffset: 0),
            dateFrom: now,
            dateTo: now,
            statusHistory: const [],
            title: 'New',
          ),
        );
        stubCreateTaskEntry(created);

        final agentService = MockTaskAgentService();
        when(
          () => agentService.createTaskAgent(
            taskId: any(named: 'taskId'),
            templateId: any(named: 'templateId'),
            profileId: any(named: 'profileId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            awaitContent: any(named: 'awaitContent'),
          ),
        ).thenThrow(StateError('not asserted on the identity result'));

        when(
          () => mockEntitiesCacheService.getCategoryById(any()),
        ).thenReturn(
          CategoryTestUtils.createTestCategory(
            id: 'cat-1',
            defaultTemplateId: 'tmpl-1',
            defaultProfileId: 'prof-1',
          ),
        );

        await pumpWidget(
          tester,
          incoming: [],
          outgoing: [buildTask(id: 'out-1', title: 'Outgoing Task')],
          extraOverrides: [
            createEntryControllerOverride(parentTaskWithCategory('cat-1')),
            taskAgentServiceProvider.overrideWithValue(agentService),
          ],
        );

        await tapCreateNewLinkedTask(tester);

        verify(
          () => agentService.createTaskAgent(
            taskId: 'new-task',
            templateId: 'tmpl-1',
            profileId: 'prof-1',
            allowedCategoryIds: {'cat-1'},
            awaitContent: true,
          ),
        ).called(1);
      },
    );

    testWidgets(
      'does nothing further when createTask returns null',
      (tester) async {
        stubCreateTaskEntry(null);

        final agentService = MockTaskAgentService();

        await pumpWidget(
          tester,
          incoming: [],
          outgoing: [buildTask(id: 'out-1', title: 'Outgoing Task')],
          extraOverrides: [
            createEntryControllerOverride(parentTaskWithCategory('cat-1')),
            taskAgentServiceProvider.overrideWithValue(agentService),
          ],
        );

        await tapCreateNewLinkedTask(tester);

        // createTask was attempted...
        verify(
          () => mockPersistenceLogic.createTaskEntry(
            data: any(named: 'data'),
            entryText: any(named: 'entryText'),
            linkedId: any(named: 'linkedId'),
            categoryId: any(named: 'categoryId'),
          ),
        ).called(1);
        // ...but the null result short-circuits the agent assignment.
        verifyNever(
          () => agentService.createTaskAgent(
            taskId: any(named: 'taskId'),
            templateId: any(named: 'templateId'),
            profileId: any(named: 'profileId'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
            awaitContent: any(named: 'awaitContent'),
          ),
        );
      },
    );
  });

  group('LinkedTasksWidget unlink flows', () {
    testWidgets('confirming unlink on outgoing row removes link with '
        'fromId=current, toId=outgoing', (tester) async {
      final repo = await pumpWidget(
        tester,
        incoming: [],
        outgoing: [buildTask(id: 'out-1', title: 'Outgoing Task')],
        manageMode: true,
      );

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // Confirmation dialog.
      expect(find.text('Unlink'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Unlink'));
      await tester.pumpAndSettle();

      verify(
        () => repo.removeLink(fromId: 'task-main', toId: 'out-1'),
      ).called(1);
    });

    testWidgets('confirming unlink on incoming row removes link with '
        'fromId=incoming, toId=current', (tester) async {
      final repo = await pumpWidget(
        tester,
        incoming: [buildTask(id: 'in-1', title: 'Incoming Task')],
        outgoing: [],
        manageMode: true,
      );

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Unlink'));
      await tester.pumpAndSettle();

      verify(
        () => repo.removeLink(fromId: 'in-1', toId: 'task-main'),
      ).called(1);
    });

    testWidgets(
      'tapping a row in browse mode pushes the linked task on desktop',
      (tester) async {
        await pumpWidget(
          tester,
          incoming: [],
          outgoing: [buildTask(id: 'out-1', title: 'Outgoing Task')],
          // Desktop sizing routes navigation through NavService instead of
          // pushing TaskDetailsPage onto the navigator.
          mediaQueryData: const MediaQueryData(size: Size(1280, 900)),
        );

        await tester.tap(find.text('Outgoing Task'));
        await tester.pumpAndSettle();

        verify(() => mockNavService.pushDesktopTaskDetail('out-1')).called(1);
      },
    );

    testWidgets('cancelling the confirmation does not call removeLink', (
      tester,
    ) async {
      final repo = await pumpWidget(
        tester,
        incoming: [],
        outgoing: [buildTask(id: 'out-1', title: 'Outgoing Task')],
        manageMode: true,
      );

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      verifyNever(
        () => repo.removeLink(
          fromId: any(named: 'fromId'),
          toId: any(named: 'toId'),
        ),
      );
    });
  });
}
