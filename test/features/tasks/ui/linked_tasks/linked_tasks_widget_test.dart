import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/state/linked_tasks_controller.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_tasks_widget.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

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

  void expectStatusGlyphForTitle(
    WidgetTester tester, {
    required String title,
    required TaskStatus status,
  }) {
    final rowFinder = find.ancestor(
      of: find.text(title),
      matching: find.byType(Row),
    );
    final statusString = status.toDbString;
    final expectedColor = taskColorFromStatusString(
      statusString,
      brightness: Theme.of(tester.element(rowFinder.first)).brightness,
    );
    final expectedIcon = taskIconFromStatusString(statusString);
    final icon = tester
        .widgetList<Icon>(
          find.descendant(
            of: rowFinder.first,
            matching: find.byType(Icon),
          ),
        )
        .firstWhere((icon) => icon.icon == expectedIcon);

    expect(icon.color, expectedColor, reason: title);
  }

  // Stubs a MockJournalRepository so `TaskLinkGroupsController` resolves
  // `outgoing` as basic links from [taskId] and `incoming` as basic links
  // to it — mirroring the flat "Linked Tasks" list's pre-typed-links shape.
  MockJournalRepository stubLinkGroupsRepository({
    required String taskId,
    required List<JournalEntity> incoming,
    required List<Task> outgoing,
    List<EntryLink> extraTypedLinks = const [],
    List<Task> extraTypedTasks = const [],
  }) {
    final journalRepo = MockJournalRepository();
    when(
      () => journalRepo.removeLink(
        fromId: any(named: 'fromId'),
        toId: any(named: 'toId'),
      ),
    ).thenAnswer((_) async => 1);
    when(
      () => journalRepo.removeTypedLink(
        fromId: any(named: 'fromId'),
        toId: any(named: 'toId'),
        linkType: any(named: 'linkType'),
      ),
    ).thenAnswer((_) async => 1);

    final outgoingLinks = outgoing
        .map(
          (t) => EntryLink.basic(
            id: 'link-${t.meta.id}',
            fromId: taskId,
            toId: t.meta.id,
            createdAt: now,
            updatedAt: now,
            vectorClock: null,
          ),
        )
        .toList();
    final incomingLinks = incoming
        .map(
          (e) => EntryLink.basic(
            id: 'link-in-${e.id}',
            fromId: e.id,
            toId: taskId,
            createdAt: now,
            updatedAt: now,
            vectorClock: null,
          ),
        )
        .toList();

    when(
      () => journalRepo.getTypedLinksForTaskIds(
        {taskId},
        linkTypes: any(named: 'linkTypes'),
      ),
    ).thenAnswer(
      (_) async => [...outgoingLinks, ...incomingLinks, ...extraTypedLinks],
    );
    when(
      () => journalRepo.getJournalEntitiesByIds(any()),
    ).thenAnswer(
      (_) async => [...outgoing, ...incoming, ...extraTypedTasks],
    );

    return journalRepo;
  }

  Future<MockJournalRepository> pumpWidget(
    WidgetTester tester, {
    required List<JournalEntity> incoming,
    required List<Task> outgoing,
    bool manageMode = false,
    MediaQueryData? mediaQueryData,
    List<Override> extraOverrides = const [],
    List<EntryLink> extraTypedLinks = const [],
    List<Task> extraTypedTasks = const [],
  }) async {
    final journalRepo = stubLinkGroupsRepository(
      taskId: 'task-main',
      incoming: incoming,
      outgoing: outgoing,
      extraTypedLinks: extraTypedLinks,
      extraTypedTasks: extraTypedTasks,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          linkedTasksControllerProvider('task-main').overrideWith(
            manageMode
                ? () => MockLinkedTasksControllerManageMode('task-main')
                : LinkedTasksController.new,
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
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

    testWidgets('uses the shared task status glyph for each linked task', (
      tester,
    ) async {
      final statuses = <String, TaskStatus>{
        'Open': TaskStatus.open(
          id: 's-open',
          createdAt: now,
          utcOffset: 0,
        ),
        'Groomed': TaskStatus.groomed(
          id: 's-groomed',
          createdAt: now,
          utcOffset: 0,
        ),
        'In Progress': TaskStatus.inProgress(
          id: 's-progress',
          createdAt: now,
          utcOffset: 0,
        ),
        'Blocked': TaskStatus.blocked(
          id: 's-blocked',
          createdAt: now,
          utcOffset: 0,
          reason: 'waiting',
        ),
        'On Hold': TaskStatus.onHold(
          id: 's-hold',
          createdAt: now,
          utcOffset: 0,
          reason: 'waiting',
        ),
        'Done': TaskStatus.done(
          id: 's-done',
          createdAt: now,
          utcOffset: 0,
        ),
        'Rejected': TaskStatus.rejected(
          id: 's-rejected',
          createdAt: now,
          utcOffset: 0,
        ),
      };

      await pumpWidget(
        tester,
        incoming: [],
        outgoing: statuses.entries
            .map(
              (entry) => buildTask(
                id: 't-${entry.key}',
                title: entry.key,
                status: entry.value,
              ),
            )
            .toList(),
      );

      for (final entry in statuses.entries) {
        expectStatusGlyphForTitle(
          tester,
          title: entry.key,
          status: entry.value,
        );
      }
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.circle_outlined), findsNothing);
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

    testWidgets(
      'renders the typed-relationship sections above the flat list, with a '
      'divider between them, when both are present',
      (tester) async {
        final blocker = buildTask(id: 'blocker-1', title: 'Blocker Task');
        await pumpWidget(
          tester,
          incoming: [],
          outgoing: [buildTask(id: 'out-1', title: 'Outgoing Task')],
          extraTypedLinks: [
            EntryLink.blocks(
              id: 'link-blocks',
              fromId: 'blocker-1',
              toId: 'task-main',
              createdAt: now,
              updatedAt: now,
              vectorClock: null,
            ),
          ],
          extraTypedTasks: [blocker],
        );

        expect(find.text('Blocked by'), findsOneWidget);
        expect(find.text('Blocker Task'), findsOneWidget);
        expect(find.text('Outgoing Task'), findsOneWidget);
        // One divider between the typed sections and the flat list — the
        // flat list itself has only one row, so no additional dividers.
        expect(find.byType(Divider), findsOneWidget);
      },
    );
  });

  group('LinkedTasksWidget expand/collapse', () {
    testWidgets('resets to expanded when the parent swaps the taskId', (
      tester,
    ) async {
      final taskA = buildTask(id: 'a-out', title: 'Task A linked');
      final taskB = buildTask(id: 'b-out', title: 'Task B linked');

      final journalRepo = MockJournalRepository();
      when(
        () => journalRepo.getTypedLinksForTaskIds(
          {'task-a'},
          linkTypes: any(named: 'linkTypes'),
        ),
      ).thenAnswer(
        (_) async => [
          EntryLink.basic(
            id: 'link-a',
            fromId: 'task-a',
            toId: 'a-out',
            createdAt: now,
            updatedAt: now,
            vectorClock: null,
          ),
        ],
      );
      when(
        () => journalRepo.getTypedLinksForTaskIds(
          {'task-b'},
          linkTypes: any(named: 'linkTypes'),
        ),
      ).thenAnswer(
        (_) async => [
          EntryLink.basic(
            id: 'link-b',
            fromId: 'task-b',
            toId: 'b-out',
            createdAt: now,
            updatedAt: now,
            vectorClock: null,
          ),
        ],
      );
      when(
        () => journalRepo.getJournalEntitiesByIds(any()),
      ).thenAnswer((_) async => [taskA, taskB]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider('task-a').overrideWith(
              LinkedTasksController.new,
            ),
            linkedTasksControllerProvider('task-b').overrideWith(
              LinkedTasksController.new,
            ),
            journalRepositoryProvider.overrideWithValue(journalRepo),
          ],
          child: const WidgetTestBench(
            child: LinkedTasksWidget(taskId: 'task-a'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Collapse for task-a.
      await tester.tap(find.text('Linked Tasks'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Task A linked'), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      // Swap to task-b without recreating the widget tree above.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkedTasksControllerProvider('task-a').overrideWith(
              LinkedTasksController.new,
            ),
            linkedTasksControllerProvider('task-b').overrideWith(
              LinkedTasksController.new,
            ),
            journalRepositoryProvider.overrideWithValue(journalRepo),
          ],
          child: const WidgetTestBench(
            child: LinkedTasksWidget(taskId: 'task-b'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Outgoing Task'), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await tester.tap(find.text('Linked Tasks'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Outgoing Task'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
    });
  });
}
