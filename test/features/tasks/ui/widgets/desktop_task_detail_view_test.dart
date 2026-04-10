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

  Future<void> setDesktopSize(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
  }

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

    testWidgets('renders SizedBox.shrink on provider error', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const DesktopTaskDetailView(taskId: 'error-task'),
          overrides: [
            taskDetailRecordProvider('error-task').overrideWith(
              (ref) async {
                throw StateError('test error');
              },
            ),
          ],
        ),
      );
      // Pump multiple times to let the async error propagate through Riverpod
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }

      expect(find.byType(TaskDetailPane), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('header rendering', () {
    testWidgets('displays title, priority, project, category, and labels', (
      tester,
    ) async {
      await setDesktopSize(tester);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildSubject(taskId: 'pay', record: paymentTask),
      );
      await tester.pump();

      expect(find.text('Payment confirmation'), findsOneWidget);
      expect(find.text(paymentTask.task.data.priority.short), findsOneWidget);
      expect(find.text(paymentTask.projectTitle), findsOneWidget);
      expect(find.text(paymentTask.category.name), findsAtLeastNWidgets(1));
      for (final label in paymentTask.labels) {
        expect(find.text(label.label), findsOneWidget);
      }
    });
  });

  group('detail card sections', () {
    testWidgets('renders all detail sections with correct content', (
      tester,
    ) async {
      await setDesktopSize(tester);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        buildSubject(taskId: 'pay', record: paymentTask),
      );
      await tester.pump();

      // AI Summary
      expect(find.text('AI Task Summary'), findsOneWidget);
      expect(find.text(paymentTask.aiSummary), findsOneWidget);

      // Time Tracker
      expect(find.text('Time Tracker'), findsOneWidget);
      expect(find.text(paymentTask.trackedDurationLabel), findsOneWidget);

      // Todos
      expect(find.text('Todos'), findsOneWidget);
      for (final item in paymentTask.checklistItems) {
        expect(find.text(item.title), findsOneWidget);
      }

      // Audio
      expect(find.text('Audio Recordings'), findsOneWidget);
      for (final entry in paymentTask.audioEntries) {
        expect(find.text(entry.title), findsOneWidget);
      }
    });
  });

  group('section navigation', () {
    testWidgets('renders jump-to-section sidebar on wide layout', (
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
  });
}
