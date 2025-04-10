import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/task_list_card_card.dart';
import 'package:lotti/features/tasks/ui/task_status.dart';
import 'package:lotti/features/tasks/ui/time_recording_icon.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../test_helper.dart';

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

class MockNavService extends Mock implements NavService {}

class MockTimeService extends Mock implements TimeService {}

class MockBuildContext extends Mock implements BuildContext {}

class FakeJournalEntity extends Fake implements JournalEntity {}

void main() {
  late Task testTask;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockNavService mockNavService;
  late MockTimeService mockTimeService;
  late String taskId;

  setUpAll(() {
    registerFallbackValue(MockBuildContext());
    registerFallbackValue(FakeJournalEntity());
  });

  setUp(() {
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockNavService = MockNavService();
    mockTimeService = MockTimeService();

    // Register mock services
    getIt.allowReassignment = true;
    getIt
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<TimeService>(mockTimeService);

    // Create test data
    taskId = 'test-task-id';
    const categoryId = 'test-category-id';
    final now = DateTime.now();

    final taskStatus = TaskStatus.open(
      id: 'status-id',
      createdAt: now,
      utcOffset: now.timeZoneOffset.inMinutes,
    );

    final metadata = Metadata(
      id: taskId,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now.add(const Duration(hours: 1)),
      categoryId: categoryId,
    );

    final taskData = TaskData(
      status: taskStatus,
      dateFrom: now,
      dateTo: now.add(const Duration(hours: 1)),
      statusHistory: [],
      title: 'Test Task Title',
    );

    testTask = Task(
      meta: metadata,
      data: taskData,
    );

    // Setup mock behavior
    when(() => mockTimeService.getStream())
        .thenAnswer((_) => Stream.value(null));
    when(() => mockTimeService.linkedFrom).thenReturn(null);
  });

  tearDown(() {
    // Clean up registered services
    getIt
      ..unregister<EntitiesCacheService>()
      ..unregister<TimeService>();
    if (getIt.isRegistered<NavService>()) {
      getIt.unregister<NavService>();
    }
  });

  testWidgets('displays task title correctly', (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      createTestApp(
        TaskListCard(task: testTask),
      ),
    );

    // Assert
    expect(find.text('Test Task Title'), findsOneWidget);
  });

  testWidgets('displays CategoryColorIcon with correct categoryId',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      createTestApp(
        TaskListCard(task: testTask),
      ),
    );

    // Assert
    expect(find.byType(CategoryColorIcon), findsOneWidget);

    // Verify that the CategoryColorIcon has the correct categoryId
    final categoryIconWidget = tester.widget<CategoryColorIcon>(
      find.byType(CategoryColorIcon),
    );
    expect(categoryIconWidget.categoryId, testTask.meta.categoryId);
  });

  testWidgets('displays TaskStatusWidget with correct task',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      createTestApp(
        TaskListCard(task: testTask),
      ),
    );

    // Assert
    expect(find.byType(TaskStatusWidget), findsOneWidget);

    // Verify that the TaskStatusWidget has the correct task
    final taskStatusWidget = tester.widget<TaskStatusWidget>(
      find.byType(TaskStatusWidget),
    );
    expect(taskStatusWidget.task, testTask);
  });

  testWidgets('displays TimeRecordingIcon with correct taskId and padding',
      (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      createTestApp(
        TaskListCard(task: testTask),
      ),
    );

    // Assert
    expect(find.byType(TimeRecordingIcon), findsOneWidget);

    // Verify that the TimeRecordingIcon has the correct taskId
    final timeRecordingIcon = tester.widget<TimeRecordingIcon>(
      find.byType(TimeRecordingIcon),
    );
    expect(timeRecordingIcon.taskId, taskId);
    expect(timeRecordingIcon.padding, const EdgeInsets.only(right: 10));
  });

  testWidgets('navigates to task details when tapped',
      (WidgetTester tester) async {
    // Arrange - register the mock nav service
    getIt.registerSingleton<NavService>(mockNavService);

    await tester.pumpWidget(
      createTestApp(
        TaskListCard(task: testTask),
      ),
    );

    // Act - tap the card
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    // Verify the navigation occurred with the correct path
    verify(
      () => mockNavService.beamToNamed(
        '/tasks/$taskId',
        data: any(named: 'data'),
      ),
    ).called(1);
  });

  testWidgets('TimeRecordingIcon shows icon when linked to current task',
      (WidgetTester tester) async {
    // Arrange - set up time service to return the task as linked
    when(() => mockTimeService.linkedFrom).thenReturn(testTask);
    when(() => mockTimeService.getStream())
        .thenAnswer((_) => Stream.value(testTask));

    await tester.pumpWidget(
      createTestApp(
        TaskListCard(task: testTask),
      ),
    );

    // Assert that TimeRecordingIcon shows the ColorIcon when linked
    await tester.pump();
    expect(find.byType(TimeRecordingIcon), findsOneWidget);

    // We should find a Padding inside the TimeRecordingIcon that contains a ColorIcon
    final timeRecordingIconFinder = find.byType(TimeRecordingIcon);
    final paddingFinder = find.descendant(
      of: timeRecordingIconFinder,
      matching: find.byType(Padding),
    );
    expect(paddingFinder, findsOneWidget);

    final colorIconFinder = find.descendant(
      of: paddingFinder,
      matching: find.byType(ColorIcon),
    );
    expect(colorIconFinder, findsOneWidget);
  });
}
