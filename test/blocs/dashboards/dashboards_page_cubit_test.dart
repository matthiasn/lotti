import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/blocs/dashboards/dashboards_page_cubit.dart';
import 'package:lotti/blocs/dashboards/dashboards_page_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks/mocks.dart';
import '../../test_data/sync_config_test_data.dart';
import '../../test_data/test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DashboardsPageCubit Tests - ', () {
    final mockJournalDb = MockJournalDb();

    setUpAll(() {
      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<LoggingDb>(LoggingDb(inMemoryDatabase: true));
    });
    tearDownAll(getIt.reset);

    blocTest<DashboardsPageCubit, DashboardsPageState>(
      'set dirty and save text entry',
      build: DashboardsPageCubit.new,
      setUp: () {
        when(mockJournalDb.watchDashboards).thenAnswer(
          (_) => Stream<List<DashboardDefinition>>.fromIterable([
            [
              testDashboardConfig,
              emptyTestDashboardConfig,
            ]
          ]),
        );
      },
      act: (c) async {
        c
          ..toggleShowSearch()
          ..setSearchString('foo')
          ..setSearchString('')
          ..toggleShowSearch();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        c.toggleSelectedCategoryIds(categoryMindfulness.id);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        c.toggleSelectedCategoryIds(categoryMindfulness.id);
      },
      wait: defaultWait,
      expect: () => <DashboardsPageState>[
        DashboardsPageState(
          allDashboards: [],
          filteredSortedDashboards: [],
          selectedCategoryIds: <String>{},
          showSearch: true,
          searchString: '',
        ),
        DashboardsPageState(
          allDashboards: [],
          filteredSortedDashboards: [],
          selectedCategoryIds: <String>{},
          showSearch: true,
          searchString: 'foo',
        ),
        DashboardsPageState(
          allDashboards: [],
          filteredSortedDashboards: [],
          selectedCategoryIds: <String>{},
          showSearch: true,
          searchString: '',
        ),
        DashboardsPageState(
          allDashboards: [],
          filteredSortedDashboards: [],
          selectedCategoryIds: <String>{},
          showSearch: false,
          searchString: '',
        ),
        DashboardsPageState(
          allDashboards: [
            testDashboardConfig,
            emptyTestDashboardConfig,
          ],
          filteredSortedDashboards: [
            testDashboardConfig,
            emptyTestDashboardConfig,
          ],
          selectedCategoryIds: <String>{},
          showSearch: false,
          searchString: '',
        ),
        DashboardsPageState(
          allDashboards: [
            testDashboardConfig,
            emptyTestDashboardConfig,
          ],
          filteredSortedDashboards: [
            testDashboardConfig,
          ],
          selectedCategoryIds: <String>{categoryMindfulness.id},
          showSearch: false,
          searchString: '',
        ),
        DashboardsPageState(
          allDashboards: [
            testDashboardConfig,
            emptyTestDashboardConfig,
          ],
          filteredSortedDashboards: [
            testDashboardConfig,
            emptyTestDashboardConfig,
          ],
          selectedCategoryIds: <String>{},
          showSearch: false,
          searchString: '',
        ),
      ],
      verify: (c) {},
    );
  });
}
