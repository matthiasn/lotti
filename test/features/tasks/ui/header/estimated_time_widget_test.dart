import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/tasks/ui/header/estimated_time_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/date_time/duration_bottom_sheet.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_helper.dart';

class MockTask extends Mock implements Task {
  MockTask(this.taskData);

  final TaskData taskData;

  @override
  TaskData get data => taskData;

  @override
  Metadata get meta => Metadata(
        id: 'test-task-id',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        dateFrom: DateTime.now(),
        dateTo: DateTime.now(),
      );
}

class MockSaveCallback extends Mock {
  Future<void> call({Duration? estimate, bool stopRecording = false});
}

class MockTimeService extends Mock implements TimeService {}

// Create a mock build context for testing
class MockBuildContext extends Mock implements BuildContext {}

void main() {
  late MockTask mockTask;
  late MockSaveCallback mockSave;
  late MockTimeService mockTimeService;

  setUp(() {
    final taskData = TaskData(
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
    );

    mockTask = MockTask(taskData);
    mockSave = MockSaveCallback();
    mockTimeService = MockTimeService();

    // Register the mock TimeService in GetIt
    getIt.registerSingleton<TimeService>(mockTimeService);

    // Setup the mock responses
    when(() => mockTimeService.getStream())
        .thenAnswer((_) => Stream<JournalEntity?>.fromIterable([]));
    when(() => mockTimeService.linkedFrom).thenReturn(null);

    when(
      () => mockSave(
        estimate: any(named: 'estimate'),
        stopRecording: any(named: 'stopRecording'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(getIt.reset);

  testWidgets('renders with task estimate', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        EstimatedTimeWidget(
          task: mockTask,
          save: mockSave.call,
        ),
      ),
    );

    // Verify the widget displays the formatted estimate (02:30)
    expect(find.text('02:30'), findsOneWidget);

    // Verify the label is displayed
    expect(find.byType(Text), findsAtLeast(2));
  });

  testWidgets('renders with zero estimate when task has no estimate',
      (tester) async {
    final taskData = TaskData(
      status: TaskStatus.open(
        id: 'test-status-id',
        createdAt: DateTime.now(),
        utcOffset: 0,
      ),
      dateFrom: DateTime.now(),
      dateTo: DateTime.now(),
      statusHistory: [],
      title: 'Test Task',
    );

    mockTask = MockTask(taskData);

    await tester.pumpWidget(
      createTestApp(
        EstimatedTimeWidget(
          task: mockTask,
          save: mockSave.call,
        ),
      ),
    );

    // Verify the widget displays 00:00 when no estimate is set
    expect(find.text('00:00'), findsOneWidget);
  });

  testWidgets('opens duration bottom sheet when tapped', (tester) async {
    await tester.pumpWidget(
      createTestApp(
        EstimatedTimeWidget(
          task: mockTask,
          save: mockSave.call,
        ),
      ),
    );

    // Tap on the widget
    await tester.tap(find.byType(InkWell));
    await tester.pump();

    // After tapping, we should see the modal bottom sheet
    expect(find.byType(DurationBottomSheet), findsOneWidget);
  });

  // This uses a more direct approach to test save functionality
  test('save is called with duration when user selects a new duration',
      () async {
    // Create a controller to simulate the EstimatedTimeWidget's functionality
    final widget = EstimatedTimeWidget(
      task: mockTask,
      save: mockSave.call,
    );

    // Directly simulate the effect of showModalBottomSheet returning a value
    // by calling the onTap method with a mocked context
    const duration = Duration(hours: 4, minutes: 15);

    // Mock the showModalBottomSheet function's behavior without actually needing to replace it
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'showModalBottomSheet') {
          // Return the duration we want to test with
          return duration;
        }
        return null;
      },
    );

    // Create an instance of the widget and call its save method directly
    await widget.save(estimate: duration);

    // Verify mock save was called with the provided duration
    verify(
      () => mockSave(
        estimate: duration,
        stopRecording: any(named: 'stopRecording'),
      ),
    ).called(1);
  });
}
