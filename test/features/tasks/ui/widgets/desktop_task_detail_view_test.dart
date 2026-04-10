import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/state/task_detail_record_provider.dart';
import 'package:lotti/features/tasks/ui/model/task_list_detail_models.dart';
import 'package:lotti/features/tasks/ui/widgets/desktop_task_detail_view.dart';
import 'package:lotti/features/tasks/ui/widgets/task_detail_pane.dart';
import 'package:lotti/features/tasks/widgetbook/task_list_detail_mock_data.dart';

import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TaskListData mockData;
  late TaskRecord paymentTask;

  setUp(() async {
    await setUpTestGetIt();
    mockData = buildTaskListDetailMockData();
    paymentTask = mockData.tasks.firstWhere(
      (r) => r.task.data.title == 'Payment confirmation',
    );
  });

  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    required String taskId,
    required TaskRecord? record,
    Size size = const Size(800, 900),
  }) {
    return makeTestableWidget(
      DesktopTaskDetailView(taskId: taskId),
      mediaQueryData: MediaQueryData(size: size),
      overrides: [
        taskDetailRecordProvider(taskId).overrideWith(
          (ref) async => record,
        ),
      ],
    );
  }

  group('loading & error states', () {
    testWidgets('shows CircularProgressIndicator while loading', (
      tester,
    ) async {
      final completer = Completer<TaskRecord?>();

      await tester.pumpWidget(
        makeTestableWidget(
          const DesktopTaskDetailView(taskId: 'loading-task'),
          overrides: [
            taskDetailRecordProvider('loading-task').overrideWith(
              (ref) => completer.future,
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(TaskDetailPane), findsNothing);

      completer.complete(null);
      await tester.pump();
    });

    testWidgets('renders SizedBox.shrink when record resolves to null', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(taskId: 'null-task', record: null));
      await tester.pump();

      expect(find.byType(TaskDetailPane), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('header rendering', () {
    testWidgets('displays task title from record', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildSubject(taskId: 'pay', record: paymentTask),
      );
      await tester.pump();

      expect(find.text('Payment confirmation'), findsOneWidget);
    });

    testWidgets('displays priority label from record', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildSubject(taskId: 'pay', record: paymentTask),
      );
      await tester.pump();

      // Priority short label (e.g. P1)
      expect(
        find.text(paymentTask.task.data.priority.short),
        findsOneWidget,
      );
    });

    testWidgets('displays project title from record', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildSubject(taskId: 'pay', record: paymentTask),
      );
      await tester.pump();

      expect(find.text(paymentTask.projectTitle), findsOneWidget);
    });

    testWidgets('displays category chip from record', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildSubject(taskId: 'pay', record: paymentTask),
      );
      await tester.pump();

      expect(find.text(paymentTask.category.name), findsAtLeastNWidgets(1));
    });

    testWidgets('displays label chips from record', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildSubject(taskId: 'pay', record: paymentTask),
      );
      await tester.pump();

      for (final label in paymentTask.labels) {
        expect(find.text(label.label), findsOneWidget);
      }
    });
  });

  group('detail card sections', () {
    testWidgets('renders AI Task Summary section', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildSubject(taskId: 'pay', record: paymentTask),
      );
      await tester.pump();

      expect(find.text('AI Task Summary'), findsOneWidget);
      // Verify the actual AI summary text is rendered
      expect(find.text(paymentTask.aiSummary), findsOneWidget);
    });

    testWidgets('renders Time Tracker section with duration', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildSubject(taskId: 'pay', record: paymentTask),
      );
      await tester.pump();

      expect(find.text('Time Tracker'), findsOneWidget);
      expect(
        find.text(paymentTask.trackedDurationLabel),
        findsOneWidget,
      );
    });

    testWidgets('renders Todos section with completion count', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildSubject(taskId: 'pay', record: paymentTask),
      );
      await tester.pump();

      expect(find.text('Todos'), findsOneWidget);
      // Verify checklist item titles are displayed
      for (final item in paymentTask.checklistItems) {
        expect(find.text(item.title), findsOneWidget);
      }
    });

    testWidgets('renders Audio Recordings section with entries', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildSubject(taskId: 'pay', record: paymentTask),
      );
      await tester.pump();

      expect(find.text('Audio Recordings'), findsOneWidget);
      // Verify audio entry titles are displayed
      for (final entry in paymentTask.audioEntries) {
        expect(find.text(entry.title), findsOneWidget);
      }
    });
  });

  group('section navigation pills', () {
    testWidgets('renders jump-to-section pills on wide layout', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(900, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildSubject(
          taskId: 'pay',
          record: paymentTask,
          size: const Size(900, 900),
        ),
      );
      await tester.pump();

      // The "Jump to section" label appears on desktop (>=720px)
      expect(find.text('Jump to section'), findsOneWidget);
    });
  });

  group('widget identity', () {
    testWidgets('uses ValueKey matching taskId', (tester) async {
      await tester.pumpWidget(
        buildSubject(taskId: 'task-42', record: paymentTask),
      );
      await tester.pump();

      final pane = tester.widget<TaskDetailPane>(find.byType(TaskDetailPane));
      expect(pane.key, const ValueKey<String>('task-42'));
    });

    testWidgets('renders TaskDetailPane as child', (tester) async {
      await tester.pumpWidget(
        buildSubject(taskId: 'task-x', record: mockData.tasks.first),
      );
      await tester.pump();

      expect(find.byType(TaskDetailPane), findsOneWidget);
    });
  });
}
