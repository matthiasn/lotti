import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/animated_task_card.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/task_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/modal/animated_modal_item.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_helper.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  late Task testTask;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late RecordingMockNavService mockNavService;
  late MockTimeService mockTimeService;
  late DateTime now;

  setUp(() {
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockNavService = RecordingMockNavService();
    mockTimeService = MockTimeService();
    // Register mock services
    getIt
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<TimeService>(mockTimeService)
      ..registerSingleton<NavService>(mockNavService);

    when(() => mockTimeService.linkedFrom).thenReturn(null);
    when(mockTimeService.getStream).thenAnswer((_) => Stream.value(null));
    when(
      () => mockEntitiesCacheService.getCategoryById(any()),
    ).thenReturn(null);
    when(
      () => mockEntitiesCacheService.getCategoryById('test-category-id'),
    ).thenReturn(
      CategoryDefinition(
        id: 'test-category-id',
        createdAt: DateTime(2024, 1, 1, 12),
        updatedAt: DateTime(2024, 1, 1, 12),
        name: 'Test Category',
        vectorClock: null,
        private: false,
        active: true,
        color: '#FF0000',
      ),
    );

    // Create test task
    now = DateTime(2024, 1, 1, 12); // Use a fixed time for deterministic tests
    const categoryId = 'test-category-id';
    const taskId = 'test-task-id';

    final metadata = Metadata(
      id: taskId,
      createdAt: now,
      updatedAt: now,
      dateFrom: now,
      dateTo: now.add(const Duration(hours: 1)),
      categoryId: categoryId,
    );

    final taskStatus = TaskStatus.open(
      id: 'status-id',
      createdAt: now,
      utcOffset: now.timeZoneOffset.inMinutes,
    );

    final taskData = TaskData(
      status: taskStatus,
      dateFrom: now,
      dateTo: now.add(const Duration(hours: 1)),
      statusHistory: [],
      title: 'Test Task Title',
    );

    const entryText = EntryText(
      plainText: 'Test task description',
      markdown: 'Test task description',
    );

    testTask = Task(
      meta: metadata,
      data: taskData,
      entryText: entryText,
    );

    // Ensure ThemingController dependencies are registered
    ensureThemingServicesRegistered();
  });

  tearDown(() {
    // Clean up registered services
    getIt
      ..unregister<EntitiesCacheService>()
      ..unregister<TimeService>()
      ..unregister<NavService>();
  });

  group('AnimatedModernTaskCard', () {
    testWidgets('renders task card with animation wrapper', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: AnimatedModernTaskCard(
            task: testTask,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Verify the animated wrapper is present
      expect(find.byType(AnimatedModalItem), findsOneWidget);

      // Verify the underlying task card is rendered
      expect(find.byType(ModernTaskCard), findsOneWidget);

      // Verify task title is displayed
      expect(find.text('Test Task Title'), findsOneWidget);
    });

    testWidgets('navigates to task detail on tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: AnimatedModernTaskCard(
            task: testTask,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Tap the card
      await tester.tap(find.byType(AnimatedModalItem));
      await tester.pump();

      // Verify navigation was triggered
      expect(mockNavService.navigationHistory, ['/tasks/test-task-id']);
    });

    testWidgets('applies correct animation parameters', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: AnimatedModernTaskCard(
            task: testTask,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Verify the AnimatedModalItem has the correct parameters
      final animatedItem = tester.widget<AnimatedModalItem>(
        find.byType(AnimatedModalItem),
      );
      expect(animatedItem.hoverScale, 0.995);
      expect(animatedItem.tapScale, 0.985);
      expect(animatedItem.hoverElevation, 2);
      expect(animatedItem.margin, EdgeInsets.zero);
      // ModernTaskCard draws its own shadow, so the wrapper disables its own.
      expect(animatedItem.disableShadow, isTrue);
    });

    testWidgets('hover animation triggers on desktop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: AnimatedModernTaskCard(
            task: testTask,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Find MouseRegions - there may be multiple due to nested widgets
      final mouseRegions = find.byType(MouseRegion);
      expect(mouseRegions, findsWidgets);

      // Simulate hover on the AnimatedModalItem
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer();
      await gesture.moveTo(tester.getCenter(find.byType(AnimatedModalItem)));
      await tester.pump(const Duration(milliseconds: 300));

      // The animation should have triggered
      // We can't easily test the visual result, but we verify the gesture was handled
      expect(find.byType(Transform), findsWidgets);

      // Clean up
      await gesture.removePointer();
    });

    testWidgets('tap animation triggers correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: AnimatedModernTaskCard(
            task: testTask,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Start tap
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AnimatedModalItem)),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // The tap animation should be in progress
      expect(find.byType(Transform), findsWidgets);

      // Complete tap
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify navigation occurred
      expect(mockNavService.navigationHistory, ['/tasks/test-task-id']);
    });

    testWidgets('renders task with different statuses', (
      WidgetTester tester,
    ) async {
      // Test with in-progress status
      final inProgressTask = testTask.copyWith(
        data: testTask.data.copyWith(
          status: TaskStatus.inProgress(
            id: 'status-id',
            createdAt: now,
            utcOffset: now.timeZoneOffset.inMinutes,
          ),
        ),
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: AnimatedModernTaskCard(
            task: inProgressTask,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // The inner card receives the in-progress status — not just any task.
      expect(find.text('Test Task Title'), findsOneWidget);
      final innerCard = tester.widget<ModernTaskCard>(
        find.byType(ModernTaskCard),
      );
      expect(innerCard.task.data.status, isA<TaskInProgress>());
    });

    testWidgets('handles task with due date', (WidgetTester tester) async {
      // Create task with due date
      final taskWithDue = testTask.copyWith(
        data: testTask.data.copyWith(
          due: now.add(const Duration(days: 7)),
        ),
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: AnimatedModernTaskCard(
            task: taskWithDue,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Verify the card renders with due date
      expect(find.byType(AnimatedModernTaskCard), findsOneWidget);
      expect(find.byIcon(Icons.event_rounded), findsOneWidget);
    });

    testWidgets('maintains correct layout structure', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: AnimatedModernTaskCard(
            task: testTask,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Verify the widget tree structure
      expect(
        find.descendant(
          of: find.byType(AnimatedModalItem),
          matching: find.byType(ModernTaskCard),
        ),
        findsOneWidget,
      );
    });

    testWidgets('card responds to rapid taps correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: AnimatedModernTaskCard(
            task: testTask,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Perform multiple rapid taps
      await tester.tap(find.byType(AnimatedModalItem));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(AnimatedModalItem));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(AnimatedModalItem));
      await tester.pump(const Duration(milliseconds: 300));

      // Navigation should have been called three times
      expect(mockNavService.navigationHistory.length, 3);
    });

    testWidgets('handles long task titles gracefully', (
      WidgetTester tester,
    ) async {
      final longTitleTask = testTask.copyWith(
        data: testTask.data.copyWith(
          title:
              'This is a very long task title that should be truncated '
              'properly when displayed in the card to ensure good UI',
        ),
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: AnimatedModernTaskCard(
            task: longTitleTask,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Verify the card renders without overflow
      expect(find.byType(AnimatedModernTaskCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('passes showCreationDate to ModernTaskCard', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: AnimatedModernTaskCard(
            task: testTask,
            showCreationDate: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Verify ModernTaskCard receives showCreationDate: true
      final modernTaskCard = tester.widget<ModernTaskCard>(
        find.byType(ModernTaskCard),
      );
      expect(modernTaskCard.showCreationDate, isTrue);
    });

    testWidgets('showCreationDate defaults to false', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: AnimatedModernTaskCard(
            task: testTask,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      // Verify ModernTaskCard receives showCreationDate: false by default
      final modernTaskCard = tester.widget<ModernTaskCard>(
        find.byType(ModernTaskCard),
      );
      expect(modernTaskCard.showCreationDate, isFalse);
    });
  });
}
