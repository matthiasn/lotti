import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/ui/header/estimated_time_widget.dart';
import 'package:lotti/features/tasks/ui/time_recording_icon.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_helper.dart';

class MockTimeService extends Mock implements TimeService {}

void main() {
  late Task testTask;
  late MockTimeService mockTimeService;

  setUp(() {
    mockTimeService = MockTimeService();
    getIt.registerSingleton<TimeService>(mockTimeService);

    when(() => mockTimeService.getStream())
        .thenAnswer((_) => Stream<JournalEntity?>.fromIterable([]));
    when(() => mockTimeService.linkedFrom).thenReturn(null);

    testTask = Task(
      meta: Metadata(
        id: 'test-task-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: 'test-status-id',
          createdAt: DateTime.now(),
          utcOffset: 0,
        ),
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
        statusHistory: [],
        title: 'Test Task',
        estimate: const Duration(hours: 2, minutes: 30),
      ),
    );
  });

  tearDown(getIt.reset);

  testWidgets('displays formatted estimate', (tester) async {
    await tester.pumpWidget(
      WidgetTestBench(
        child: EstimatedTimeWidget(
          task: testTask,
          save: ({Duration? estimate, bool stopRecording = false}) async {},
        ),
      ),
    );

    expect(find.text('02:30'), findsOneWidget);
  });

  testWidgets('displays placeholder when no estimate', (tester) async {
    final taskWithoutEstimate = Task(
      meta: testTask.meta,
      data: TaskData(
        status: testTask.data.status,
        dateFrom: testTask.data.dateFrom,
        dateTo: testTask.data.dateTo,
        statusHistory: [],
        title: 'Test Task',
        // No estimate
      ),
    );

    await tester.pumpWidget(
      WidgetTestBench(
        child: EstimatedTimeWidget(
          task: taskWithoutEstimate,
          save: ({Duration? estimate, bool stopRecording = false}) async {},
        ),
      ),
    );

    expect(find.text('No estimate'), findsOneWidget);
  });

  testWidgets('is tappable', (tester) async {
    await tester.pumpWidget(
      WidgetTestBench(
        child: EstimatedTimeWidget(
          task: testTask,
          save: ({Duration? estimate, bool stopRecording = false}) async {},
        ),
      ),
    );

    await tester.tap(find.text('02:30'));
    expect(true, isTrue); // Just verify it doesn't crash
  });

  testWidgets('shows time recording icon', (tester) async {
    await tester.pumpWidget(
      WidgetTestBench(
        child: EstimatedTimeWidget(
          task: testTask,
          save: ({Duration? estimate, bool stopRecording = false}) async {},
        ),
      ),
    );

    expect(find.byType(TimeRecordingIcon), findsOneWidget);
  });

  testWidgets(
      'showEstimatePicker does not call callback when duration unchanged',
      (tester) async {
    var callbackCalled = false;

    await tester.pumpWidget(
      WidgetTestBench(
        child: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showEstimatePicker(
                      context: context,
                      initialDuration: const Duration(hours: 2),
                      onEstimateChanged: (newDuration) async {
                        callbackCalled = true;
                      },
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Without changing the picker value, tapping Done should not call callback.
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(callbackCalled, isFalse);
  });

  testWidgets('showEstimatePicker calls callback when duration changes',
      (tester) async {
    Duration? selected;

    await tester.pumpWidget(
      WidgetTestBench(
        child: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showEstimatePicker(
                      context: context,
                      initialDuration: const Duration(hours: 2),
                      onEstimateChanged: (newDuration) async {
                        selected = newDuration;
                      },
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Simulate the user changing the duration in the picker.
    final picker = tester.widget<CupertinoTimerPicker>(
      find.byType(CupertinoTimerPicker),
    );
    picker.onTimerDurationChanged(const Duration(hours: 3));

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(selected, equals(const Duration(hours: 3)));
  });
}
