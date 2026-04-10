// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/model/task_progress_state.dart';
import 'package:lotti/features/tasks/state/task_live_data_provider.dart';
import 'package:lotti/features/tasks/state/task_one_liner_provider.dart';
import 'package:lotti/features/tasks/state/task_progress_controller.dart';
import 'package:lotti/features/tasks/ui/cover_art_thumbnail.dart';
import 'package:lotti/features/tasks/ui/model/task_browse_models.dart';
import 'package:lotti/features/tasks/ui/time_recording_icon.dart';
import 'package:lotti/features/tasks/ui/widgets/task_browse_list_item.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/entity_factories.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

// ---------------------------------------------------------------------------
// Fake task progress controller for provider override
// ---------------------------------------------------------------------------

class _FakeTaskProgressController extends TaskProgressController {
  _FakeTaskProgressController(this._fakeState);

  final TaskProgressState? _fakeState;

  @override
  Future<TaskProgressState?> build({required String id}) async {
    return _fakeState;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

TaskBrowseListItem _makeWidget(
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

void main() {
  late MockEntitiesCacheService mockEntitiesCacheService;

  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        mockEntitiesCacheService = MockEntitiesCacheService();
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
    mockEntitiesCacheService =
        getIt<EntitiesCacheService>() as MockEntitiesCacheService;
  });

  tearDown(() async {
    await tearDownTestGetIt();
  });

  // -------------------------------------------------------------------------
  // Section headers
  // -------------------------------------------------------------------------

  group('Section headers', () {
    testWidgets('renders priority section header with glyph and title', (
      tester,
    ) async {
      final task = TestTaskFactory.create(
        id: 'task-priority',
        title: 'Priority Task',
        dateFrom: DateTime(2026, 4, 8),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          _makeWidget(
            task,
            sectionKey: const TaskBrowseSectionKey.priority(
              TaskPriority.p1High,
            ),
            showSectionHeader: true,
          ),
        ),
      );
      await tester.pump();

      // The priority section header renders a TaskShowcasePriorityGlyph
      expect(find.byType(TaskShowcasePriorityGlyph), findsAtLeastNWidgets(1));
      // "P1 High" — the priority short code + localized label
      expect(find.textContaining('P1'), findsAtLeastNWidgets(1));
      expect(find.textContaining('High'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders dueToday section header', (tester) async {
      final task = TestTaskFactory.create(
        id: 'task-due-today',
        title: 'Due Today Task',
        dateFrom: DateTime(2026, 4, 8),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          _makeWidget(
            task,
            sectionKey: const TaskBrowseSectionKey.dueToday(),
            showSectionHeader: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Due Today'), findsOneWidget);
    });

    testWidgets('renders dueTomorrow section header', (tester) async {
      final task = TestTaskFactory.create(
        id: 'task-due-tomorrow',
        title: 'Due Tomorrow Task',
        dateFrom: DateTime(2026, 4, 8),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          _makeWidget(
            task,
            sectionKey: const TaskBrowseSectionKey.dueTomorrow(),
            showSectionHeader: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Due Tomorrow'), findsOneWidget);
    });

    testWidgets('renders dueYesterday section header', (tester) async {
      final task = TestTaskFactory.create(
        id: 'task-due-yesterday',
        title: 'Due Yesterday Task',
        dateFrom: DateTime(2026, 4, 8),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          _makeWidget(
            task,
            sectionKey: const TaskBrowseSectionKey.dueYesterday(),
            showSectionHeader: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Due Yesterday'), findsOneWidget);
    });

    testWidgets('renders createdDate section header', (tester) async {
      final task = TestTaskFactory.create(
        id: 'task-created-date',
        title: 'Created Date Task',
        dateFrom: DateTime(2026, 4, 8),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          _makeWidget(
            task,
            sectionKey: TaskBrowseSectionKey.createdDate(DateTime(2026, 4, 8)),
            showSectionHeader: true,
          ),
        ),
      );
      await tester.pump();

      // MaterialLocalizations.formatMediumDate(DateTime(2026, 4, 8)) → "Apr 8, 2026"
      expect(find.textContaining('Apr'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders dueDate section header', (tester) async {
      final task = TestTaskFactory.create(
        id: 'task-due-date',
        title: 'Specific Due Date Task',
        dateFrom: DateTime(2026, 4, 8),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          _makeWidget(
            task,
            sectionKey: TaskBrowseSectionKey.dueDate(DateTime(2026, 4, 15)),
            showSectionHeader: true,
          ),
        ),
      );
      await tester.pump();

      // "Due: Apr 15, 2026"
      expect(find.textContaining('Due:'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Apr 15'), findsAtLeastNWidgets(1));
    });

    testWidgets('renders noDueDate section header', (tester) async {
      final task = TestTaskFactory.create(
        id: 'task-no-due',
        title: 'No Due Date Task',
        dateFrom: DateTime(2026, 4, 8),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          _makeWidget(
            task,
            sectionKey: const TaskBrowseSectionKey.noDueDate(),
            showSectionHeader: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No due date'), findsOneWidget);
    });

    testWidgets('renders section count when provided', (tester) async {
      final task = TestTaskFactory.create(
        id: 'task-count',
        title: 'Count Task',
        dateFrom: DateTime(2026, 4, 8),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          TaskBrowseListItem(
            entry: TaskBrowseEntry(
              task: task,
              sectionKey: const TaskBrowseSectionKey.dueToday(),
              showSectionHeader: true,
              isFirstInSection: true,
              isLastInSection: true,
              sectionCount: 5,
            ),
            sortOption: TaskSortOption.byPriority,
            showCreationDate: false,
            showDueDate: false,
            showCoverArt: false,
            trackedDurationLabelOverride: '0h 0m',
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      // "5 tasks" via taskShowcaseTaskCount("{count} tasks")
      expect(find.text('5 tasks'), findsOneWidget);
    });

    testWidgets('renders titleOverride instead of computed section title', (
      tester,
    ) async {
      final task = TestTaskFactory.create(
        id: 'task-override',
        title: 'Override Title Task',
        dateFrom: DateTime(2026, 4, 8),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          _makeWidget(
            task,
            sectionKey: const TaskBrowseSectionKey.dueToday(),
            showSectionHeader: true,
            sectionHeaderTitleOverride: 'My Custom Header',
          ),
        ),
      );
      await tester.pump();

      expect(find.text('My Custom Header'), findsOneWidget);
      // "Due Today" should NOT appear since override takes precedence
      expect(find.text('Due Today'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // Footer chips
  // -------------------------------------------------------------------------

  group('Footer chips', () {
    testWidgets(
      'shows creation date chip when showCreationDate is true and sortOption is not byDate',
      (
        tester,
      ) async {
        final task = TestTaskFactory.create(
          id: 'task-creation-date',
          title: 'Task With Creation Date',
          dateFrom: DateTime(2026, 4, 8),
        );

        await tester.pumpWidget(
          makeTestableWidget(
            _makeWidget(
              task,
              sortOption: TaskSortOption.byPriority,
              showCreationDate: true,
            ),
          ),
        );
        await tester.pump();

        // TaskShowcaseMetaChip with calendar icon represents the creation date
        final chips = tester.widgetList<TaskShowcaseMetaChip>(
          find.byType(TaskShowcaseMetaChip),
        );
        final dateChips = chips
            .where((c) => c.icon == Icons.calendar_today_outlined)
            .toList();
        expect(dateChips, hasLength(1));
      },
    );

    testWidgets('hides creation date chip when sortOption is byDate', (
      tester,
    ) async {
      final task = TestTaskFactory.create(
        id: 'task-by-date',
        title: 'Task Sorted By Date',
        dateFrom: DateTime(2026, 4, 8),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          _makeWidget(
            task,
            sortOption: TaskSortOption.byDate,
            showCreationDate: true,
          ),
        ),
      );
      await tester.pump();

      final chips = tester.widgetList<TaskShowcaseMetaChip>(
        find.byType(TaskShowcaseMetaChip),
      );
      final dateChips = chips
          .where((c) => c.icon == Icons.calendar_today_outlined)
          .toList();
      expect(dateChips, isEmpty);
    });

    testWidgets(
      'shows due date chip when conditions are met (open task, showDueDate, byPriority sort)',
      (tester) async {
        final openStatus = TaskStatus.open(
          id: 'status-1',
          createdAt: DateTime(2024),
          utcOffset: 0,
        );
        final task =
            TestTaskFactory.create(
              id: 'task-due',
              title: 'Task With Due Date',
              dateFrom: DateTime(2026, 4, 8),
              status: openStatus,
            ).copyWith(
              data: TestTaskDataFactory.create(
                title: 'Task With Due Date',
                status: openStatus,
              ).copyWith(due: DateTime(2026, 4, 20)),
            );

        await tester.pumpWidget(
          makeTestableWidget(
            _makeWidget(
              task,
              sortOption: TaskSortOption.byPriority,
              showDueDate: true,
            ),
          ),
        );
        await tester.pump();

        // DueDateText is rendered as a widget in the footer
        expect(find.byIcon(Icons.event_rounded), findsAtLeastNWidgets(1));
      },
    );

    testWidgets('hides due date chip when task is done', (tester) async {
      final doneStatus = TaskStatus.done(
        id: 'status-done',
        createdAt: DateTime(2024),
        utcOffset: 0,
      );
      final task =
          TestTaskFactory.create(
            id: 'task-done',
            title: 'Done Task',
            dateFrom: DateTime(2026, 4, 8),
            status: doneStatus,
          ).copyWith(
            data: TestTaskDataFactory.create(
              title: 'Done Task',
              status: doneStatus,
            ).copyWith(due: DateTime(2026, 4, 20)),
          );

      await tester.pumpWidget(
        makeTestableWidget(
          _makeWidget(
            task,
            sortOption: TaskSortOption.byPriority,
            showDueDate: true,
          ),
        ),
      );
      await tester.pump();

      // DueDateText should NOT appear for done tasks
      expect(find.byIcon(Icons.event_rounded), findsNothing);
    });

    testWidgets('hides due date chip when task is rejected', (tester) async {
      final rejectedStatus = TaskStatus.rejected(
        id: 'status-rejected',
        createdAt: DateTime(2024),
        utcOffset: 0,
      );
      final task =
          TestTaskFactory.create(
            id: 'task-rejected',
            title: 'Rejected Task',
            dateFrom: DateTime(2026, 4, 8),
            status: rejectedStatus,
          ).copyWith(
            data: TestTaskDataFactory.create(
              title: 'Rejected Task',
              status: rejectedStatus,
            ).copyWith(due: DateTime(2026, 4, 20)),
          );

      await tester.pumpWidget(
        makeTestableWidget(
          _makeWidget(
            task,
            sortOption: TaskSortOption.byPriority,
            showDueDate: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.event_rounded), findsNothing);
    });

    testWidgets('hides due date chip when sortOption is byDueDate', (
      tester,
    ) async {
      final openStatus = TaskStatus.open(
        id: 'status-2',
        createdAt: DateTime(2024),
        utcOffset: 0,
      );
      final task =
          TestTaskFactory.create(
            id: 'task-by-due-date',
            title: 'Task With Due Date (byDueDate sort)',
            dateFrom: DateTime(2026, 4, 8),
            status: openStatus,
          ).copyWith(
            data: TestTaskDataFactory.create(
              title: 'Task With Due Date (byDueDate sort)',
              status: openStatus,
            ).copyWith(due: DateTime(2026, 4, 20)),
          );

      await tester.pumpWidget(
        makeTestableWidget(
          _makeWidget(
            task,
            sortOption: TaskSortOption.byDueDate,
            showDueDate: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.event_rounded), findsNothing);
    });

    testWidgets('shows vector distance chip when vectorDistance is provided', (
      tester,
    ) async {
      final task = TestTaskFactory.create(
        id: 'task-vector',
        title: 'Task With Vector Distance',
        dateFrom: DateTime(2026, 4, 8),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          _makeWidget(
            task,
            vectorDistance: 0.42,
          ),
        ),
      );
      await tester.pump();

      // TaskShowcaseMetaChip with hub icon for vector distance
      final chips = tester.widgetList<TaskShowcaseMetaChip>(
        find.byType(TaskShowcaseMetaChip),
      );
      final vectorChips = chips
          .where((c) => c.icon == Icons.hub_outlined)
          .toList();
      expect(vectorChips, hasLength(1));
      // The label is distance.toStringAsFixed(2) = "0.42"
      expect(vectorChips.first.label, '0.42');
    });

    testWidgets('hides vector distance chip when not provided', (tester) async {
      final task = TestTaskFactory.create(
        id: 'task-no-vector',
        title: 'Task Without Vector Distance',
        dateFrom: DateTime(2026, 4, 8),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          _makeWidget(
            task,
            vectorDistance: null,
          ),
        ),
      );
      await tester.pump();

      final chips = tester.widgetList<TaskShowcaseMetaChip>(
        find.byType(TaskShowcaseMetaChip),
      );
      final vectorChips = chips
          .where((c) => c.icon == Icons.hub_outlined)
          .toList();
      expect(vectorChips, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // Cover art
  // -------------------------------------------------------------------------

  group('Cover art', () {
    testWidgets(
      'renders CoverArtThumbnail when showCoverArt is true and task has coverArtId',
      (
        tester,
      ) async {
        const coverArtImageId = 'cover-img-1';
        final task =
            TestTaskFactory.create(
              id: 'task-cover-art',
              title: 'Task With Cover Art',
              dateFrom: DateTime(2026, 4, 8),
            ).copyWith(
              data: TestTaskDataFactory.create(
                title: 'Task With Cover Art',
              ).copyWith(coverArtId: coverArtImageId),
            );

        await tester.pumpWidget(
          makeTestableWidget(
            _makeWidget(
              task,
              showCoverArt: true,
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(CoverArtThumbnail), findsOneWidget);
        final thumbnail = tester.widget<CoverArtThumbnail>(
          find.byType(CoverArtThumbnail),
        );
        expect(thumbnail.imageId, coverArtImageId);
        expect(thumbnail.size, 72);
      },
    );

    testWidgets(
      'does not render CoverArtThumbnail when showCoverArt is false',
      (
        tester,
      ) async {
        final task =
            TestTaskFactory.create(
              id: 'task-no-cover-art',
              title: 'Task Without Cover Art Toggle',
              dateFrom: DateTime(2026, 4, 8),
            ).copyWith(
              data: TestTaskDataFactory.create(
                title: 'Task Without Cover Art Toggle',
              ).copyWith(coverArtId: 'some-image'),
            );

        await tester.pumpWidget(
          makeTestableWidget(
            _makeWidget(
              task,
              showCoverArt: false,
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(CoverArtThumbnail), findsNothing);
      },
    );

    testWidgets(
      'does not render CoverArtThumbnail when task has no coverArtId',
      (
        tester,
      ) async {
        final task = TestTaskFactory.create(
          id: 'task-null-cover-art',
          title: 'Task Null CoverArtId',
          dateFrom: DateTime(2026, 4, 8),
        );
        // task.data.coverArtId is null by default from TestTaskFactory

        await tester.pumpWidget(
          makeTestableWidget(
            _makeWidget(
              task,
              showCoverArt: true,
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(CoverArtThumbnail), findsNothing);
      },
    );
  });

  // -------------------------------------------------------------------------
  // Hover interaction
  // -------------------------------------------------------------------------

  group('Hover interaction', () {
    testWidgets('updates hoveredTaskIdNotifier on hover enter and leave', (
      tester,
    ) async {
      final hoveredNotifier = ValueNotifier<String?>(null);
      addTearDown(hoveredNotifier.dispose);

      final task = TestTaskFactory.create(
        id: 'task-hover',
        title: 'Hover Task',
        dateFrom: DateTime(2026, 4, 8),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          _makeWidget(
            task,
            hoveredTaskIdNotifier: hoveredNotifier,
          ),
        ),
      );
      await tester.pump();

      // Simulate hover enter
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      addTearDown(gesture.removePointer);
      await gesture.addPointer();

      final rowFinder = find.byKey(
        const ValueKey('task-browse-row-task-hover'),
      );
      expect(rowFinder, findsOneWidget);

      await gesture.moveTo(tester.getCenter(rowFinder));
      await tester.pump();

      expect(hoveredNotifier.value, 'task-hover');

      // Simulate hover leave by moving off the row to an area outside it.
      // Use the bottom-right corner of the screen (beyond row bounds).
      await gesture.moveTo(const Offset(2000, 2000));
      await tester.pump();

      expect(hoveredNotifier.value, isNull);
    });

    testWidgets(
      'does not attach hover listener when hoveredTaskIdNotifier is null',
      (
        tester,
      ) async {
        final task = TestTaskFactory.create(
          id: 'task-no-hover',
          title: 'No Hover Task',
          dateFrom: DateTime(2026, 4, 8),
        );

        // This should render without error and use the non-ValueListenableBuilder path
        await tester.pumpWidget(
          makeTestableWidget(
            _makeWidget(
              task,
              hoveredTaskIdNotifier: null,
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(TaskBrowseListItem), findsOneWidget);
      },
    );
  });

  // -------------------------------------------------------------------------
  // Live tracked duration provider path
  // -------------------------------------------------------------------------

  group('TrackedDurationMeta live provider path', () {
    testWidgets('shows tracked duration from live provider when no labelOverride', (
      tester,
    ) async {
      const taskId = 'task-live-duration';
      const testProgress = TaskProgressState(
        progress: Duration(hours: 2, minutes: 30),
        estimate: Duration(hours: 4),
      );

      final task = TestTaskFactory.create(
        id: taskId,
        title: 'Live Duration Task',
        dateFrom: DateTime(2026, 4, 8),
      );

      // Build without trackedDurationLabelOverride to exercise the live provider path
      final widget = TaskBrowseListItem(
        entry: TaskBrowseEntry(
          task: task,
          sectionKey: const TaskBrowseSectionKey.dueToday(),
          showSectionHeader: false,
          isFirstInSection: true,
          isLastInSection: true,
        ),
        sortOption: TaskSortOption.byPriority,
        showCreationDate: false,
        showDueDate: false,
        showCoverArt: false,
        onTap: () {},
        // No trackedDurationLabelOverride — provider is consulted
      );

      await tester.pumpWidget(
        makeTestableWidget(
          widget,
          overrides: [
            taskProgressControllerProvider(id: taskId).overrideWith(
              () => _FakeTaskProgressController(testProgress),
            ),
          ],
        ),
      );
      // First pump starts the widget; second pump lets the async provider resolve.
      await tester.pump();
      await tester.pump();

      // The provider returns 2h 30m; the widget formats it as "2h 30m"
      expect(find.text('2h 30m'), findsOneWidget);
    });

    testWidgets('shows zero duration label when provider returns null', (
      tester,
    ) async {
      const taskId = 'task-null-duration';

      final task = TestTaskFactory.create(
        id: taskId,
        title: 'Null Duration Task',
        dateFrom: DateTime(2026, 4, 8),
      );

      final widget = TaskBrowseListItem(
        entry: TaskBrowseEntry(
          task: task,
          sectionKey: const TaskBrowseSectionKey.dueToday(),
          showSectionHeader: false,
          isFirstInSection: true,
          isLastInSection: true,
        ),
        sortOption: TaskSortOption.byPriority,
        showCreationDate: false,
        showDueDate: false,
        showCoverArt: false,
        onTap: () {},
      );

      await tester.pumpWidget(
        makeTestableWidget(
          widget,
          overrides: [
            taskProgressControllerProvider(id: taskId).overrideWith(
              () => _FakeTaskProgressController(null),
            ),
          ],
        ),
      );
      // First pump starts the widget; second pump lets the async provider resolve.
      await tester.pump();
      await tester.pump();

      // null state → Duration.zero → "0h 0m"
      expect(find.text('0h 0m'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Live task data
  // -------------------------------------------------------------------------

  group('Live task data', () {
    testWidgets('renders updated title from taskLiveDataProvider', (
      tester,
    ) async {
      const taskId = 'task-live';
      final originalTask = TestTaskFactory.create(
        id: taskId,
        title: 'Original Title',
        dateFrom: DateTime(2026, 4, 8),
      );
      final updatedTask = TestTaskFactory.create(
        id: taskId,
        title: 'Updated Title',
        dateFrom: DateTime(2026, 4, 8),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          _makeWidget(originalTask),
          overrides: [
            taskLiveDataProvider.overrideWith(
              (ref, id) => Future.value(updatedTask),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      // The live provider returned an updated task, so the title should reflect
      // the live data, not the snapshot.
      expect(find.text('Updated Title'), findsOneWidget);
      expect(find.text('Original Title'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // One-liner subtitle
  // -------------------------------------------------------------------------

  group('One-liner subtitle', () {
    testWidgets('renders one-liner text from taskOneLinerProvider', (
      tester,
    ) async {
      final task = TestTaskFactory.create(
        id: 'task-oneliner',
        title: 'Task With Summary',
        dateFrom: DateTime(2026, 4, 8),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          _makeWidget(task),
          overrides: [
            taskOneLinerProvider.overrideWith(
              (ref, id) => Future.value('Implementing OAuth2 flow'),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Task With Summary'), findsOneWidget);
      expect(find.text('Implementing OAuth2 flow'), findsOneWidget);
    });

    testWidgets('does not render one-liner when provider returns null', (
      tester,
    ) async {
      final task = TestTaskFactory.create(
        id: 'task-no-oneliner',
        title: 'Task Without Summary',
        dateFrom: DateTime(2026, 4, 8),
      );

      await tester.pumpWidget(
        makeTestableWidget(
          _makeWidget(task),
          overrides: [
            taskOneLinerProvider.overrideWith(
              (ref, id) => Future.value(null),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Task Without Summary'), findsOneWidget);
      // Only the title Text widget should exist for the task content text;
      // no additional caption-styled Text for a one-liner.
      final textWidgets = tester.widgetList<Text>(
        find.descendant(
          of: find.byType(TaskBrowseListItem),
          matching: find.byType(Text),
        ),
      );
      expect(
        textWidgets.where((t) => t.data == 'Implementing OAuth2 flow'),
        isEmpty,
      );
    });
  });

  // -------------------------------------------------------------------------
  // Time recording indicator
  // -------------------------------------------------------------------------

  group('Time recording indicator', () {
    testWidgets('shows recording dot when task is actively recording', (
      tester,
    ) async {
      const taskId = 'task-recording';
      final task = TestTaskFactory.create(
        id: taskId,
        title: 'Recording Task',
        dateFrom: DateTime(2026, 4, 8),
      );

      // Override the TimeService mock to simulate active recording for this task.
      final mockTimeService = getIt<TimeService>() as MockTimeService;
      final recordingEntry = TestTaskFactory.create(
        id: taskId,
        title: 'Recording Task',
        dateFrom: DateTime(2026, 4, 8),
      );
      when(() => mockTimeService.linkedFrom).thenReturn(recordingEntry);
      when(mockTimeService.getStream).thenAnswer(
        (_) => Stream.value(recordingEntry),
      );

      await tester.pumpWidget(
        makeTestableWidget(_makeWidget(task)),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(TimeRecordingIcon), findsOneWidget);
      // The ColorIcon (red dot) should be visible when recording.
      expect(
        find.descendant(
          of: find.byType(TimeRecordingIcon),
          matching: find.byType(ColorIcon),
        ),
        findsOneWidget,
      );
    });

    testWidgets('hides recording dot when task is not recording', (
      tester,
    ) async {
      final task = TestTaskFactory.create(
        id: 'task-not-recording',
        title: 'Not Recording Task',
        dateFrom: DateTime(2026, 4, 8),
      );

      await tester.pumpWidget(
        makeTestableWidget(_makeWidget(task)),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(TimeRecordingIcon), findsOneWidget);
      // The ColorIcon should NOT be rendered (SizedBox.shrink instead).
      expect(
        find.descendant(
          of: find.byType(TimeRecordingIcon),
          matching: find.byType(ColorIcon),
        ),
        findsNothing,
      );
    });
  });
}
