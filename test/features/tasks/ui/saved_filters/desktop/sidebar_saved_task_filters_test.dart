import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_provider.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_mru_controller.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/ui/saved_filters/desktop/sidebar_saved_task_filters.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/saved_task_filters_sheet.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../test_utils/fake_journal_page_controller.dart';
import '../../../../../widget_test_utils.dart';

const _saved = <SavedTaskFilter>[
  SavedTaskFilter(
    id: 'alpha',
    name: 'Alpha',
    filter: TasksFilter(selectedTaskStatuses: {'OPEN'}),
  ),
  SavedTaskFilter(
    id: 'blocked',
    name: 'Blocked',
    filter: TasksFilter(selectedTaskStatuses: {'BLOCKED'}),
  ),
  SavedTaskFilter(id: 'charlie', name: 'Charlie', filter: TasksFilter()),
  SavedTaskFilter(id: 'delta', name: 'Delta', filter: TasksFilter()),
  SavedTaskFilter(id: 'echo', name: 'Echo', filter: TasksFilter()),
  SavedTaskFilter(id: 'foxtrot', name: 'Foxtrot', filter: TasksFilter()),
  SavedTaskFilter(id: 'golf', name: 'Golf', filter: TasksFilter()),
];

class _StubSavedController extends SavedTaskFiltersController {
  _StubSavedController(this.seed);

  final List<SavedTaskFilter> seed;

  @override
  Future<List<SavedTaskFilter>> build() async => seed;
}

/// Holds every batch filter update open until [release], so a test can act
/// while a tapped filter is still landing.
class _GatedJournalPageController extends FakeJournalPageController {
  _GatedJournalPageController() : super(const JournalPageState());

  final _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<void> applyBatchFilterUpdate({
    Set<String>? statuses,
    Set<String>? categoryIds,
    Set<String>? labelIds,
    Set<String>? projectIds,
    Set<String>? priorities,
    TaskSortOption? sortOption,
    AgentAssignmentFilter? agentAssignmentFilter,
    SearchMode? searchMode,
    bool? showCreationDate,
    bool? showDueDate,
  }) async {
    await super.applyBatchFilterUpdate(
      statuses: statuses,
      categoryIds: categoryIds,
      labelIds: labelIds,
      projectIds: projectIds,
      priorities: priorities,
      sortOption: sortOption,
      agentAssignmentFilter: agentAssignmentFilter,
      searchMode: searchMode,
      showCreationDate: showCreationDate,
      showDueDate: showDueDate,
    );
    await _gate.future;
  }
}

Future<FakeJournalPageController> _pumpSidebar(
  WidgetTester tester, {
  List<SavedTaskFilter> saved = _saved,
  JournalPageState pageState = const JournalPageState(),
  VoidCallback? onApplied,
  FakeJournalPageController? pageController,
  ValueListenable<bool>? showSidebar,
}) async {
  final page = pageController ?? FakeJournalPageController(pageState);
  final sidebar = SidebarSavedTaskFilters(onApplied: onApplied);
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: dsTokensLight.spacing.step13 + dsTokensLight.spacing.step10,
            child: showSidebar == null
                ? sidebar
                : ValueListenableBuilder<bool>(
                    valueListenable: showSidebar,
                    builder: (_, show, _) =>
                        show ? sidebar : const SizedBox.shrink(),
                  ),
          ),
        ),
      ),
      overrides: [
        journalPageControllerProvider(true).overrideWith(() => page),
        savedTaskFiltersControllerProvider.overrideWith(
          () => _StubSavedController(saved),
        ),
        savedTaskFilterCountsProvider.overrideWith(
          (ref) async => const {
            'alpha': 11,
            'blocked': 9,
            'charlie': 8,
            'delta': 7,
            'echo': 6,
            'foxtrot': 5,
            'golf': 4,
          },
        ),
        allTasksTotalCountProvider.overrideWith((ref) async => 50),
      ],
    ),
  );
  await tester.pump();
  await tester.pump();
  return page;
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

  testWidgets('collapses when no saved filters exist', (tester) async {
    await _pumpSidebar(tester, saved: const []);

    expect(find.byKey(SidebarSavedTaskFiltersKeys.allTasks), findsNothing);
    expect(
      tester.getSize(find.byKey(SidebarSavedTaskFiltersKeys.root)).height,
      0,
    );
  });

  testWidgets('shows All and the first five persisted filters with counts', (
    tester,
  ) async {
    await _pumpSidebar(tester);

    expect(find.byKey(SidebarSavedTaskFiltersKeys.allTasks), findsOneWidget);
    for (final filter in _saved.take(5)) {
      expect(
        find.byKey(SidebarSavedTaskFiltersKeys.filter(filter.id)),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(SidebarSavedTaskFiltersKeys.filter('foxtrot')),
      findsNothing,
    );
    expect(find.text('50'), findsOneWidget);
    expect(find.text('11'), findsOneWidget);
    expect(find.text('2 more saved filters'), findsOneWidget);
  });

  testWidgets('a category-scoped filter announces its category first', (
    tester,
  ) async {
    final cache = getIt<EntitiesCacheService>() as MockEntitiesCacheService;
    when(
      () => cache.getCategoryById(categoryMindfulness.id),
    ).thenReturn(categoryMindfulness);
    await _pumpSidebar(
      tester,
      saved: [
        SavedTaskFilter(
          id: 'alpha',
          name: 'Alpha',
          filter: TasksFilter(selectedCategoryIds: {categoryMindfulness.id}),
        ),
      ],
    );

    expect(
      find.bySemanticsLabel('${categoryMindfulness.name}, Alpha, 11 tasks'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('All tasks, 50 tasks'), findsOneWidget);
  });

  testWidgets('More expands every filter and Show fewer restores five', (
    tester,
  ) async {
    await _pumpSidebar(tester);

    await tester.tap(find.byKey(SidebarSavedTaskFiltersKeys.showMore));
    await tester.pump();

    expect(
      find.byKey(SidebarSavedTaskFiltersKeys.filter('foxtrot')),
      findsOneWidget,
    );
    expect(
      find.byKey(SidebarSavedTaskFiltersKeys.filter('golf')),
      findsOneWidget,
    );
    expect(find.byKey(SidebarSavedTaskFiltersKeys.showLess), findsOneWidget);

    await tester.tap(find.byKey(SidebarSavedTaskFiltersKeys.showLess));
    await tester.pump();

    expect(
      find.byKey(SidebarSavedTaskFiltersKeys.filter('foxtrot')),
      findsNothing,
    );
    expect(find.byKey(SidebarSavedTaskFiltersKeys.showMore), findsOneWidget);
  });

  testWidgets('tapping saved and All rows applies the corresponding filter', (
    tester,
  ) async {
    final page = await _pumpSidebar(tester);

    await tester.tap(
      find.byKey(SidebarSavedTaskFiltersKeys.filter('blocked')),
    );
    await tester.pump();

    expect(page.setSelectedTaskStatusesCalls.single, {'BLOCKED'});

    await tester.tap(find.byKey(SidebarSavedTaskFiltersKeys.allTasks));
    await tester.pump();

    expect(page.setSelectedTaskStatusesCalls.last, <String>{});
    expect(page.applyBatchFilterUpdateCalled, 2);
  });

  group('onApplied', () {
    testWidgets('fires once a saved filter has been applied', (tester) async {
      late FakeJournalPageController page;
      final appliedWith = <Set<String>>[];
      page = await _pumpSidebar(
        tester,
        onApplied: () =>
            appliedWith.add(page.setSelectedTaskStatusesCalls.last),
      );

      await tester.tap(
        find.byKey(SidebarSavedTaskFiltersKeys.filter('blocked')),
      );
      await tester.pump();

      // Called after the filter landed, not before: the page already holds
      // the filter's statuses when the callback runs.
      expect(appliedWith, [
        {'BLOCKED'},
      ]);
    });

    testWidgets('fires once All tasks has been applied', (tester) async {
      late FakeJournalPageController page;
      final appliedWith = <Set<String>>[];
      page = await _pumpSidebar(
        tester,
        onApplied: () =>
            appliedWith.add(page.setSelectedTaskStatusesCalls.last),
      );

      await tester.tap(find.byKey(SidebarSavedTaskFiltersKeys.allTasks));
      await tester.pump();

      expect(appliedWith, [<String>{}]);
      expect(page.applyBatchFilterUpdateCalled, 1);
    });

    for (final (name, tapKey) in [
      ('a saved filter', SidebarSavedTaskFiltersKeys.filter('blocked')),
      ('All tasks', SidebarSavedTaskFiltersKeys.allTasks),
    ]) {
      testWidgets('does not fire when the list unmounted while $name was '
          'landing', (tester) async {
        final page = _GatedJournalPageController();
        final show = ValueNotifier<bool>(true);
        addTearDown(show.dispose);
        var applied = 0;
        await _pumpSidebar(
          tester,
          pageController: page,
          showSidebar: show,
          onApplied: () => applied++,
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SidebarSavedTaskFilters)),
        );

        await tester.tap(find.byKey(tapKey));
        await tester.pump();
        expect(page.applyBatchFilterUpdateCalled, 1);

        // The host goes away (e.g. the window crossed the desktop
        // breakpoint) before the filter has landed.
        show.value = false;
        await tester.pump();
        expect(find.byType(SidebarSavedTaskFilters), findsNothing);

        page.release();
        await tester.pump();

        expect(applied, 0);
        // The recency order is independent of the list's lifecycle.
        expect(
          container.read(savedTaskFilterMruProvider),
          tapKey == SidebarSavedTaskFiltersKeys.allTasks
              ? isEmpty
              : ['blocked'],
        );
      });
    }

    testWidgets('does not fire for Manage, More or Show fewer, which leave '
        'the list where it is', (tester) async {
      var applied = 0;
      await _pumpSidebar(tester, onApplied: () => applied++);

      await tester.tap(find.byKey(SidebarSavedTaskFiltersKeys.showMore));
      await tester.pump();
      await tester.tap(find.byKey(SidebarSavedTaskFiltersKeys.showLess));
      await tester.pump();
      await tester.tap(find.byKey(SidebarSavedTaskFiltersKeys.manage));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(SavedTaskFiltersSheet), findsOneWidget);
      expect(applied, 0);
    });
  });

  testWidgets('the manage action opens the saved-filters manager sheet', (
    tester,
  ) async {
    await _pumpSidebar(tester);
    expect(find.byType(SavedTaskFiltersSheet), findsNothing);

    await tester.tap(find.byKey(SidebarSavedTaskFiltersKeys.manage));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final sheet = find.byType(SavedTaskFiltersSheet);
    expect(sheet, findsOneWidget);
    // The manager lists every saved filter, including the two the sidebar
    // folds behind "more".
    expect(
      find.descendant(of: sheet, matching: find.text('Golf')),
      findsOneWidget,
    );
  });

  testWidgets('sidebar labels and counts use design-system caption type', (
    tester,
  ) async {
    await _pumpSidebar(tester);

    final label = tester.widget<Text>(find.text('Alpha'));
    final count = tester.widget<Text>(find.text('11'));
    final caption = dsTokensLight.typography.styles.others.caption;

    expect(label.style?.fontFamily, caption.fontFamily);
    expect(label.style?.fontSize, caption.fontSize);
    expect(count.style?.fontFamily, caption.fontFamily);
    expect(count.style?.fontSize, caption.fontSize);
  });
}
