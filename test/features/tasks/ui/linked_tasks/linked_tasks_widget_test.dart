import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/tasks/state/linkable_tasks_controller.dart';
import 'package:lotti/features/tasks/state/linked_tasks_controller.dart';
import 'package:lotti/features/tasks/state/task_one_liner_provider.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_task_row.dart';
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
import '../../../../test_utils/screenshot_harness.dart';
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
    double? width,
    Locale? locale,
    List<Override> extraOverrides = const [],
    List<EntryLink> extraTypedLinks = const [],
    List<Task> extraTypedTasks = const [],
    Map<String, String> oneLinersByTaskId = const {},
    // Defaults to "the app has other tasks", the world every case below the
    // first-run ones lives in. False is the fresh-install state where the
    // card must not render at all.
    bool linkableTasksExist = true,
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
          linkableTasksOverride('task-main', exists: linkableTasksExist),
          linkedTasksControllerProvider('task-main').overrideWith(
            manageMode
                ? () => MockLinkedTasksControllerManageMode('task-main')
                : LinkedTasksController.new,
          ),
          taskOneLinersProvider.overrideWith(
            (ref, request) async {
              final result = <String, String>{};
              for (final taskId in request.taskIds) {
                final oneLiner = oneLinersByTaskId[taskId];
                if (oneLiner != null) result[taskId] = oneLiner;
              }
              return result;
            },
          ),
          journalRepositoryProvider.overrideWithValue(journalRepo),
          ...extraOverrides,
        ],
        child: WidgetTestBench(
          locale: locale,
          mediaQueryData: mediaQueryData,
          // Align, not a bare SizedBox: the bench hands its child tight
          // constraints, so a width set any other way is silently ignored and
          // the card is measured at the full 800pt surface instead of a phone.
          child: width == null
              ? const LinkedTasksWidget(taskId: 'task-main')
              : Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    child: const LinkedTasksWidget(taskId: 'task-main'),
                  ),
                ),
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

  setUpAll(() async {
    registerAllFallbackValues();
    // Real font metrics: the fallback test font is far wider than Inter, so
    // width assertions measured against it describe a layout that does not
    // ship.
    await loadAppFonts();
  });

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
    testWidgets('passes one batched tagline result into the matching row', (
      tester,
    ) async {
      await pumpWidget(
        tester,
        incoming: [],
        outgoing: [buildTask(id: 'task-2', title: 'Linked task')],
        oneLinersByTaskId: const {'task-2': 'Ready for final review'},
      );

      final row = tester.widget<LinkedTaskRow>(find.byType(LinkedTaskRow));
      expect(row.data.oneLiner, 'Ready for final review');
    });

    testWidgets(
      'the header sits nearer the content it labels than the card edge',
      (tester) async {
        await pumpWidget(tester, incoming: [], outgoing: []);

        final card = tester.getRect(find.byType(DecoratedBox).first);
        final title = tester.getRect(
          find.byKey(const ValueKey('linked-tasks-card-title')),
        );
        final firstRow = tester.getRect(find.text('Link a task…'));

        final above = title.top - card.top;
        final below = firstRow.top - title.bottom;

        // Proximity: a section title belongs to what follows it. Only the
        // header's own padding holds it off the card's top edge, while the row
        // beneath contributes step3 of its own, so symmetric header padding
        // produces an asymmetric result — it measured 4pt above and 14pt below
        // before this was made asymmetric.
        expect(
          above,
          greaterThanOrEqualTo(below),
          reason:
              'the title must not sit closer to the border than to the '
              'list it heads',
        );
        // Not merely ordered but comfortably clear of the edge: an earlier
        // 4pt crowded the title against the border.
        expect(above, greaterThanOrEqualTo(12));
      },
    );

    testWidgets(
      'with no links it still renders a header carrying the link action — '
      'otherwise the feature has no reachable entry point at all',
      (tester) async {
        await pumpWidget(tester, incoming: [], outgoing: []);

        expect(find.text('Linked Tasks'), findsOneWidget);
        // A worded action, not a bare icon in an empty bordered box.
        expect(find.text('Link a task…'), findsOneWidget);
        expect(
          find.text(
            'Connect this task to another task.',
          ),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.add_link), findsOneWidget);
        // Nothing to count, expand, or list yet.
        expect(find.text('0'), findsNothing);
        expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
        expect(find.byType(LinkedTaskRow), findsNothing);
      },
    );

    testWidgets(
      'with no links AND no other task to link to, the card renders nothing '
      'at all — the first-run install has no linkable candidate',
      (tester) async {
        await pumpWidget(
          tester,
          incoming: [],
          outgoing: [],
          linkableTasksExist: false,
        );

        // Not merely a smaller card: no header, no border, no explanation.
        // On the app's very first task this was the loudest block on the
        // screen and it taught blockers and duplicates to someone who had
        // exactly one task and could not link it to anything.
        expect(find.byType(DesignSystemListItem), findsNothing);
        expect(find.text('Linked Tasks'), findsNothing);
        expect(find.text('Link a task…'), findsNothing);
        expect(find.byIcon(Icons.add_link), findsNothing);
        expect(
          find.descendant(
            of: find.byType(LinkedTasksWidget),
            matching: find.byType(DecoratedBox),
          ),
          findsNothing,
          reason:
              'not even the card chrome — a bordered box with nothing in it '
              'is what made the first task screen read as a failed load',
        );
      },
    );

    testWidgets(
      'a task that already HAS links keeps its card even when the linkable '
      'lookup says no — hiding it would hide real content',
      (tester) async {
        await pumpWidget(
          tester,
          incoming: [],
          outgoing: [buildTask(id: 'task-2', title: 'Already linked')],
          linkableTasksExist: false,
        );

        expect(find.text('Linked Tasks'), findsOneWidget);
        expect(find.text('Already linked'), findsOneWidget);
      },
    );

    testWidgets('exposes the link action alongside links too', (tester) async {
      await pumpWidget(
        tester,
        incoming: [],
        outgoing: [buildTask(id: 'out-1', title: 'Outgoing Task')],
      );

      // With a list to add to, the header carries the action and the empty
      // state's worded row is gone.
      expect(find.byIcon(Icons.add_link), findsOneWidget);
      expect(find.text('Link a task…'), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
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

    // A plain link carries no relationship semantics, so its row renders
    // without the direction glyph + caption unit that a typed relationship
    // row uses — the "Other links" section header is the only signal, and a
    // flat row must not mimic a typed one with a content-free "to"/"from".
    for (final flat in [
      (label: 'outgoing', incoming: false, title: 'Outgoing Task'),
      (label: 'incoming', incoming: true, title: 'Incoming Task'),
    ]) {
      testWidgets(
        'renders an ${flat.label} plain link captionless',
        (tester) async {
          final task = buildTask(id: 'flat-1', title: flat.title);
          await pumpWidget(
            tester,
            incoming: flat.incoming ? [task] : [],
            outgoing: flat.incoming ? [] : [task],
          );

          expect(find.text(flat.title), findsOneWidget);
          // Browse-mode chevron is still the row's affordance...
          expect(find.byIcon(Icons.arrow_forward_ios), findsOneWidget);
          // ...but no direction caption or arrow glyph.
          expect(find.text('to'), findsNothing);
          expect(find.text('from'), findsNothing);
          expect(find.byType(SvgPicture), findsNothing);
        },
      );
    }

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
      // All three render captionless.
      expect(find.text('to'), findsNothing);
      expect(find.text('from'), findsNothing);
      // Three rows → two dividers between them.
      expect(find.byType(DesignSystemDivider), findsNWidgets(2));
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

        expect(find.text('Is blocked by'), findsOneWidget);
        expect(find.text('Blocker Task'), findsOneWidget);
        expect(find.text('Outgoing Task'), findsOneWidget);
        // One divider between the typed sections and the flat list — the
        // flat list itself has only one row, so no additional dividers.
        expect(find.byType(DesignSystemDivider), findsOneWidget);
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
            linkableTasksOverride('task-a', exists: true),
            linkableTasksOverride('task-b', exists: true),
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
            linkableTasksOverride('task-a', exists: true),
            linkableTasksOverride('task-b', exists: true),
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

    // The other half of the header contract. The scale loop below proves the
    // header does not overflow; it says nothing about whether the title is
    // being eaten while space sits idle beside it — which is exactly how a
    // default-scale truncation shipped under a green suite.
    // The card sits inside the detail page's horizontal padding, so its real
    // width on a 390pt phone is ~357 — measuring at the full viewport width
    // hands the header 33pt it never has, which is enough to hide the
    // truncation entirely.
    const phoneCardWidth = 357.0;

    // Every shipped locale, not just English. The R17 fix was verified in
    // English and shipped truncated in German and Spanish, whose card title
    // and action label are both markedly longer — a difference no
    // English-only assertion and no screenshot round can see.
    for (final locale in ['en', 'de', 'fr', 'es', 'ro', 'cs']) {
      testWidgets(
        'the header title survives default text size in "$locale"',
        (tester) async {
          await pumpWidget(
            tester,
            incoming: [],
            outgoing: [buildTask(id: 'out-1', title: 'Outgoing Task')],
            width: phoneCardWidth,
            locale: Locale(locale),
            mediaQueryData: const MediaQueryData(size: Size(390, 844)),
          );

          final title = tester.renderObject<RenderParagraph>(
            find.byKey(const ValueKey('linked-tasks-card-title')),
          );
          expect(
            title.didExceedMaxLines,
            isFalse,
            reason:
                'the card truncates its own name in "$locale" at default text '
                'size: ${title.size.width}pt granted against '
                '${title.getMaxIntrinsicWidth(double.infinity)}pt needed',
          );

          // The other direction, which is what an allowance being too large
          // hides: only the two locales whose title and label genuinely
          // collide should lose the word. Asserting the title survives says
          // nothing about labels dropped that had room.
          // Both branches render a DesignSystemButton — the fallback is
          // icon-only, not a different component — so the label is what
          // distinguishes them.
          final worded = tester
              .widgetList<DesignSystemButton>(find.byType(DesignSystemButton))
              .any((button) => button.label.isNotEmpty);
          final expectsWordedAction = !const {'de', 'es'}.contains(locale);
          expect(
            worded,
            expectsWordedAction,
            reason: expectsWordedAction
                ? 'the link action should keep its word in "$locale" — an '
                      "allowance larger than the button's real chrome takes "
                      'the label from locales that had room for it'
                : 'the link action cannot keep its word in "$locale" without '
                      "truncating the card's own name",
          );
        },
      );
    }

    for (final manageMode in [false, true]) {
      testWidgets(
        'the header title is not truncated at default text size '
        '(manage: $manageMode) — it may give way only when the trailing '
        'controls genuinely leave it no room',
        (tester) async {
          await pumpWidget(
            tester,
            incoming: [],
            outgoing: [buildTask(id: 'out-1', title: 'Outgoing Task')],
            manageMode: manageMode,
            width: phoneCardWidth,
            mediaQueryData: const MediaQueryData(size: Size(390, 844)),
          );

          final titleFinder = find.text('Linked Tasks');
          expect(titleFinder, findsOneWidget);

          final painted = tester.renderObject<RenderParagraph>(titleFinder);
          expect(
            painted.didExceedMaxLines,
            isFalse,
            reason:
                'the card is truncating its own name at default text size; '
                'the granted width is ${painted.size.width}pt against an '
                'intrinsic ${painted.getMaxIntrinsicWidth(double.infinity)}pt',
          );
        },
      );
    }

    // Large accessibility text sizes are a supported configuration, not an
    // edge case, and the card header is the densest row in the feature: a
    // title, a count badge, a worded action and an overflow menu on one line.
    for (final scale in [1.3, 1.6, 2.0]) {
      for (final manageMode in [false, true]) {
        testWidgets(
          'the header survives text scale $scale (manage: $manageMode) — at '
          'these sizes it used to overflow, clipping the action and dropping '
          "the overflow menu that is manage mode's other way out",
          (tester) async {
            await pumpWidget(
              tester,
              incoming: [],
              outgoing: [buildTask(id: 'out-1', title: 'Outgoing Task')],
              manageMode: manageMode,
              // The card's real width, like every other assertion in this
              // file. Measuring at the full viewport hands the header 33pt it
              // never has — which is exactly the headroom that can keep the
              // overflow menu visible at a large text scale while the shipped
              // card drops it.
              width: phoneCardWidth,
              mediaQueryData: MediaQueryData(
                size: const Size(390, 844),
                textScaler: TextScaler.linear(scale),
              ),
            );

            expect(tester.takeException(), isNull);
            // The way out must still be there, not merely un-crashed.
            expect(find.byIcon(Icons.more_vert), findsOneWidget);
          },
        );
      }
    }

    testWidgets(
      'the empty card words both creative actions — it is the screen where '
      'the user knows least, and creating a linked task was reachable only '
      'through an unlabelled glyph holding one item',
      (tester) async {
        await pumpWidget(tester, incoming: [], outgoing: []);

        expect(find.text('Link a task…'), findsOneWidget);
        expect(find.text('Create new linked task…'), findsOneWidget);
      },
    );

    testWidgets(
      'the unlink confirmation names the task — the rows it is reached from '
      'carry two faint glyphs each, so "this task" cannot say which link was '
      'hit on the only irreversible action here',
      (tester) async {
        await pumpWidget(
          tester,
          incoming: [],
          outgoing: [buildTask(id: 'out-1', title: 'Outgoing Task')],
          manageMode: true,
        );

        await tester.tap(find.byIcon(Icons.link_off));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.textContaining('Outgoing Task'), findsWidgets);
      },
    );
  });
}

/// Serves a fixed answer to "does any other task exist to link to?", so a
/// test can state which world it is in instead of depending on a JournalDb
/// stub three layers down. The card renders nothing at all when this is
/// false — see `LinkedTasksWidget.build`.
class _StaticLinkableTasks extends LinkableTasksController {
  _StaticLinkableTasks({required this.exists});

  final bool exists;

  @override
  Future<bool> build() async => exists;
}

Override linkableTasksOverride(String taskId, {required bool exists}) =>
    linkableTasksExistProvider(
      taskId,
    ).overrideWith(() => _StaticLinkableTasks(exists: exists));
