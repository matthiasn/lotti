// ignore_for_file: avoid_redundant_argument_values

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/entity_factories.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import 'task_browse_list_item_test_helpers.dart';

void main() {
  setUp(setUpTaskBrowse);
  tearDown(tearDownTestGetIt);

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

        await pumpTaskBrowseItem(tester, task, showCoverArt: true);

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

        await pumpTaskBrowseItem(tester, task, showCoverArt: false);

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

        await pumpTaskBrowseItem(tester, task, showCoverArt: true);

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

      await pumpTaskBrowseItem(
        tester,
        task,
        hoveredTaskIdNotifier: hoveredNotifier,
      );

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
        await pumpTaskBrowseItem(tester, task, hoveredTaskIdNotifier: null);

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
            taskProgressControllerProvider(taskId).overrideWith(
              () => FakeTaskProgressController(testProgress),
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
            taskProgressControllerProvider(taskId).overrideWith(
              () => FakeTaskProgressController(null),
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
          makeTaskBrowseWidget(originalTask),
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

    testWidgets(
      'renders localized "(untitled)" warning in red when title is empty',
      (tester) async {
        final task = TestTaskFactory.create(
          id: 'task-empty-title',
          title: '',
          dateFrom: DateTime(2026, 4, 8),
        );

        await pumpTaskBrowseItem(tester, task);

        final finder = find.text('(untitled)');
        expect(finder, findsOneWidget);

        final textWidget = tester.widget<Text>(finder);
        final style = textWidget.style!;
        expect(style.fontStyle, FontStyle.italic);
        // Warning color comes from the design-system error token, not from
        // colorScheme. Assert the same resolution the widget uses.
        final element = tester.element(finder);
        expect(style.color, TaskShowcasePalette.error(element));
      },
    );
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
          makeTaskBrowseWidget(task),
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
          makeTaskBrowseWidget(task),
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

      await pumpTaskBrowseItem(tester, task);
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

      await pumpTaskBrowseItem(tester, task);
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
