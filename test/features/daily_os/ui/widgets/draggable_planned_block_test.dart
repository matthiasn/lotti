import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/draggable_planned_block.dart';
import 'package:lotti/features/daily_os/util/drag_position_utils.dart';
import 'package:lotti/features/daily_os/util/timeline_folding_utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../test_helper.dart';

class MockEntitiesCacheService extends Mock implements EntitiesCacheService {}

/// Mock controller that returns fixed unified data.
class _TestUnifiedController extends UnifiedDailyOsDataController {
  _TestUnifiedController(this._data);

  final DailyOsData _data;

  @override
  Future<DailyOsData> build({required DateTime date}) async {
    return _data;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDate = DateTime(2026, 1, 15);

  final testCategory = CategoryDefinition(
    id: 'cat-1',
    name: 'Work',
    color: '#4285F4',
    createdAt: testDate,
    updatedAt: testDate,
    vectorClock: null,
    private: false,
    active: true,
  );

  late MockEntitiesCacheService mockCacheService;

  PlannedBlock createTestBlock({
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    String categoryId = 'cat-1',
  }) {
    return PlannedBlock(
      id: 'block-1',
      categoryId: categoryId,
      startTime: testDate.add(Duration(hours: startHour, minutes: startMinute)),
      endTime: testDate.add(Duration(hours: endHour, minutes: endMinute)),
    );
  }

  PlannedTimeSlot createTestSlot({
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    String categoryId = 'cat-1',
  }) {
    final block = createTestBlock(
      startHour: startHour,
      startMinute: startMinute,
      endHour: endHour,
      endMinute: endMinute,
      categoryId: categoryId,
    );
    return PlannedTimeSlot(
      block: block,
      startTime: block.startTime,
      endTime: block.endTime,
      categoryId: categoryId,
    );
  }

  DayPlanEntry createEmptyDayPlan(DateTime date) {
    return DayPlanEntry(
      meta: Metadata(
        id: dayPlanId(date),
        createdAt: date,
        updatedAt: date,
        dateFrom: date,
        dateTo: date.add(const Duration(days: 1)),
      ),
      data: DayPlanData(
        planDate: date,
        status: const DayPlanStatus.draft(),
      ),
    );
  }

  Widget createTestWidget({
    required PlannedTimeSlot slot,
    required int sectionStartHour,
    required int sectionEndHour,
    TimelineFoldingState? foldingState,
    Set<int> expandedRegions = const {},
    String? highlightedCategoryId,
    DragActiveChangedCallback? onDragActiveChanged,
    List<Override> additionalOverrides = const [],
  }) {
    final effectiveFoldingState = foldingState ??
        TimelineFoldingState(
          visibleClusters: [
            VisibleCluster(
                startHour: sectionStartHour, endHour: sectionEndHour),
          ],
          compressedRegions: const [],
        );

    final unifiedData = DailyOsData(
      date: testDate,
      dayPlan: createEmptyDayPlan(testDate),
      timelineData: DailyTimelineData(
        date: testDate,
        plannedSlots: [slot],
        actualSlots: const [],
        dayStartHour: sectionStartHour,
        dayEndHour: sectionEndHour,
      ),
      budgetProgress: const [],
    );

    // Calculate section height for positioning
    final sectionHeight =
        (sectionEndHour - sectionStartHour) * kHourHeight + 100;

    return RiverpodWidgetTestBench(
      overrides: [
        dailyOsSelectedDateProvider.overrideWithValue(testDate),
        unifiedDailyOsDataControllerProvider(date: testDate).overrideWith(
          () => _TestUnifiedController(unifiedData),
        ),
        highlightedCategoryIdProvider
            .overrideWith((ref) => highlightedCategoryId),
        runningTimerCategoryIdProvider.overrideWithValue(null),
        ...additionalOverrides,
      ],
      child: SizedBox(
        height: sectionHeight,
        width: 200,
        child: Stack(
          children: [
            DraggablePlannedBlock(
              slot: slot,
              sectionStartHour: sectionStartHour,
              sectionEndHour: sectionEndHour,
              date: testDate,
              foldingState: effectiveFoldingState,
              expandedRegions: expandedRegions,
              onDragActiveChanged: onDragActiveChanged,
            ),
          ],
        ),
      ),
    );
  }

  setUp(() {
    mockCacheService = MockEntitiesCacheService();
    // Use thenAnswer to handle different category IDs
    when(() => mockCacheService.getCategoryById(any()))
        .thenAnswer((invocation) {
      final categoryId = invocation.positionalArguments[0] as String?;
      if (categoryId == 'cat-1') {
        return testCategory;
      }
      return null;
    });

    if (getIt.isRegistered<EntitiesCacheService>()) {
      getIt.unregister<EntitiesCacheService>();
    }
    getIt.registerSingleton<EntitiesCacheService>(mockCacheService);
  });

  tearDown(() async {
    if (getIt.isRegistered<EntitiesCacheService>()) {
      getIt.unregister<EntitiesCacheService>();
    }
  });

  group('DraggablePlannedBlock rendering', () {
    testWidgets('renders category name', (tester) async {
      final slot = createTestSlot(
        startHour: 9,
        startMinute: 0,
        endHour: 11,
        endMinute: 0,
      );

      await tester.pumpWidget(
        createTestWidget(
          slot: slot,
          sectionStartHour: 8,
          sectionEndHour: 18,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Work'), findsOneWidget);
    });

    testWidgets('renders fallback text when no category', (tester) async {
      final slot = createTestSlot(
        startHour: 9,
        startMinute: 0,
        endHour: 11,
        endMinute: 0,
        categoryId: 'unknown-cat',
      );

      await tester.pumpWidget(
        createTestWidget(
          slot: slot,
          sectionStartHour: 8,
          sectionEndHour: 18,
        ),
      );
      await tester.pumpAndSettle();

      // Should show fallback "Planned" text
      expect(find.text('Planned'), findsOneWidget);
    });

    testWidgets('shows resize handles for large blocks', (tester) async {
      // 2 hour block = 80px > 48px threshold
      final slot = createTestSlot(
        startHour: 9,
        startMinute: 0,
        endHour: 11,
        endMinute: 0,
      );

      await tester.pumpWidget(
        createTestWidget(
          slot: slot,
          sectionStartHour: 8,
          sectionEndHour: 18,
        ),
      );
      await tester.pumpAndSettle();

      // Find resize handle containers (24x3 px decorations)
      final handleFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints?.maxWidth == 24 &&
            widget.constraints?.maxHeight == 3,
      );

      // Should have 2 resize handles (top and bottom)
      expect(handleFinder, findsNWidgets(2));
    });

    testWidgets('hides resize handles for small blocks (move-only mode)',
        (tester) async {
      // 30 min block = 20px < 48px threshold
      final slot = createTestSlot(
        startHour: 9,
        startMinute: 0,
        endHour: 9,
        endMinute: 30,
      );

      await tester.pumpWidget(
        createTestWidget(
          slot: slot,
          sectionStartHour: 8,
          sectionEndHour: 18,
        ),
      );
      await tester.pumpAndSettle();

      // Find resize handle containers
      final handleFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.constraints?.maxWidth == 24 &&
            widget.constraints?.maxHeight == 3,
      );

      // Should have no resize handles in move-only mode
      expect(handleFinder, findsNothing);
    });

    testWidgets('applies highlighted style when category is highlighted',
        (tester) async {
      final slot = createTestSlot(
        startHour: 9,
        startMinute: 0,
        endHour: 11,
        endMinute: 0,
      );

      await tester.pumpWidget(
        createTestWidget(
          slot: slot,
          sectionStartHour: 8,
          sectionEndHour: 18,
          highlightedCategoryId: 'cat-1',
        ),
      );
      await tester.pumpAndSettle();

      // Find the AnimatedContainer with border
      final animatedContainer = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );

      final decoration = animatedContainer.decoration! as BoxDecoration;
      final border = decoration.border! as Border;

      // Highlighted should have width 2
      expect(border.top.width, equals(2.0));
    });
  });

  group('DraggablePlannedBlock interactions', () {
    testWidgets('tap does not crash', (tester) async {
      final slot = createTestSlot(
        startHour: 9,
        startMinute: 0,
        endHour: 11,
        endMinute: 0,
      );

      await tester.pumpWidget(
        createTestWidget(
          slot: slot,
          sectionStartHour: 8,
          sectionEndHour: 18,
        ),
      );
      await tester.pumpAndSettle();

      // Tap the block - should not crash
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();

      // Block should still be visible
      expect(find.text('Work'), findsOneWidget);
    });

    testWidgets('double tap does not crash', (tester) async {
      final slot = createTestSlot(
        startHour: 9,
        startMinute: 0,
        endHour: 11,
        endMinute: 0,
      );

      await tester.pumpWidget(
        createTestWidget(
          slot: slot,
          sectionStartHour: 8,
          sectionEndHour: 18,
        ),
      );
      await tester.pumpAndSettle();

      // Double tap - should not crash (would normally open edit modal)
      await tester.tap(find.text('Work'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Work'));
      await tester.pumpAndSettle();

      // Block widget should still be visible (modal may also show "Work")
      expect(find.byType(DraggablePlannedBlock), findsOneWidget);
    });

    testWidgets('long press initiates drag and calls onDragActiveChanged',
        (tester) async {
      var dragActive = false;

      final slot = createTestSlot(
        startHour: 9,
        startMinute: 0,
        endHour: 11,
        endMinute: 0,
      );

      await tester.pumpWidget(
        createTestWidget(
          slot: slot,
          sectionStartHour: 8,
          sectionEndHour: 18,
          onDragActiveChanged: ({required bool isDragging}) =>
              dragActive = isDragging,
        ),
      );
      await tester.pumpAndSettle();

      // Start long press
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Work')),
      );

      // Wait for long press to register
      await tester.pump(const Duration(milliseconds: 600));

      expect(dragActive, isTrue);

      // End the gesture
      await gesture.up();
      await tester.pumpAndSettle();

      expect(dragActive, isFalse);
    });

    testWidgets('drag shows time indicators', (tester) async {
      final slot = createTestSlot(
        startHour: 9,
        startMinute: 0,
        endHour: 11,
        endMinute: 0,
      );

      await tester.pumpWidget(
        createTestWidget(
          slot: slot,
          sectionStartHour: 8,
          sectionEndHour: 18,
        ),
      );
      await tester.pumpAndSettle();

      // Start long press
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Work')),
      );

      // Wait for long press to register
      await tester.pump(const Duration(milliseconds: 600));

      // Time indicators should appear
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('11:00'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('drag updates position visually', (tester) async {
      final slot = createTestSlot(
        startHour: 10,
        startMinute: 0,
        endHour: 11,
        endMinute: 0,
      );

      await tester.pumpWidget(
        createTestWidget(
          slot: slot,
          sectionStartHour: 8,
          sectionEndHour: 18,
        ),
      );
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.text('Work'));

      // Start long press
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 600));

      // Move down by 40px (1 hour)
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();

      // Time should update to show new position
      expect(find.text('11:00'), findsOneWidget);
      expect(find.text('12:00'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('drag is clamped to section boundaries', (tester) async {
      final slot = createTestSlot(
        startHour: 10,
        startMinute: 0,
        endHour: 11,
        endMinute: 0,
      );

      await tester.pumpWidget(
        createTestWidget(
          slot: slot,
          sectionStartHour: 9,
          sectionEndHour: 12,
        ),
      );
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.text('Work'));

      // Start long press
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 600));

      // Try to move down by 200px (5 hours) - should be clamped
      await gesture.moveBy(const Offset(0, 200));
      await tester.pump();

      // End time should be clamped to section end (12:00)
      // So start time should be 11:00 for a 1-hour block
      expect(find.text('11:00'), findsOneWidget);
      expect(find.text('12:00'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('dragging up is also clamped to section start', (tester) async {
      final slot = createTestSlot(
        startHour: 10,
        startMinute: 0,
        endHour: 11,
        endMinute: 0,
      );

      await tester.pumpWidget(
        createTestWidget(
          slot: slot,
          sectionStartHour: 9,
          sectionEndHour: 18,
        ),
      );
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.text('Work'));

      // Start long press
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 600));

      // Try to move up by 200px - should be clamped to section start
      await gesture.moveBy(const Offset(0, -200));
      await tester.pump();

      // Start time should be clamped to section start (09:00)
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('DraggablePlannedBlock drag modes', () {
    testWidgets('tapping top edge detects resize top mode', (tester) async {
      // Need a larger block for resize handles to be active
      final slot = createTestSlot(
        startHour: 9,
        startMinute: 0,
        endHour: 12,
        endMinute: 0,
      );

      await tester.pumpWidget(
        createTestWidget(
          slot: slot,
          sectionStartHour: 8,
          sectionEndHour: 18,
        ),
      );
      await tester.pumpAndSettle();

      // Get the block bounds
      final blockFinder = find.byType(DraggablePlannedBlock);
      final blockBox = tester.getRect(blockFinder);

      // Long press near top edge
      final topEdge = Offset(blockBox.center.dx, blockBox.top + 5);
      final gesture = await tester.startGesture(topEdge);
      await tester.pump(const Duration(milliseconds: 600));

      // Drag down to resize
      await gesture.moveBy(const Offset(0, 20)); // 30 minutes
      await tester.pump();

      // Start time should change, end time should stay the same
      expect(find.text('09:30'), findsOneWidget); // New start
      expect(find.text('12:00'), findsOneWidget); // Same end

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('tapping bottom edge detects resize bottom mode',
        (tester) async {
      final slot = createTestSlot(
        startHour: 9,
        startMinute: 0,
        endHour: 12,
        endMinute: 0,
      );

      await tester.pumpWidget(
        createTestWidget(
          slot: slot,
          sectionStartHour: 8,
          sectionEndHour: 18,
        ),
      );
      await tester.pumpAndSettle();

      // Get the block bounds
      final blockFinder = find.byType(DraggablePlannedBlock);
      final blockBox = tester.getRect(blockFinder);

      // Long press near bottom edge
      final bottomEdge = Offset(blockBox.center.dx, blockBox.bottom - 5);
      final gesture = await tester.startGesture(bottomEdge);
      await tester.pump(const Duration(milliseconds: 600));

      // Drag down to resize
      await gesture.moveBy(const Offset(0, 20)); // 30 minutes
      await tester.pump();

      // End time should change, start time should stay the same
      expect(find.text('09:00'), findsOneWidget); // Same start
      expect(find.text('12:30'), findsOneWidget); // New end

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('tapping block center detects move mode and shows duration',
        (tester) async {
      final slot = createTestSlot(
        startHour: 9,
        startMinute: 0,
        endHour: 12,
        endMinute: 0,
      );

      await tester.pumpWidget(
        createTestWidget(
          slot: slot,
          sectionStartHour: 8,
          sectionEndHour: 18,
        ),
      );
      await tester.pumpAndSettle();

      // Get block center (not text center which is at top)
      final blockFinder = find.byType(DraggablePlannedBlock);
      final blockCenter = tester.getCenter(blockFinder);

      // Long press at block center
      final gesture = await tester.startGesture(blockCenter);
      await tester.pump(const Duration(milliseconds: 600));

      // In move mode, duration indicator should show
      expect(find.text('3h'), findsOneWidget);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('small block always uses move mode regardless of tap position',
        (tester) async {
      // Small block (30 min = 20px < 48px threshold)
      final slot = createTestSlot(
        startHour: 9,
        startMinute: 0,
        endHour: 9,
        endMinute: 30,
      );

      await tester.pumpWidget(
        createTestWidget(
          slot: slot,
          sectionStartHour: 8,
          sectionEndHour: 18,
        ),
      );
      await tester.pumpAndSettle();

      // Get the block bounds
      final blockFinder = find.byType(DraggablePlannedBlock);
      final blockBox = tester.getRect(blockFinder);

      // Long press near top edge (would be resize on large block)
      final topEdge = Offset(blockBox.center.dx, blockBox.top + 2);
      final gesture = await tester.startGesture(topEdge);
      await tester.pump(const Duration(milliseconds: 600));

      // Drag down
      await gesture.moveBy(const Offset(0, 40)); // 1 hour
      await tester.pump();

      // Both times should shift (move mode, not resize)
      expect(find.text('10:00'), findsOneWidget); // New start
      expect(find.text('10:30'), findsOneWidget); // New end

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('DraggablePlannedBlock haptic feedback', () {
    testWidgets('long press triggers haptic feedback', (tester) async {
      final messages = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (methodCall) async {
          if (methodCall.method == 'HapticFeedback.vibrate') {
            messages.add(methodCall);
          }
          return null;
        },
      );

      try {
        final slot = createTestSlot(
          startHour: 9,
          startMinute: 0,
          endHour: 11,
          endMinute: 0,
        );

        await tester.pumpWidget(
          createTestWidget(
            slot: slot,
            sectionStartHour: 8,
            sectionEndHour: 18,
          ),
        );
        await tester.pumpAndSettle();

        // Long press
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Work')),
        );
        await tester.pump(const Duration(milliseconds: 600));

        // Should have received haptic feedback
        expect(messages, isNotEmpty);

        await gesture.up();
        await tester.pumpAndSettle();
      } finally {
        // Clean up mock handler to prevent leaks into other tests
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      }
    });
  });
}
