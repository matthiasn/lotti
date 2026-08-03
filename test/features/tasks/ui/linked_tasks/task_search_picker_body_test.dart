import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/task_search_picker_body.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/widgets/picker/entity_picker_sheet.dart';
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

  /// The tree under test. Re-pumping it rebuilds the body without resetting
  /// its state, which is how a test observes damage that a write left behind
  /// without scheduling a frame of its own.
  Widget bodyTree({
    Future<Task?> Function(String title)? onCreateTask,
    void Function(Task task)? onTaskSelected,
  }) => makeTestableWidget(
    // makeTestableWidget hosts its child in a SingleChildScrollView, so the
    // body needs a bounded height of its own to lay its list out against, and
    // a Material ancestor for the search field.
    _Host(
      child: TaskSearchPickerBody(
        excludeIds: const {},
        onTaskSelected: onTaskSelected ?? (_) {},
        onCreateTask: onCreateTask,
      ),
    ),
  );

  Future<void> pumpBody(
    WidgetTester tester, {
    Future<Task?> Function(String title)? onCreateTask,
  }) async {
    await tester.pumpWidget(bodyTree(onCreateTask: onCreateTask));
    await tester.pump();
    await tester.pump();
  }

  /// Types [query] and lets the picker settle on it: past the debounce, then a
  /// frame for the full-text lookup to land and be committed. Results only
  /// move once, at the end of this, which is the point.
  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pump(entityPickerSearchDebounce);
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

      // Mid-debounce the pool does not yet hold the match, so an unguarded
      // exact-title check would offer to create a duplicate of a task that
      // already exists.
      expect(createRow(), findsNothing);

      await tester.pump(entityPickerSearchDebounce);
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

  // The picker owns *when* a query is resolved; this body owns what a resolved
  // query costs and which results it is allowed to keep.
  group('full-text lookups', () {
    testWidgets('a burst of keystrokes costs one lookup, for the last query', (
      tester,
    ) async {
      stubTasks([buildTask(id: 'a', title: 'Apple Task')]);
      await pumpBody(tester);

      // Four characters inside one debounce window.
      for (final query in ['A', 'Ap', 'App', 'Appl']) {
        await tester.enterText(find.byType(TextField), query);
        await tester.pump(const Duration(milliseconds: 40));
      }
      verifyNever(() => fts5Db.watchFullTextMatches(any()));

      await tester.pump(entityPickerSearchDebounce);
      await tester.pump();

      // One query hits the index, not one per character. Typing used to open a
      // fresh Drift subscription per keystroke.
      verify(() => fts5Db.watchFullTextMatches('Appl')).called(1);
      verifyNoMoreInteractions(fts5Db);
    });

    testWidgets('the lookup is given the trimmed query', (tester) async {
      stubTasks([]);
      await pumpBody(tester);

      await search(tester, '  apple  ');

      // Surrounding whitespace is not part of what the user searched for, and
      // the exact-title check downstream compares trimmed titles.
      verify(() => fts5Db.watchFullTextMatches('apple')).called(1);
    });

    testWidgets(
      'clearing the search drops the out-of-window hits the last query found',
      (tester) async {
        final beyondWindow = buildTask(id: 'beyond', title: 'Past the window');
        stubTasks([buildTask(id: 'in-window', title: 'Prefetched task')]);
        stubFullTextHitsOutsideWindow([beyondWindow]);

        await pumpBody(tester);
        await search(tester, 'window');
        expect(find.text('Past the window'), findsOneWidget);

        await tester.enterText(find.byType(TextField), '');
        await tester.pump();

        // A cleared field shows what a freshly opened picker shows. Leaving
        // the last query's hits in the pool made the two disagree.
        expect(find.text('Past the window'), findsNothing);
        expect(find.text('Prefetched task'), findsOneWidget);
      },
    );

    testWidgets('a stale lookup landing last does not overwrite a newer one', (
      tester,
    ) async {
      stubTasks([
        buildTask(id: 'apple', title: 'Apple Task'),
        buildTask(id: 'banana', title: 'Banana Task'),
      ]);

      // Created here, not in setUp: a completer built in setUp belongs to
      // another zone and never resolves inside the test's fake async.
      final stale = Completer<List<String>>();
      when(
        () => fts5Db.watchFullTextMatches('stale'),
      ).thenAnswer((_) => Stream.fromFuture(stale.future));
      when(
        () => fts5Db.watchFullTextMatches('fresh'),
      ).thenAnswer((_) => Stream.value(<String>['banana']));

      await pumpBody(tester);

      // Settle on the query whose lookup never answers, so it is genuinely in
      // flight rather than cancelled by the debounce...
      await search(tester, 'stale');
      // ...then settle on a newer one that answers at once.
      await search(tester, 'fresh');
      expect(find.text('Banana Task'), findsOneWidget);

      stale.complete(<String>['apple']);
      await tester.pumpAndSettle();

      // The abandoned query's hits must not reappear under the newer query.
      expect(find.text('Banana Task'), findsOneWidget);
      expect(find.text('Apple Task'), findsNothing);

      // A stale write schedules no frame of its own, so it does no visible
      // damage until the list is next built for some other reason. Rebuild and
      // check again: an ungated write leaves the matches describing the
      // abandoned query, which silently drops the current query's results.
      await tester.pumpWidget(bodyTree());
      await tester.pump();
      expect(find.text('Banana Task'), findsOneWidget);
      expect(find.text('Apple Task'), findsNothing);
    });

    testWidgets('a stale lookup that fails last does not clear a newer one', (
      tester,
    ) async {
      // Titled so it can only be found through the index — a row that also
      // matched by title would survive the matches being wiped and prove
      // nothing.
      stubTasks([buildTask(id: 'banana', title: 'Banana Task')]);

      final stale = Completer<List<String>>();
      when(
        () => fts5Db.watchFullTextMatches('stale'),
      ).thenAnswer((_) => Stream.fromFuture(stale.future));
      when(
        () => fts5Db.watchFullTextMatches('fresh'),
      ).thenAnswer((_) => Stream.value(<String>['banana']));

      await pumpBody(tester);
      await search(tester, 'stale');
      await search(tester, 'fresh');
      expect(find.text('Banana Task'), findsOneWidget);

      // The abandoned lookup errors rather than answering. Its failure handler
      // resets the matches too, so it needs the same generation guard the
      // success path has — without one it wipes the newer query's only route
      // to its results.
      stale.completeError(Exception('fts unavailable'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(bodyTree());
      await tester.pump();

      expect(find.text('Banana Task'), findsOneWidget);
    });

    testWidgets(
      'a row still on screen from the previous query can be picked after a '
      'newer lookup has replaced the matches',
      (tester) async {
        final first = buildTask(id: 'first', title: 'Past the window one');
        final second = buildTask(id: 'second', title: 'Past the window two');
        stubTasks([]);
        when(
          () => fts5Db.watchFullTextMatches('one'),
        ).thenAnswer((_) => Stream.value(<String>['first']));
        when(
          () => fts5Db.watchFullTextMatches('two'),
        ).thenAnswer((_) => Stream.value(<String>['second']));
        when(() => journalDb.getJournalEntitiesForIds({'first'})).thenAnswer(
          (_) async => [first],
        );
        when(() => journalDb.getJournalEntitiesForIds({'second'})).thenAnswer(
          (_) async => [second],
        );

        Task? selected;
        await tester.pumpWidget(
          bodyTree(onTaskSelected: (task) => selected = task),
        );
        await tester.pump();
        await tester.pump();

        await search(tester, 'one');
        expect(find.text('Past the window one'), findsOneWidget);

        // The second lookup lands and overwrites the resolved matches.
        await search(tester, 'two');
        expect(find.text('Past the window two'), findsOneWidget);

        // The real window is sub-frame — `setState` only schedules the
        // repaint, so the first query's row stays mounted and hit-testable
        // until it lands, and a tap there arrives with the matches already
        // replaced. A tap cannot be driven into that window (tapping requires
        // pumping, which closes it), so the pick contract is exercised
        // directly: an id the picker rendered must still resolve.
        final sheet = tester.widget<EntityPickerSheet>(
          find.byType(EntityPickerSheet),
        );
        await sheet.onPick!('first');

        // Resolving from the latest lookup alone dropped this on the floor.
        expect(selected?.meta.id, 'first');
      },
    );

    testWidgets('a task only the lookup found can still be picked', (
      tester,
    ) async {
      final beyondWindow = buildTask(id: 'beyond', title: 'Past the window');
      stubTasks([buildTask(id: 'in-window', title: 'Prefetched task')]);
      stubFullTextHitsOutsideWindow([beyondWindow]);

      Task? selected;
      await tester.pumpWidget(
        bodyTree(onTaskSelected: (task) => selected = task),
      );
      await tester.pump();
      await tester.pump();

      await search(tester, 'window');
      await tester.tap(find.text('Past the window'));
      await tester.pump();

      // Rendering a row the pick handler cannot resolve is what let the picker
      // surface a task and then throw on the tap.
      expect(tester.takeException(), isNull);
      expect(selected?.meta.id, 'beyond');
    });
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
