import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_provider.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_repository.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_mru_controller.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/ui/saved_filters/desktop/desktop_saved_task_view_bar.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/save_current_task_filter.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/saved_task_filters_sheet.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_utils/fake_journal_page_controller.dart';
import '../../../../../widget_test_utils.dart';
import '../../../../categories/test_utils.dart';

const _barHostKey = Key('desktop-saved-task-view-bar-host');

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
  int total = 214,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final page = FakeJournalPageController(pageState);
  final result = makeTestableWidgetWithContainer(
    Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          key: _barHostKey,
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
      allTasksTotalCountProvider.overrideWith((ref) async => total),
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
        tester
            .widget<Tooltip>(
              find.ancestor(of: current, matching: find.byType(Tooltip)),
            )
            .message,
        'Lotti · In progress',
      );
      expect(
        find.descendant(of: current, matching: find.text('5')),
        findsOneWidget,
      );
      final root = find.byKey(DesktopSavedTaskViewBarKeys.root);
      expect(tester.getTopLeft(current).dx, tester.getTopLeft(root).dx);
      expect(
        tester.getSize(current).width,
        lessThan(tester.getSize(root).width / 2),
        reason: 'the selected view stays compact instead of owning a flex cell',
      );

      await tester.tap(current);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SavedTaskFiltersSheet), findsOneWidget);
      expect(find.text('Saved views'), findsOneWidget);
    },
  );

  testWidgets('All is a compact primary view with the live total', (
    tester,
  ) async {
    await _pumpBar(tester);

    final current = find.byKey(DesktopSavedTaskViewBarKeys.currentView);
    expect(
      find.descendant(of: current, matching: find.text('All tasks')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: current, matching: find.text('214')),
      findsOneWidget,
    );
    expect(
      tester.getSize(current).width,
      lessThan(
        tester.getSize(find.byKey(DesktopSavedTaskViewBarKeys.root)).width,
      ),
    );
  });

  testWidgets('the primary selector supports an accessibility tap', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpBar(
      tester,
      pageState: const JournalPageState(
        selectedTaskStatuses: {'IN_PROGRESS'},
      ),
    );

    tester.semantics.tap(
      find.semantics.byLabel('Saved views, Lotti · In progress, 5 tasks'),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SavedTaskFiltersSheet), findsOneWidget);
    semantics.dispose();
  });

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
        tester.getCenter(blockedStatus).dy,
      );
      expect(
        tester.getCenter(blockedCount).dx,
        lessThan(tester.getCenter(blockedStatus).dx),
        reason: 'the task count leads each compact queue monitor',
      );
      expect(
        tester.widget<Text>(blockedCount).style!.fontSize,
        greaterThan(tester.widget<Text>(blockedStatus).style!.fontSize!),
        reason: 'queue magnitude is visually primary to the saved-view name',
      );
    },
  );

  testWidgets('wide current view keeps the complete saved name visible', (
    tester,
  ) async {
    await _pumpBar(
      tester,
      pageState: const JournalPageState(
        selectedTaskStatuses: {'IN_PROGRESS'},
      ),
      width: 1000,
    );

    final label = find.descendant(
      of: find.byKey(DesktopSavedTaskViewBarKeys.currentView),
      matching: find.text('Lotti · In progress'),
    );
    expect(label, findsOneWidget);
  });

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

  testWidgets('tapping All resets the active saved view', (tester) async {
    final bench = await _pumpBar(
      tester,
      pageState: const JournalPageState(
        selectedTaskStatuses: {'IN_PROGRESS'},
      ),
    );

    await tester.tap(find.byKey(DesktopSavedTaskViewBarKeys.allTasks));
    await tester.pump();

    expect(bench.page.applyBatchFilterUpdateCalled, 1);
    expect(bench.page.setSelectedTaskStatusesCalls.single, <String>{});
  });

  testWidgets('a custom view exposes the save flow in place', (tester) async {
    await _pumpBar(
      tester,
      pageState: const JournalPageState(selectedPriorities: {'P1'}),
    );

    await tester.tap(find.byKey(DesktopSavedTaskViewBarKeys.save));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(SaveCurrentTaskFilterKeys.nameField),
      findsOneWidget,
    );
  });

  testWidgets('category context stays visible on compact monitors', (
    tester,
  ) async {
    when(
      () => getIt<EntitiesCacheService>().getCategoryById('cat-work'),
    ).thenReturn(
      CategoryTestUtils.createTestCategory(
        id: 'cat-work',
        name: 'Work',
        color: '#00FF00',
      ),
    );
    const categorized = SavedTaskFilter(
      id: 'work',
      name: 'Work · Urgent',
      filter: TasksFilter(selectedCategoryIds: {'cat-work'}),
    );
    await _pumpBar(
      tester,
      pageState: const JournalPageState(
        selectedTaskStatuses: {'IN_PROGRESS'},
      ),
      saved: const [_inProgress, categorized],
      countsOverride: savedTaskFilterCountsProvider.overrideWith(
        (ref) async => const {'in-progress': 5, 'work': 8},
      ),
    );

    final monitor = find.byKey(DesktopSavedTaskViewBarKeys.monitor('work'));
    final dots = tester.widgetList<Container>(
      find.descendant(of: monitor, matching: find.byType(Container)),
    );
    expect(
      dots.any(
        (container) =>
            container.decoration is BoxDecoration &&
            (container.decoration! as BoxDecoration).shape == BoxShape.circle,
      ),
      isTrue,
    );
    expect(tester.getSemantics(monitor).label, contains('Work'));
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

  testWidgets(
    'large text keeps the saved-view run scrollable without overflow',
    (
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

      expect(
        find.byKey(DesktopSavedTaskViewBarKeys.currentView),
        findsOneWidget,
      );
      expect(find.byKey(DesktopSavedTaskViewBarKeys.allTasks), findsOneWidget);
      expect(
        find.byKey(DesktopSavedTaskViewBarKeys.monitor('blocked')),
        findsOneWidget,
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
    },
  );

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

  testWidgets(
    'real task-pane width keeps a single saved view and All compact and left aligned',
    (tester) async {
      const fooo = SavedTaskFilter(
        id: 'fooo',
        name: 'fooo',
        filter: TasksFilter(selectedTaskStatuses: {'IN_PROGRESS'}),
      );
      await _pumpBar(
        tester,
        pageState: const JournalPageState(
          selectedTaskStatuses: {'IN_PROGRESS'},
        ),
        saved: const [fooo],
        countsOverride: savedTaskFilterCountsProvider.overrideWith(
          (ref) async => const {'fooo': 2},
        ),
        total: 5,
        width: 490,
      );

      final root = find.byKey(DesktopSavedTaskViewBarKeys.root);
      final current = find.byKey(DesktopSavedTaskViewBarKeys.currentView);
      final all = find.byKey(DesktopSavedTaskViewBarKeys.allTasks);
      final hostRect = tester.getRect(find.byKey(_barHostKey));
      final rootRect = tester.getRect(root);
      final currentRect = tester.getRect(current);
      final allRect = tester.getRect(all);

      expect(
        currentRect.left,
        hostRect.left + dsTokensLight.spacing.step6,
        reason: 'the named saved-view selector is anchored to the pane start',
      );
      expect(currentRect.left, rootRect.left);
      expect(allRect.left, greaterThan(currentRect.right));
      expect(allRect.right, lessThan(rootRect.center.dx));
      expect(
        find.descendant(of: all, matching: find.text('5')),
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
