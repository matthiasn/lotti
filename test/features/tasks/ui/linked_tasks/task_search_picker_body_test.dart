import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/task_search_picker_body.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/entity_factories.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../../categories/test_utils.dart';

/// The picker body's own behaviour, independent of what any modal does with a
/// picked task. `LinkTaskModal`'s suite covers the integration — creating,
/// linking, and confirming — while the rules for *when* the create row is
/// offered at all belong here.
void main() {
  late MockJournalDb journalDb;
  late MockFts5Db fts5Db;

  final now = DateTime(2025, 12, 31, 12);

  Task buildTask({required String id, required String title}) =>
      TestTaskFactory.create(
        id: id,
        title: title,
        createdAt: now,
        dateFrom: now,
        dateTo: now,
      );

  void stubTasks(List<Task> tasks) {
    when(
      () => journalDb.getTasks(
        starredStatuses: any(named: 'starredStatuses'),
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => tasks);
  }

  /// Full-text hits that the prefetch never loaded, resolved by id — the
  /// window a task can hide in on a backlog larger than 200 rows.
  void stubFullTextHitsOutsideWindow(List<Task> tasks) {
    when(
      () => fts5Db.watchFullTextMatches(any()),
    ).thenAnswer((_) => Stream.value(tasks.map((t) => t.meta.id).toList()));
    when(
      () => journalDb.getJournalEntitiesForIds(any()),
    ).thenAnswer((_) async => tasks);
  }

  setUp(() async {
    journalDb = MockJournalDb();
    fts5Db = MockFts5Db();

    stubTasks([]);
    when(
      () => fts5Db.watchFullTextMatches(any()),
    ).thenAnswer((_) => Stream.value(<String>[]));
    when(
      () => journalDb.getJournalEntitiesForIds(any()),
    ).thenAnswer((_) async => <JournalEntity>[]);

    final cache = MockEntitiesCacheService();
    when(() => cache.sortedCategories).thenReturn([
      CategoryTestUtils.createTestCategory(id: 'cat-a', name: 'A'),
    ]);

    // Centralized lifecycle first, then only the picker-specific doubles on
    // top of it — the shared helper owns registration and cleanup.
    await setUpTestGetIt(
      additionalSetup: () {
        if (getIt.isRegistered<JournalDb>()) getIt.unregister<JournalDb>();
        getIt
          ..registerSingleton<EntitiesCacheService>(cache)
          ..registerSingleton<JournalDb>(journalDb)
          ..registerSingleton<Fts5Db>(fts5Db);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  Finder createRow() => find.byKey(const ValueKey('link-picker-create'));

  Future<void> pumpBody(
    WidgetTester tester, {
    Future<Task?> Function(String title)? onCreateTask,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        // makeTestableWidget hosts its child in a SingleChildScrollView, so
        // the body needs a bounded height of its own to lay its list out
        // against, and a Material ancestor for the search field.
        _Host(
          child: TaskSearchPickerBody(
            excludeIds: const {},
            onTaskSelected: (_) {},
            onCreateTask: onCreateTask,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Two pumps: the create row is withheld until the query's full-text lookup
  /// resolves, so the pool it checks for an exact-title match is complete.
  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pump();
    await tester.pump();
  }

  testWidgets('no create row at all without onCreateTask', (tester) async {
    stubTasks([buildTask(id: 'a', title: 'Apple Task')]);
    await pumpBody(tester);

    await search(tester, 'Write the guide');

    // The blocker picker takes this path: it stays search-only, so a miss is
    // still a miss and the empty state is still the right answer.
    expect(createRow(), findsNothing);
    expect(find.text('No tasks found'), findsOneWidget);
  });

  testWidgets(
    'offers the create row on a miss, withholds it on an exact title match, '
    'and offers it again for a partial one',
    (tester) async {
      stubTasks([buildTask(id: 'apple', title: 'Apple Task')]);
      await pumpBody(tester, onCreateTask: (_) async => null);

      // Nothing typed: no create row, and no reason for one.
      expect(createRow(), findsNothing);

      await search(tester, 'Write the guide');
      expect(find.text('No tasks found'), findsNothing);
      expect(createRow(), findsOneWidget);

      // An exact title match means the task already exists — offering to
      // create a second one with the same name would be a duplicate. Case
      // and surrounding whitespace do not make it a different title.
      await search(tester, '  apple task ');
      expect(createRow(), findsNothing);

      // A partial match still offers it: "Apple" is a legitimately different
      // task from "Apple Task".
      await search(tester, 'Apple');
      expect(createRow(), findsOneWidget);
    },
  );

  testWidgets(
    'withholds the create row until the full-text lookup resolves, so an '
    'exact match outside the prefetch window cannot be duplicated',
    (tester) async {
      // The backlog is larger than the prefetch: the matching task exists but
      // is not in the loaded window.
      final beyondWindow = buildTask(id: 'beyond', title: 'Write the guide');
      stubTasks([buildTask(id: 'in-window', title: 'Prefetched task')]);
      stubFullTextHitsOutsideWindow([beyondWindow]);

      await pumpBody(tester, onCreateTask: (_) async => null);

      await tester.enterText(find.byType(TextField), 'Write the guide');
      await tester.pump();

      // One pump in, the lookup has not resolved. The pool does not yet hold
      // the match, so an unguarded exact-title check would offer to create a
      // duplicate of a task that already exists.
      expect(createRow(), findsNothing);

      await tester.pump();

      // Resolved: the match is in the pool and the create row stays withheld
      // for the right reason. Asserted via the row's status subtitle, since
      // the title itself also appears in the search field.
      expect(createRow(), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    },
  );

  testWidgets('a failed full-text lookup still releases the create row', (
    tester,
  ) async {
    stubTasks([]);
    when(
      () => fts5Db.watchFullTextMatches(any()),
    ).thenAnswer((_) => Stream.error(Exception('fts unavailable')));

    await pumpBody(tester, onCreateTask: (_) async => null);
    await search(tester, 'Write the guide');

    // The pool is as complete as it is going to get. Withholding forever
    // would make an unavailable index look like a permanently missing
    // feature.
    expect(createRow(), findsOneWidget);
  });

  testWidgets(
    'an exact title match on an *excluded* task still offers the create',
    (tester) async {
      final anchor = buildTask(id: 'anchor', title: 'Write the guide');
      stubTasks([anchor]);

      await tester.pumpWidget(
        makeTestableWidget(
          _Host(
            child: TaskSearchPickerBody(
              // The anchor task is always excluded from its own picker.
              excludeIds: const {'anchor'},
              onTaskSelected: (_) {},
              onCreateTask: (_) async => null,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await search(tester, 'Write the guide');

      // Checked against the raw pool this was a dead end: the row was hidden
      // (excluded) and the create row suppressed (the excluded task counted
      // as a duplicate), leaving neither.
      expect(createRow(), findsOneWidget);
    },
  );

  testWidgets('a second tap while a create is pending is ignored', (
    tester,
  ) async {
    stubTasks([]);
    final write = Completer<Task?>();
    var createCalls = 0;

    await tester.pumpWidget(
      makeTestableWidget(
        _Host(
          child: TaskSearchPickerBody(
            excludeIds: const {},
            onTaskSelected: (_) {},
            onCreateTask: (_) {
              createCalls++;
              return write.future;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await search(tester, 'Write the guide');
    await tester.tap(createRow());
    await tester.pump();

    // Second tap lands while the first write is still open.
    await tester.tap(createRow(), warnIfMissed: false);
    await tester.pump();

    expect(createCalls, 1);

    write.complete(null);
    await tester.pump();
  });

  testWidgets('existing rows are inert while a create is pending', (
    tester,
  ) async {
    stubTasks([buildTask(id: 'apple', title: 'Apple Task')]);
    final write = Completer<Task?>();
    Task? selected;

    await tester.pumpWidget(
      makeTestableWidget(
        _Host(
          child: TaskSearchPickerBody(
            excludeIds: const {},
            onTaskSelected: (task) => selected = task,
            onCreateTask: (_) => write.future,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    // A query that both matches an existing task and offers a create.
    await search(tester, 'Apple');
    expect(createRow(), findsOneWidget);
    await tester.tap(createRow());
    await tester.pump();

    // Picking an existing result mid-create would commit and pop while the
    // create was still pending, and the create's completion would then commit
    // a second link for a task the user had moved on from.
    await tester.tap(find.text('Apple Task'), warnIfMissed: false);
    await tester.pump();
    expect(selected, isNull);

    write.complete(null);
    await tester.pump();
  });

  testWidgets('a created task is resolvable and reaches onTaskSelected', (
    tester,
  ) async {
    stubTasks([]);
    final created = buildTask(id: 'new-task', title: 'Write the guide');
    Task? selected;
    var createCalls = 0;

    await tester.pumpWidget(
      makeTestableWidget(
        // makeTestableWidget hosts its child in a SingleChildScrollView, so
        // the body needs a bounded height of its own to lay its list out
        // against, and a Material ancestor for the search field.
        _Host(
          child: TaskSearchPickerBody(
            excludeIds: const {},
            onTaskSelected: (task) => selected = task,
            onCreateTask: (title) async {
              createCalls++;
              return created;
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await search(tester, 'Write the guide');
    await tester.tap(createRow());
    await tester.pump();

    expect(createCalls, 1);
    // The freshly created task is in neither the prefetch nor the full-text
    // results, so the pick handler can only resolve the id the picker hands
    // back if the body registered it. Without that the tap is silently lost.
    expect(selected?.meta.id, 'new-task');
  });

  testWidgets('a failed create selects nothing', (tester) async {
    stubTasks([]);
    Task? selected;

    await tester.pumpWidget(
      makeTestableWidget(
        // makeTestableWidget hosts its child in a SingleChildScrollView, so
        // the body needs a bounded height of its own to lay its list out
        // against, and a Material ancestor for the search field.
        _Host(
          child: TaskSearchPickerBody(
            excludeIds: const {},
            onTaskSelected: (task) => selected = task,
            onCreateTask: (_) async => null,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await search(tester, 'Write the guide');
    await tester.tap(createRow());
    await tester.pump();

    expect(selected, isNull);
  });
}

/// Bounded, Material-backed host: `makeTestableWidget` puts its child in a
/// scroll view, which gives the picker an unbounded height, and the search
/// field needs a Material ancestor.
class _Host extends StatelessWidget {
  const _Host({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Material(child: SizedBox(height: 600, child: child));
}
