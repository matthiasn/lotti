import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/ai/repository/vector_search_repository.dart';
import 'package:lotti/features/journal/state/journal_filter_persistence.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/utils/entry_type_gating.dart';
import 'package:lotti/features/journal/utils/entry_types.dart';
import 'package:lotti/features/lockdown/state/lockdown_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import 'helpers/journal_controller_test_setup.dart';

part 'journal_page_controller_cases/lifecycle_and_search.dart';
part 'journal_page_controller_cases/flags_and_agent_queries.dart';
part 'journal_page_controller_cases/project_queries_and_batches.dart';
part 'journal_page_controller_cases/pagination_and_telemetry.dart';
part 'journal_page_controller_cases/refresh_triggers.dart';
part 'journal_page_controller_cases/refresh_scheduling.dart';
part 'journal_page_controller_cases/visibility_edges.dart';
part 'journal_page_controller_cases/filter_selection.dart';
part 'journal_page_controller_cases/project_selection.dart';
part 'journal_page_controller_cases/lockdown.dart';

final _testDate = DateTime(2024);
final _testDateRefresh = DateTime(2024, 3, 15);

/// Mutable call counter returned by `stubCountingQuery`.
class _QueryCallCounter {
  int count = 0;
}

void _emitVisibility(
  JournalControllerTestSetup setup,
  JournalPageController controller, {
  required bool isVisible,
}) {
  final visibleIndex = controller.state.showTasks
      ? testTasksIndex
      : testJournalIndex;
  setup.emitNavIndex(isVisible ? visibleIndex : testOtherIndex);
}

/// Stubs the full 8-param getJournalEntities query on [db] with [result]
/// and returns a counter incremented on every run — the shared arrangement
/// for the visibility/notification refresh tests.
// ignore: library_private_types_in_public_api
_QueryCallCounter stubCountingQuery(
  MockJournalDb db, {
  List<JournalEntity> result = const [],
}) {
  final counter = _QueryCallCounter();
  when(
    () => db.getJournalEntities(
      types: any(named: 'types'),
      starredStatuses: any(named: 'starredStatuses'),
      privateStatuses: any(named: 'privateStatuses'),
      flaggedStatuses: any(named: 'flaggedStatuses'),
      ids: any(named: 'ids'),
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
      categoryIds: any(named: 'categoryIds'),
    ),
  ).thenAnswer((_) async {
    counter.count++;
    return result;
  });
  return counter;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JournalPageController Tests', () {
    final setup = JournalControllerTestSetup();
    setUp(setup.setUp);
    tearDown(setup.tearDown);
    _registerLifecycleAndSearch(setup);
    _registerFlagsAndAgentQueries(setup);
    _registerProjectQueriesAndBatches(setup);
    _registerPaginationAndTelemetry(setup);
  });

  group('JournalPageController Refresh Tests', () {
    final setup = JournalControllerTestSetup();
    setUp(setup.setUp);
    tearDown(setup.tearDown);
    _registerRefreshTriggers(setup);
    _registerRefreshScheduling(setup);
    _registerVisibilityEdges(setup);
  });

  group('JournalPageController Filter Tests', () {
    final setup = JournalControllerTestSetup();
    setUp(setup.setUp);
    tearDown(setup.tearDown);
    _registerFilterSelection(setup);
    _registerProjectSelection(setup);
  });

  group('JournalPageController lockdown', () {
    final setup = JournalControllerTestSetup();
    setUp(setup.setUp);
    tearDown(setup.tearDown);
    _registerLockdown(setup);
  });
}

Task _buildTestTaskRefresh({
  required String id,
  required String title,
  required DateTime createdAt,
  DateTime? updatedAt,
  TaskPriority priority = TaskPriority.p2Medium,
}) {
  return Task(
    data: TaskData(
      status: TaskStatus.open(
        id: 'status-$id',
        createdAt: createdAt,
        utcOffset: 0,
      ),
      dateFrom: createdAt,
      dateTo: createdAt,
      statusHistory: const [],
      title: title,
      priority: priority,
    ),
    meta: Metadata(
      id: id,
      createdAt: createdAt,
      dateFrom: createdAt,
      dateTo: createdAt,
      updatedAt: updatedAt ?? createdAt,
    ),
  );
}
