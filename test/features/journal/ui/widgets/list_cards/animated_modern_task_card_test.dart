import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/animated_modern_task_card.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/modern_task_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/widgets/modal/animated_modal_item.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../test_helper.dart';

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {
  @override
  CategoryDefinition? getCategoryById(String? id) {
    return id == 'test-category-id'
        ? CategoryDefinition(
            id: 'test-category-id',
            createdAt: DateTime(2024, 1, 1, 12),
            updatedAt: DateTime(2024, 1, 1, 12),
            name: 'Test Category',
            vectorClock: null,
            private: false,
            active: true,
            color: '#FF0000',
          )
        : null;
  }
}

class MockNavService extends Mock implements NavService {
  final List<String> navigationHistory = [];

  @override
  void beamToNamed(String path, {Object? data}) {
    navigationHistory.add(path);
  }
}

class MockTimeService extends Mock implements TimeService {
  @override
  JournalEntity? get linkedFrom => null;

  @override
  Stream<JournalEntity?> getStream() => Stream.value(null);
}

class MockTagsService extends Mock implements TagsService {
  @override
  Map<String, TagEntity> tagsById = {};

  @override
  Stream<List<TagEntity>> watchTags() => Stream.value(<TagEntity>[]);

  @override
  TagEntity? getTagById(String id) => null;
}

void main() {
  late Task testTask;
  late MockEntitiesCacheService mockEntitiesCacheService;
  late MockNavService mockNavService;
  late MockTimeService mockTimeService;
  late MockTagsService mockTagsService;
  late DateTime now;

  setUp(() {
    mockEntitiesCacheService = MockEntitiesCacheService();
    mockNavService = MockNavService();
    mockTimeService = MockTimeService();
    mockTagsService = MockTagsService();

    // Register mock services
    getIt.allowReassignment = true;
    getIt
      ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
      ..registerSingleton<TimeService>(mockTimeService)
      ..registerSingleton<NavService>(mockNavService)
      ..registerSingleton<TagsService>(mockTagsService);

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
  });

  tearDown(() {
    // Clean up registered services
    getIt
      ..unregister<EntitiesCacheService>()
      ..unregister<TimeService>()
      ..unregister<NavService>()
      ..unregister<TagsService>();
  });

  group('AnimatedModernTaskCard', () {
    testWidgets('renders task card with animation wrapper',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: AnimatedModernTaskCard(
            task: testTask,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the animated wrapper is present
      expect(find.byType(AnimatedModalItem), findsOneWidget);

      // Verify the underlying task card is rendered
      expect(find.byType(ModernTaskCard), findsOneWidget);

      // Verify task title is displayed
      expect(find.text('Test Task Title'), findsOneWidget);
    });

    testWidgets('passes compact mode to underlying card',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: AnimatedModernTaskCard(
            task: testTask,
            isCompact: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the ModernTaskCard receives the compact flag
      final modernTaskCard = tester.widget<ModernTaskCard>(
        find.byType(ModernTaskCard),
      );
      expect(modernTaskCard.isCompact, true);
    });

    testWidgets('navigates to task detail on tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: AnimatedModernTaskCard(
            task: testTask,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the card
      await tester.tap(find.byType(AnimatedModalItem));
      await tester.pump();

      // Verify navigation was triggered
      expect(mockNavService.navigationHistory, ['/tasks/test-task-id']);
    });

    testWidgets('applies correct animation parameters',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: AnimatedModernTaskCard(
            task: testTask,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the AnimatedModalItem has the correct parameters
      final animatedItem = tester.widget<AnimatedModalItem>(
        find.byType(AnimatedModalItem),
      );
      expect(animatedItem.hoverScale, 0.995);
      expect(animatedItem.tapScale, 0.985);
      expect(animatedItem.hoverElevation, 2);
      expect(animatedItem.margin, EdgeInsets.zero);
    });

    testWidgets('hover animation triggers on desktop',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: AnimatedModernTaskCard(
            task: testTask,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find MouseRegions - there may be multiple due to nested widgets
      final mouseRegions = find.byType(MouseRegion);
      expect(mouseRegions, findsWidgets);

      // Simulate hover on the AnimatedModalItem
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer();
      await gesture.moveTo(tester.getCenter(find.byType(AnimatedModalItem)));
      await tester.pumpAndSettle();

      // The animation should have triggered
      // We can't easily test the visual result, but we verify the gesture was handled
      expect(find.byType(Transform), findsWidgets);

      // Clean up
      await gesture.removePointer();
    });

    testWidgets('tap animation triggers correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: AnimatedModernTaskCard(
            task: testTask,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Start tap
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(AnimatedModalItem)),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // The tap animation should be in progress
      expect(find.byType(Transform), findsWidgets);

      // Complete tap
      await gesture.up();
      await tester.pumpAndSettle();

      // Verify navigation occurred
      expect(mockNavService.navigationHistory, ['/tasks/test-task-id']);
    });

    testWidgets('renders task with different statuses',
        (WidgetTester tester) async {
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
      await tester.pumpAndSettle();

      // Verify the card renders without errors
      expect(find.byType(AnimatedModernTaskCard), findsOneWidget);
      expect(find.text('Test Task Title'), findsOneWidget);
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
      await tester.pumpAndSettle();

      // Verify the card renders with due date
      expect(find.byType(AnimatedModernTaskCard), findsOneWidget);
      expect(find.byIcon(Icons.event_rounded), findsOneWidget);
    });

    testWidgets('maintains correct layout structure',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: AnimatedModernTaskCard(
            task: testTask,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the widget tree structure
      expect(
        find.descendant(
          of: find.byType(AnimatedModalItem),
          matching: find.byType(ModernTaskCard),
        ),
        findsOneWidget,
      );
    });

    testWidgets('card responds to rapid taps correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: AnimatedModernTaskCard(
            task: testTask,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Perform multiple rapid taps
      await tester.tap(find.byType(AnimatedModalItem));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(AnimatedModalItem));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(AnimatedModalItem));
      await tester.pumpAndSettle();

      // Navigation should have been called three times
      expect(mockNavService.navigationHistory.length, 3);
    });

    testWidgets('handles long task titles gracefully',
        (WidgetTester tester) async {
      final longTitleTask = testTask.copyWith(
        data: testTask.data.copyWith(
          title: 'This is a very long task title that should be truncated '
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
      await tester.pumpAndSettle();

      // Verify the card renders without overflow
      expect(find.byType(AnimatedModernTaskCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('respects theme changes', (WidgetTester tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: Theme(
            data: ThemeData.dark(),
            child: AnimatedModernTaskCard(
              task: testTask,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the card renders in dark theme
      expect(find.byType(AnimatedModernTaskCard), findsOneWidget);

      // Switch to light theme
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          child: Theme(
            data: ThemeData.light(),
            child: AnimatedModernTaskCard(
              task: testTask,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the card renders in light theme
      expect(find.byType(AnimatedModernTaskCard), findsOneWidget);
    });
  });
}
