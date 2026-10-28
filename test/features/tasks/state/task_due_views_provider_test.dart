import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_page_state.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_provider.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_repository.dart';
import 'package:lotti/features/tasks/state/task_due_views_provider.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/service_overrides.dart';
import '../../../test_utils/fake_journal_page_controller.dart';
import '../../../widget_test_utils.dart';

/// Records every filter it is asked to count and answers by due clause.
class _RecordingRepo implements SavedTaskFilterCountRepository {
  _RecordingRepo({required this.overdue, required this.dueToday});

  final int overdue;
  final int dueToday;
  final List<TasksFilter> asked = [];

  @override
  Future<int> count(TasksFilter filter) async {
    asked.add(filter);
    return switch (filter.dueFilter) {
      TaskDueFilter.overdue => overdue,
      TaskDueFilter.dueToday => dueToday,
      TaskDueFilter.all => -1,
    };
  }

  @override
  Future<DueDateUrgency> dueUrgency(TasksFilter filter) async =>
      DueDateUrgency.normal;
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
    _RecordingRepo repo,
  ) async {
    final container = ProviderContainer(
      overrides: withServiceOverrides([
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

  test('counts each view as the live filter with that due clause', () async {
    final repo = _RecordingRepo(overdue: 3, dueToday: 2);

    final counts = await countsFor(
      const JournalPageState(
        selectedTaskStatuses: {'OPEN'},
        selectedCategoryIds: {'cat-1'},
      ),
      repo,
    );

    expect(counts.overdue, 3);
    expect(counts.dueToday, 2);
    expect(counts.of(TaskDueFilter.overdue), 3);
    expect(counts.of(TaskDueFilter.dueToday), 2);
    expect(repo.asked.map((f) => f.dueFilter), [
      TaskDueFilter.overdue,
      TaskDueFilter.dueToday,
    ]);
    // Every other clause rides along, so the pill counts what it would list.
    for (final filter in repo.asked) {
      expect(filter.selectedTaskStatuses, {'OPEN'});
      expect(filter.selectedCategoryIds, {'cat-1'});
    }
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
    expect(
      repo.asked.map((f) => f.dueFilter),
      containsAll([TaskDueFilter.overdue, TaskDueFilter.dueToday]),
    );
  });

  test(
    'an empty status selection counts every status, like the list',
    () async {
      final repo = _RecordingRepo(overdue: 0, dueToday: 0);

      await countsFor(const JournalPageState(), repo);

      for (final filter in repo.asked) {
        expect(filter.selectedTaskStatuses, {...allTaskStatuses});
      }
    },
  );

  test('all is not a view', () {
    expect(
      () => const TaskDueViewCounts(
        overdue: 1,
        dueToday: 1,
      ).of(TaskDueFilter.all),
      throwsArgumentError,
    );
  });
}
