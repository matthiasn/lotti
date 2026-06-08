
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/features/tasks/ui/model/task_browse_models.dart';
import 'package:lotti/features/tasks/ui/widgets/task_browse_list_item.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

class FakeTaskProgressController extends TaskProgressController {
  FakeTaskProgressController(this._fakeState);

  final TaskProgressState? _fakeState;

  @override
  Future<TaskProgressState?> build({required String id}) async {
    return _fakeState;
  }
}

/// Registers the shared GetIt mocks every task-browse-list-item test needs.
Future<void> setUpTaskBrowse() async {
  await setUpTestGetIt(
    additionalSetup: () {
      final mockEntitiesCacheService = MockEntitiesCacheService();
      when(
        () => mockEntitiesCacheService.getCategoryById(any()),
      ).thenReturn(null);
      getIt.registerSingleton<EntitiesCacheService>(mockEntitiesCacheService);

      // TimeService is accessed synchronously by TaskProgressController's
      // field initializer, so it must be registered even for overridden tests.
      final mockTimeService = MockTimeService();
      when(mockTimeService.getStream).thenAnswer((_) => const Stream.empty());
      when(() => mockTimeService.linkedFrom).thenReturn(null);
      getIt.registerSingleton<TimeService>(mockTimeService);
    },
  );
}

/// Pumps a [TaskBrowseListItem] built via [makeTaskBrowseWidget] and settles the
/// first frame — the shared shape of nearly every test in this file.
Future<void> pumpTaskBrowseItem(
  WidgetTester tester,
  Task task, {
  TaskBrowseSectionKey? sectionKey,
  bool showSectionHeader = false,
  int? sectionCount,
  TaskSortOption sortOption = TaskSortOption.byPriority,
  bool showCreationDate = false,
  bool showDueDate = false,
  bool showCoverArt = false,
  double? vectorDistance,
  String? trackedDurationLabelOverride = '0h 0m',
  String? sectionHeaderTitleOverride,
  ValueNotifier<String?>? hoveredTaskIdNotifier,
  List<Override> overrides = const [],
}) async {
  await tester.pumpWidget(
    makeTestableWidget(
      makeTaskBrowseWidget(
        task,
        sectionKey: sectionKey,
        showSectionHeader: showSectionHeader,
        sectionCount: sectionCount,
        sortOption: sortOption,
        showCreationDate: showCreationDate,
        showDueDate: showDueDate,
        showCoverArt: showCoverArt,
        vectorDistance: vectorDistance,
        trackedDurationLabelOverride: trackedDurationLabelOverride,
        sectionHeaderTitleOverride: sectionHeaderTitleOverride,
        hoveredTaskIdNotifier: hoveredTaskIdNotifier,
      ),
      overrides: overrides,
    ),
  );
  await tester.pump();
}

TaskBrowseListItem makeTaskBrowseWidget(
  Task task, {
  TaskBrowseSectionKey? sectionKey,
  bool showSectionHeader = false,
  int? sectionCount,
  TaskSortOption sortOption = TaskSortOption.byPriority,
  bool showCreationDate = false,
  bool showDueDate = false,
  bool showCoverArt = false,
  double? vectorDistance,
  String? trackedDurationLabelOverride = '0h 0m',
  String? sectionHeaderTitleOverride,
  ValueNotifier<String?>? hoveredTaskIdNotifier,
}) {
  return TaskBrowseListItem(
    entry: TaskBrowseEntry(
      task: task,
      sectionKey: sectionKey ?? const TaskBrowseSectionKey.dueToday(),
      showSectionHeader: showSectionHeader,
      isFirstInSection: true,
      isLastInSection: true,
      sectionCount: sectionCount,
    ),
    sortOption: sortOption,
    showCreationDate: showCreationDate,
    showDueDate: showDueDate,
    showCoverArt: showCoverArt,
    vectorDistance: vectorDistance,
    trackedDurationLabelOverride: trackedDurationLabelOverride,
    sectionHeaderTitleOverride: sectionHeaderTitleOverride,
    hoveredTaskIdNotifier: hoveredTaskIdNotifier,
    onTap: () {},
  );
}
