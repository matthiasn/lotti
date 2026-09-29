import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_provider.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/ui/saved_filters/mobile/saved_task_filters_sheet.dart';
import 'package:lotti/features/tasks/ui/saved_filters/sidebar/sidebar_saved_task_filters.dart';
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

Future<FakeJournalPageController> _pumpSidebar(
  WidgetTester tester, {
  List<SavedTaskFilter> saved = _saved,
  JournalPageState pageState = const JournalPageState(),
  VoidCallback? onApplied,
}) async {
  final page = FakeJournalPageController(pageState);
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: dsTokensLight.spacing.step13 + dsTokensLight.spacing.step10,
            child: SidebarSavedTaskFilters(onApplied: onApplied),
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

  group('tap targets', () {
    Size inkSize(WidgetTester tester, Key rowKey) => tester.getSize(
      find.descendant(of: find.byKey(rowKey), matching: find.byType(InkWell)),
    );

    List<Key> rowKeys() => [
      SidebarSavedTaskFiltersKeys.allTasks,
      SidebarSavedTaskFiltersKeys.filter('alpha'),
      SidebarSavedTaskFiltersKeys.showMore,
    ];

    testWidgets('meet the touch floor on a compact window, where the list '
        'rides the mobile drawer', (tester) async {
      setTestSurfaceSize(tester, const Size(390, 844));
      await _pumpSidebar(tester);

      for (final key in rowKeys()) {
        expect(
          inkSize(tester, key).height,
          greaterThanOrEqualTo(TapTargets.minimum),
          reason: '$key',
        );
      }
      final manage = tester.getSize(
        find.byKey(SidebarSavedTaskFiltersKeys.manage),
      );
      expect(manage.width, greaterThanOrEqualTo(TapTargets.minimum));
      expect(manage.height, greaterThanOrEqualTo(TapTargets.minimum));
    });

    testWidgets('stay pointer-sized on the desktop rail', (tester) async {
      setTestSurfaceSize(tester, const Size(1280, 800));
      await _pumpSidebar(tester);

      for (final key in rowKeys()) {
        expect(
          inkSize(tester, key).height,
          lessThan(TapTargets.minimum),
          reason: '$key',
        );
      }
      final manage = tester.getSize(
        find.byKey(SidebarSavedTaskFiltersKeys.manage),
      );
      expect(manage.height, lessThan(TapTargets.minimum));
    });
  });
}
