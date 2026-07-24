import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/conversions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/fts5_db.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/features/tasks/state/task_link_groups_controller.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header_connector.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/blocking_task_picker_modal.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/link_task_modal.dart';
import 'package:lotti/features/tasks/ui/linked_tasks/linked_tasks_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/entity_factories.dart';
import 'helpers/fake_entry_controller.dart';
import 'mocks/mocks.dart';
import 'test_utils/screenshot_harness.dart';
import 'widget_test_utils.dart';

class _FakeTaskLinkGroupsController extends TaskLinkGroupsController {
  _FakeTaskLinkGroupsController(this._groups);
  final TaskLinkGroups _groups;

  @override
  Future<TaskLinkGroups> build() async => _groups;
}

void main() {
  setUpAll(loadAppFonts);

  final now = DateTime(2026, 5, 4, 9);
  const mainTaskId = 'task-orbital-habitat';

  Task buildTask({
    required String id,
    required String title,
    TaskStatus? status,
  }) => TestTaskFactory.create(
    id: id,
    title: title,
    status: status,
    createdAt: now,
    dateFrom: now,
    dateTo: now,
  );

  final blockerTask = buildTask(
    id: 'task-feeder-calibration',
    title: 'Calibrate zero-gravity sardine feeder',
    status: TaskStatus.inProgress(id: 's1', createdAt: now, utcOffset: 0),
  );
  final followUpTask = buildTask(
    id: 'task-crew-rotation',
    title: 'Draft crew rotation schedule for habitat watch',
    status: TaskStatus.open(id: 's2', createdAt: now, utcOffset: 0),
  );
  final flatLinkedTask = buildTask(
    id: 'task-pressure-log',
    title: 'Habitat pressure readings — week 12',
    status: TaskStatus.open(id: 's3', createdAt: now, utcOffset: 0),
  );
  final mainTask = buildTask(
    id: mainTaskId,
    title: 'Confirm interplanetary sardine cargo pods',
    status: TaskStatus.blocked(
      id: 's4',
      createdAt: now,
      utcOffset: 0,
      reason: 'Feeder calibration incomplete',
    ),
  );

  late MockJournalDb mockJournalDb;
  late MockFts5Db mockFts5Db;
  late MockPersistenceLogic mockPersistenceLogic;
  late MockEntitiesCacheService mockCache;
  late MockNavService mockNavService;

  setUp(() async {
    mockFts5Db = MockFts5Db();
    mockPersistenceLogic = MockPersistenceLogic();
    mockCache = MockEntitiesCacheService();
    mockNavService = MockNavService();

    when(
      () => mockFts5Db.watchFullTextMatches(any()),
    ).thenAnswer((_) => Stream.value(<String>[]));
    when(() => mockCache.showPrivateEntries).thenReturn(true);
    when(() => mockCache.getCategoryById(any())).thenReturn(null);
    when(() => mockCache.getLabelById(any())).thenReturn(null);
    when(
      () => mockCache.sortedCategories,
    ).thenReturn(const <CategoryDefinition>[]);
    when(() => mockCache.sortedLabels).thenReturn(const <LabelDefinition>[]);
    when(
      () => mockCache.filterLabelsForCategory(any(), any()),
    ).thenAnswer(
      (invocation) =>
          invocation.positionalArguments.first as List<LabelDefinition>,
    );

    final mocks = await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..registerSingleton<Fts5Db>(mockFts5Db)
          ..registerSingleton<PersistenceLogic>(mockPersistenceLogic)
          ..registerSingleton<EntitiesCacheService>(mockCache)
          ..registerSingleton<NavService>(mockNavService)
          ..registerSingleton<TimeService>(MockTimeService())
          ..registerSingleton<EditorStateService>(MockEditorStateService());
      },
    );
    mockJournalDb = mocks.journalDb;

    when(
      () => mockJournalDb.getTasks(
        starredStatuses: any(named: 'starredStatuses'),
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: any(named: 'categoryIds'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => [blockerTask, followUpTask, flatLinkedTask],
    );
    when(
      () =>
          mockJournalDb.typedLinksForTaskIds(any(), types: any(named: 'types')),
    ).thenAnswer((_) async => <EntryLink>[]);
    when(
      () => mockJournalDb.getJournalEntitiesForIdsUnordered(any()),
    ).thenAnswer((_) async => <JournalEntity>[]);
  });

  tearDown(tearDownTestGetIt);

  for (final viewport in [
    ScreenshotViewport.phone,
    ScreenshotViewport.desktop,
  ]) {
    final label = viewport == ScreenshotViewport.phone ? 'phone' : 'desktop';

    testWidgets('link task modal — $label', (tester) async {
      await captureInApp(
        tester,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Confirm interplanetary sardine cargo pods'),
          ),
          body: const SizedBox.shrink(),
        ),
        name: 'link_task_modal_$label',
        size: viewport,
        interaction: (tester) async {
          final context = tester.element(find.byType(Scaffold).first);
          unawaited(
            LinkTaskModal.show(
              context: context,
              currentTaskId: mainTaskId,
              existingRelations: const {},
            ),
          );
          await tester.pumpAndSettle();
          // Open the directed-relation dropdown and pick "Blocks" so the
          // capture shows the expanded option list.
          await tester.tap(find.text('Relates to'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Blocks').last);
        },
      );
    });

    testWidgets('linked tasks widget — $label', (tester) async {
      final groups = TaskLinkGroups(
        flat: [
          TaskLinkEntry(
            linkId: 'link-flat-1',
            task: flatLinkedTask,
            kind: TaskLinkKind.basic,
            direction: TaskLinkDirection.outgoing,
          ),
        ],
        typed: [
          TaskLinkEntry(
            linkId: 'link-blocks-1',
            task: blockerTask,
            kind: TaskLinkKind.blocks,
            direction: TaskLinkDirection.incoming,
          ),
          TaskLinkEntry(
            linkId: 'link-followup-1',
            task: followUpTask,
            kind: TaskLinkKind.followsUp,
            direction: TaskLinkDirection.outgoing,
          ),
        ],
      );

      await captureInApp(
        tester,
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: kDetailContentMaxWidth,
                ),
                child: LinkedTasksWidget(taskId: mainTaskId),
              ),
            ),
          ),
        ),
        name: 'linked_tasks_widget_$label',
        size: viewport,
        overrides: [
          taskLinkGroupsControllerProvider(
            mainTaskId,
          ).overrideWith(() => _FakeTaskLinkGroupsController(groups)),
        ],
      );
    });

    testWidgets('linked tasks widget empty — $label', (tester) async {
      await captureInApp(
        tester,
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: kDetailContentMaxWidth,
                ),
                child: LinkedTasksWidget(taskId: mainTaskId),
              ),
            ),
          ),
        ),
        name: 'linked_tasks_widget_empty_$label',
        size: viewport,
        overrides: [
          taskLinkGroupsControllerProvider(mainTaskId).overrideWith(
            () => _FakeTaskLinkGroupsController(TaskLinkGroups.empty),
          ),
        ],
      );
    });

    testWidgets('header blocked-by chip — $label', (tester) async {
      when(
        () => mockJournalDb.typedLinksForTaskIds(
          {mainTaskId},
          types: {'BlocksLink'},
        ),
      ).thenAnswer(
        (_) async => [
          EntryLink.blocks(
            id: 'link-blocks-1',
            fromId: blockerTask.meta.id,
            toId: mainTaskId,
            createdAt: now,
            updatedAt: now,
            vectorClock: null,
          ),
        ],
      );
      when(
        () => mockJournalDb.entriesForIds([blockerTask.meta.id]),
      ).thenReturn(MockSelectable([toDbEntity(blockerTask)]));

      await captureInApp(
        tester,
        child: Scaffold(body: DesktopTaskHeaderConnector(taskId: mainTaskId)),
        name: 'header_blocked_by_chip_$label',
        size: viewport,
        overrides: [
          createEntryControllerOverride(mainTask),
          labelsStreamProvider.overrideWith(
            (ref) => Stream<List<LabelDefinition>>.value(const []),
          ),
          projectForTaskProvider(mainTaskId).overrideWith((ref) async => null),
          taskProgressControllerProvider(
            mainTaskId,
          ).overrideWith(() => _FakeTaskProgressController()),
        ],
      );
    });

    testWidgets('blocking task picker modal — $label', (tester) async {
      await captureInApp(
        tester,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Confirm interplanetary sardine cargo pods'),
          ),
          body: const SizedBox.shrink(),
        ),
        name: 'blocking_task_picker_modal_$label',
        size: viewport,
        interaction: (tester) async {
          final context = tester.element(find.byType(Scaffold).first);
          unawaited(
            BlockingTaskPickerModal.show(
              context: context,
              blockedTaskId: mainTaskId,
            ),
          );
          await tester.pumpAndSettle();
        },
      );
    });
  }
}

class _FakeTaskProgressController extends TaskProgressController {
  @override
  Future<TaskProgressState?> build() async => null;
}
