import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/habits/state/habits_controller.dart';
import 'package:lotti/features/habits/state/habits_state.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/recent_searches/domain/recent_search.dart';
import 'package:lotti/features/recent_searches/ui/recent_search_opener.dart';
import 'package:material_ui/material_ui.dart';

import '../../../mocks/mocks.dart';
import '../../../test_utils/fake_journal_page_controller.dart';
import '../../../widget_test_utils.dart';
import '../../habits/test_utils.dart';
import '../test_utils.dart';

/// Everything [openRecentSearch] can touch, faked, plus the container the
/// real (dependency-free) projects filter lives in.
class _Bench {
  final navService = RecordingMockNavService();
  final recents = FakeRecentSearchesController();
  final tasks = FakeJournalPageController(const JournalPageState());
  final logbook = FakeJournalPageController(const JournalPageState());
  late final FakeHabitsController habits;
  late final ProviderContainer container;

  List<Override> overrides({required bool habitsSearchShowing}) {
    habits = FakeHabitsController(
      HabitsState.initial(
        now: DateTime(2024, 3, 15),
      ).copyWith(showSearch: habitsSearchShowing),
    );
    return [
      fakeRecentSearches(recents),
      journalPageControllerProvider(true).overrideWith(() => tasks),
      journalPageControllerProvider(false).overrideWith(() => logbook),
      habitsControllerProvider.overrideWith(() => habits),
    ];
  }

  /// Pumps a button that opens [search] when tapped, and taps it.
  Future<void> open(
    WidgetTester tester,
    RecentSearch search, {
    bool habitsSearchShowing = false,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return TextButton(
              onPressed: () =>
                  openRecentSearch(ref, search, navService: navService),
              child: const Text('open'),
            );
          },
        ),
        overrides: overrides(habitsSearchShowing: habitsSearchShowing),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
  }
}

void main() {
  group('RecentSearchSurfaceRoute', () {
    test('every surface names the root of its own tab', () {
      expect(
        {
          for (final surface in RecentSearchSurface.values)
            surface: surface.rootPath,
        },
        {
          RecentSearchSurface.tasks: '/tasks',
          RecentSearchSurface.logbook: '/journal',
          RecentSearchSurface.projects: '/projects',
          RecentSearchSurface.habits: '/habits',
        },
      );
    });
  });

  group('openRecentSearch', () {
    testWidgets('a tasks search goes to the Tasks list and its controller', (
      tester,
    ) async {
      final bench = _Bench();
      await bench.open(
        tester,
        const RecentSearch(
          surface: RecentSearchSurface.tasks,
          query: 'fish feeder',
        ),
      );

      expect(bench.navService.navigationHistory, ['/tasks']);
      expect(bench.tasks.searchStringCalls, ['fish feeder']);
      expect(bench.logbook.searchStringCalls, isEmpty);
    });

    testWidgets('a logbook search goes to the Logbook and its controller', (
      tester,
    ) async {
      final bench = _Bench();
      await bench.open(
        tester,
        const RecentSearch(
          surface: RecentSearchSurface.logbook,
          query: 'ice pad',
        ),
      );

      expect(bench.navService.navigationHistory, ['/journal']);
      expect(bench.logbook.searchStringCalls, ['ice pad']);
      expect(bench.tasks.searchStringCalls, isEmpty);
    });

    testWidgets('a projects search sets the text query on the Projects '
        'filter', (tester) async {
      final bench = _Bench();
      await bench.open(
        tester,
        const RecentSearch(
          surface: RecentSearchSurface.projects,
          query: 'Waddle',
        ),
      );

      final filter = bench.container.read(projectsFilterControllerProvider);
      expect(bench.navService.navigationHistory, ['/projects']);
      expect(filter.textQuery, 'Waddle');
      expect(filter.searchMode, ProjectsSearchMode.localText);
    });

    testWidgets('a habits search opens the search bar it would otherwise '
        'hide behind', (tester) async {
      final bench = _Bench();
      await bench.open(
        tester,
        const RecentSearch(
          surface: RecentSearchSurface.habits,
          query: 'Run',
        ),
      );

      final state = bench.container.read(habitsControllerProvider);
      expect(bench.navService.navigationHistory, ['/habits']);
      expect(bench.habits.toggleShowSearchCalls, 1);
      expect(state.showSearch, isTrue);
      // Habits keeps its query lower-cased; that is its controller's rule.
      expect(state.searchString, 'run');
    });

    testWidgets('a habits search leaves an already open search bar open', (
      tester,
    ) async {
      final bench = _Bench();
      await bench.open(
        tester,
        const RecentSearch(
          surface: RecentSearchSurface.habits,
          query: 'run',
        ),
        habitsSearchShowing: true,
      );

      expect(bench.habits.toggleShowSearchCalls, 0);
      expect(bench.container.read(habitsControllerProvider).showSearch, isTrue);
    });

    testWidgets('records the reuse, so the search moves back to the top', (
      tester,
    ) async {
      final bench = _Bench();
      await bench.open(
        tester,
        const RecentSearch(
          surface: RecentSearchSurface.tasks,
          query: 'fish feeder',
        ),
      );

      expect(bench.recents.recorded, [
        (RecentSearchSurface.tasks, 'fish feeder'),
      ]);
    });
  });
}
