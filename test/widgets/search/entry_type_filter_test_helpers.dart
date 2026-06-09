// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/widgets/search/entry_type_filter.dart';

import '../../mocks/mocks.dart';
import '../../test_utils/fake_journal_page_controller.dart';
import '../../widget_test_utils.dart';

/// Default state for config-flag tests where no call tracking is needed.
const hDefaultState = JournalPageState(
  selectedEntryTypes: [],
  match: '',
  filters: {},
  showPrivateEntries: true,
  showTasks: false,
  fullTextMatches: {},
  pagingController: null,
  taskStatuses: [],
  selectedTaskStatuses: {},
  selectedCategoryIds: {},
  selectedLabelIds: {},
);

/// Mounts [EntryTypeFilter] with the shared GetIt registration and the
/// 3-provider override block that every test in this file needs.
///
/// [controllerFactory] defaults to a tracking-free fake; pass a closure
/// returning a shared [FakeJournalPageController] for interaction tests.
/// [pumpAfterMount] pumps one frame after mounting (disable for tests that
/// assert on the pre-first-event loading state).
Future<void> hPumpFilter(
  WidgetTester tester,
  MockJournalDb mockDb, {
  JournalPageController Function()? controllerFactory,
  bool pumpAfterMount = true,
}) async {
  if (GetIt.I.isRegistered<JournalDb>()) {
    GetIt.I.unregister<JournalDb>();
  }
  GetIt.I.registerSingleton<JournalDb>(mockDb);
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      const EntryTypeFilter(),
      overrides: [
        journalDbProvider.overrideWithValue(mockDb),
        journalPageScopeProvider.overrideWithValue(false),
        journalPageControllerProvider(false).overrideWith(
          controllerFactory ?? () => FakeJournalPageController(hDefaultState),
        ),
      ],
    ),
  );
  if (pumpAfterMount) {
    await tester.pump();
  }
}
