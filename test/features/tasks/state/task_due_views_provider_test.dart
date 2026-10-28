import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_page_state.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_provider.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_repository.dart';
import 'package:lotti/features/tasks/state/task_due_view_counts.dart';
import 'package:lotti/features/tasks/state/task_due_views_provider.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/service_overrides.dart';
import '../../../mocks/mocks.dart';
import '../../../test_utils/fake_journal_page_controller.dart';
import '../../../widget_test_utils.dart';

/// Records every filter the provider asks it to count both views for.
class _RecordingRepo implements SavedTaskFilterCountRepository {
  _RecordingRepo({required this.overdue, required this.dueToday});

  final int overdue;
  final int dueToday;
  final List<TasksFilter> asked = [];
  final List<Set<String>?> restrictions = [];

  @override
  Future<TaskDueViewCounts> dueViewCounts(
    TasksFilter filter, {
    Set<String>? restrictToIds,
  }) async {
    asked.add(filter);
    restrictions.add(restrictToIds);
    return TaskDueViewCounts(overdue: overdue, dueToday: dueToday);
  }

  // The views must come from the one batched call, never from two counts.
  @override
  Future<int> count(TasksFilter filter, {Set<String>? restrictToIds}) =>
      throw StateError('smart views counted view by view');

  @override
  Future<List<DueDateUrgency>> dueUrgencies(List<TasksFilter> filters) =>
      throw UnimplementedError();
}

void main() {
  setUp(() async {
    final mocks = await setUpTestGetIt();
    when(
      () => mocks.updateNotifications.updateStream,
    ).thenAnswer((_) => const Stream.empty());
  });
  tearDown(tearDownTestGetIt);

  Future<TaskDueViewCounts> countsFor(
    JournalPageState pageState,
    _RecordingRepo repo, {
    Fts5Db? fts,
  }) async {
    final container = ProviderContainer(
      overrides: withServiceOverrides([
        if (fts != null) fts5DbProvider.overrideWithValue(fts),
        journalPageControllerProvider(
          true,
        ).overrideWith(() => FakeJournalPageController(pageState)),
        savedTaskFilterCountRepositoryProvider.overrideWithValue(repo),
      ]),
    );
    addTearDown(container.dispose);
    final sub = container.listen(taskDueViewCountsProvider, (_, _) {});
    addTearDown(sub.close);
    return container.read(taskDueViewCountsProvider.future);
  }

  test('counts both views from the live filter in one call', () async {
    final repo = _RecordingRepo(overdue: 3, dueToday: 2);

    final counts = await countsFor(
      const JournalPageState(
        selectedTaskStatuses: {'OPEN'},
        selectedCategoryIds: {'cat-1'},
      ),
      repo,
    );

    expect((counts.overdue, counts.dueToday), (3, 2));
    // Every other clause rides along, so the pill counts what it would list.
    expect(repo.asked.single.selectedTaskStatuses, {'OPEN'});
    expect(repo.asked.single.selectedCategoryIds, {'cat-1'});
  });

  test("an active view does not hide the other view's count", () async {
    final repo = _RecordingRepo(overdue: 4, dueToday: 1);

    final counts = await countsFor(
      const JournalPageState(
        selectedTaskStatuses: {'OPEN'},
        dueFilter: TaskDueFilter.overdue,
      ),
      repo,
    );

    expect(counts.dueToday, 1);
    expect(repo.asked, hasLength(1));
  });

  test(
    'an empty status selection counts every status, like the list',
    () async {
      final repo = _RecordingRepo(overdue: 0, dueToday: 0);

      await countsFor(const JournalPageState(), repo);

      expect(repo.asked.single.selectedTaskStatuses, {...allTaskStatuses});
    },
  );

  test('no search, no restriction', () async {
    final repo = _RecordingRepo(overdue: 0, dueToday: 0);

    await countsFor(const JournalPageState(), repo);

    expect(repo.restrictions, [null]);
  });

  test('a full-text search restricts both counts to its matches', () async {
    final repo = _RecordingRepo(overdue: 1, dueToday: 0);
    final fts = MockFts5Db();
    when(
      () => fts.watchFullTextMatches('habitat'),
    ).thenAnswer((_) => Stream.value(const ['t1', 't2']));

    await countsFor(
      const JournalPageState(match: 'habitat'),
      repo,
      fts: fts,
    );

    expect(repo.restrictions, [
      {'t1', 't2'},
    ]);
  });

  test('a semantic search restricts to the vector result set', () async {
    final repo = _RecordingRepo(overdue: 1, dueToday: 0);
    final fts = MockFts5Db();

    await countsFor(
      const JournalPageState(
        match: 'fish',
        enableVectorSearch: true,
        searchMode: SearchMode.vector,
        vectorSearchDistances: {'v1': 0.1, 'v2': 0.3},
      ),
      repo,
      fts: fts,
    );

    expect(repo.restrictions.first, {'v1', 'v2'});
    verifyNever(() => fts.watchFullTextMatches(any()));
  });
}
