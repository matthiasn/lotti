import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_count_provider.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/ui/saved_filters/desktop/sidebar_saved_task_filters.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
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
}) async {
  final page = FakeJournalPageController(pageState);
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: dsTokensLight.spacing.step13 + dsTokensLight.spacing.step10,
            child: const SidebarSavedTaskFilters(),
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
