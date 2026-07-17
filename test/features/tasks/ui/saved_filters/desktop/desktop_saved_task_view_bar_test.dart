import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_provider.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_repository.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_mru_controller.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/ui/saved_filters/desktop/desktop_saved_task_view_bar.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/saved_task_filters_sheet.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_utils/fake_journal_page_controller.dart';
import '../../../../../widget_test_utils.dart';

const _inProgress = SavedTaskFilter(
  id: 'in-progress',
  name: 'Lotti · In progress',
  filter: TasksFilter(selectedTaskStatuses: {'IN_PROGRESS'}),
);
const _blocked = SavedTaskFilter(
  id: 'blocked',
  name: 'Lotti · Blocked',
  filter: TasksFilter(selectedTaskStatuses: {'BLOCKED'}),
);
const _groomed = SavedTaskFilter(
  id: 'groomed',
  name: 'Lotti · Groomed',
  filter: TasksFilter(selectedTaskStatuses: {'GROOMED'}),
);
const _urgent = SavedTaskFilter(
  id: 'urgent',
  name: 'Lotti · Urgent',
  filter: TasksFilter(selectedPriorities: {'P0'}),
);
const _later = SavedTaskFilter(
  id: 'later',
  name: 'Later',
  filter: TasksFilter(selectedTaskStatuses: {'ON HOLD'}),
);

const List<SavedTaskFilter> _saved = [
  _inProgress,
  _blocked,
  _groomed,
  _urgent,
  _later,
];
const _counts = {
  'in-progress': 5,
  'blocked': 9,
  'groomed': 146,
  'urgent': 3,
  'later': 17,
};

class _StubSavedController extends SavedTaskFiltersController {
  _StubSavedController(this.seed);

  final List<SavedTaskFilter> seed;

  @override
  Future<List<SavedTaskFilter>> build() async => seed;
}

class _GatedCountRepository implements SavedTaskFilterCountRepository {
  _GatedCountRepository(this.value);

  int value;
  Completer<int>? gate;

  @override
  Future<int> count(TasksFilter filter) {
    final pending = gate;
    if (pending != null) return pending.future;
    return Future.value(value);
  }
}

Future<({ProviderContainer container, FakeJournalPageController page})>
_pumpBar(
  WidgetTester tester, {
  JournalPageState pageState = const JournalPageState(),
  List<SavedTaskFilter> saved = _saved,
  List<Override> extraOverrides = const [],
  Override? countsOverride,
  double width = 620,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final page = FakeJournalPageController(pageState);
  final result = makeTestableWidgetWithContainer(
    Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: const DesktopSavedTaskViewBar(),
        ),
      ),
    ),
    mediaQueryData: MediaQueryData(
      size: const Size(1400, 900),
      textScaler: textScaler,
    ),
    overrides: [
      journalPageControllerProvider(true).overrideWith(() => page),
      savedTaskFiltersControllerProvider.overrideWith(
        () => _StubSavedController(saved),
      ),
      countsOverride ??
          savedTaskFilterCountsProvider.overrideWith(
            (ref) async => _counts,
          ),
      allTasksTotalCountProvider.overrideWith((ref) async => 214),
      currentTasksFilterCountProvider.overrideWith((ref) async => 4),
      ...extraOverrides,
    ],
  );
  addTearDown(result.container.dispose);
  await tester.pumpWidget(result.widget);
  await tester.pump();
  await tester.pump();
  return (container: result.container, page: page);
}

void main() {
  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        final cache = MockEntitiesCacheService();
        when(() => cache.getCategoryById(any())).thenReturn(null);
        getIt.registerSingleton<EntitiesCacheService>(cache);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  testWidgets('collapses when no saved views exist', (tester) async {
    await _pumpBar(tester, saved: const []);

    expect(
      find.byKey(DesktopSavedTaskViewBarKeys.currentView),
      findsNothing,
    );
    expect(
      tester.getSize(find.byKey(DesktopSavedTaskViewBarKeys.root)).height,
      0,
    );
  });

  testWidgets(
    'current view is the primary selector, keeps its count, and opens the sheet',
    (tester) async {
      await _pumpBar(
        tester,
        pageState: const JournalPageState(
          selectedTaskStatuses: {'IN_PROGRESS'},
        ),
      );

      final current = find.byKey(DesktopSavedTaskViewBarKeys.currentView);
      expect(
        find.descendant(
          of: current,
          matching: find.text('Lotti · In progress'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: current, matching: find.text('5')),
        findsOneWidget,
      );

      await tester.tap(current);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SavedTaskFiltersSheet), findsOneWidget);
      expect(find.text('Saved views'), findsOneWidget);
    },
  );

  testWidgets(
    'watchlist is stable saved order with count first, not recent-use order',
    (tester) async {
      final bench = await _pumpBar(
        tester,
        pageState: const JournalPageState(
          selectedTaskStatuses: {'IN_PROGRESS'},
        ),
      );

      // The active view is kept in the primary selector. The four watch slots
      // are the All reset followed by the next three views in persisted order.
      // "Later" is outside the cap even after MRU promotion.
      expect(find.byKey(DesktopSavedTaskViewBarKeys.allTasks), findsOneWidget);
      for (final id in ['blocked', 'groomed', 'urgent']) {
        expect(
          find.byKey(DesktopSavedTaskViewBarKeys.monitor(id)),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(DesktopSavedTaskViewBarKeys.monitor('later')),
        findsNothing,
      );

      bench.container.read(savedTaskFilterMruProvider.notifier).touch('later');
      await tester.pump();
      expect(
        find.byKey(DesktopSavedTaskViewBarKeys.monitor('later')),
        findsNothing,
        reason: 'recency must not silently redefine the watchlist',
      );

      final blocked = find.byKey(
        DesktopSavedTaskViewBarKeys.monitor('blocked'),
      );
      final blockedCount = find.descendant(
        of: blocked,
        matching: find.text('9'),
      );
      final blockedStatus = find.descendant(
        of: blocked,
        matching: find.text('Blocked'),
      );
      expect(
        find.descendant(of: blocked, matching: find.text('Lotti')),
        findsNothing,
        reason: 'the category dot replaces the redundant category prefix',
      );
      expect(
        tester.getCenter(blockedCount).dy,
        lessThan(
          tester.getCenter(blockedStatus).dy,
        ),
        reason: 'the task count leads each compact queue monitor',
      );
      expect(
        tester.widget<Text>(blockedCount).style!.fontSize,
        greaterThan(tester.widget<Text>(blockedStatus).style!.fontSize!),
        reason: 'queue magnitude is visually primary to the saved-view name',
      );
    },
  );

  testWidgets('tapping a monitor applies its saved filter', (tester) async {
    final bench = await _pumpBar(
      tester,
      pageState: const JournalPageState(
        selectedTaskStatuses: {'IN_PROGRESS'},
      ),
    );

    await tester.tap(
      find.byKey(DesktopSavedTaskViewBarKeys.monitor('blocked')),
    );
    await tester.pump();

    expect(bench.page.applyBatchFilterUpdateCalled, 1);
    expect(bench.page.setSelectedTaskStatusesCalls.single, {'BLOCKED'});
  });

  testWidgets('custom view keeps reset and save while reducing monitor noise', (
    tester,
  ) async {
    await _pumpBar(
      tester,
      pageState: const JournalPageState(selectedPriorities: {'P1'}),
    );

    final current = find.byKey(DesktopSavedTaskViewBarKeys.currentView);
    expect(
      find.descendant(of: current, matching: find.text('Custom')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: current, matching: find.text('4')),
      findsOneWidget,
    );
    expect(find.byKey(DesktopSavedTaskViewBarKeys.allTasks), findsOneWidget);
    expect(find.byKey(DesktopSavedTaskViewBarKeys.save), findsOneWidget);
    expect(
      find.byKey(DesktopSavedTaskViewBarKeys.monitor('in-progress')),
      findsOneWidget,
    );
    expect(
      find.byKey(DesktopSavedTaskViewBarKeys.monitor('blocked')),
      findsNothing,
    );
  });

  testWidgets('large text keeps the current view and reset without overflow', (
    tester,
  ) async {
    await _pumpBar(
      tester,
      pageState: const JournalPageState(
        selectedTaskStatuses: {'IN_PROGRESS'},
      ),
      width: 480,
      textScaler: const TextScaler.linear(1.6),
    );

    expect(find.byKey(DesktopSavedTaskViewBarKeys.currentView), findsOneWidget);
    expect(find.byKey(DesktopSavedTaskViewBarKeys.allTasks), findsOneWidget);
    expect(
      find.byKey(DesktopSavedTaskViewBarKeys.monitor('blocked')),
      findsNothing,
    );
    expect(
      tester
          .widget<SingleChildScrollView>(
            find.byKey(DesktopSavedTaskViewBarKeys.root),
          )
          .scrollDirection,
      Axis.horizontal,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'narrow desktop pane reduces monitors before labels become noise',
    (
      tester,
    ) async {
      await _pumpBar(
        tester,
        pageState: const JournalPageState(
          selectedTaskStatuses: {'IN_PROGRESS'},
        ),
        width: 400,
      );

      expect(find.byKey(DesktopSavedTaskViewBarKeys.allTasks), findsOneWidget);
      expect(
        find.byKey(DesktopSavedTaskViewBarKeys.monitor('blocked')),
        findsOneWidget,
      );
      expect(
        find.byKey(DesktopSavedTaskViewBarKeys.monitor('groomed')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(DesktopSavedTaskViewBarKeys.monitor('blocked')),
          matching: find.text('Blocked'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('retains visible counts while a background refresh is pending', (
    tester,
  ) async {
    final repository = _GatedCountRepository(12);
    final bench = await _pumpBar(
      tester,
      pageState: const JournalPageState(
        selectedTaskStatuses: {'IN_PROGRESS'},
      ),
      saved: const [_inProgress, _blocked],
      countsOverride: savedTaskFilterCountsProvider.overrideWith(
        savedTaskFilterCounts,
      ),
      extraOverrides: [
        savedTaskFilterCountRepositoryProvider.overrideWithValue(repository),
      ],
    );

    final current = find.byKey(DesktopSavedTaskViewBarKeys.currentView);
    expect(
      find.descendant(of: current, matching: find.text('12')),
      findsOneWidget,
    );

    repository.gate = Completer<int>();
    bench.container.invalidate(savedTaskFilterCountsProvider);
    await tester.pump();
    await tester.pump();

    expect(
      find.descendant(of: current, matching: find.text('12')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: current, matching: find.text('–')),
      findsNothing,
    );

    repository.gate!.complete(12);
    await tester.pump();
  });
}
