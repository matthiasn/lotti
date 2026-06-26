import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/planned_block_edit_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';

/// Mock controller that returns fixed unified data and records mutations.
class _TestUnifiedController extends UnifiedDailyOsDataController {
  _TestUnifiedController(this._data);

  final DailyOsData _data;

  PlannedBlock? lastUpdatedBlock;
  String? lastRemovedBlockId;

  @override
  Future<DailyOsData> build() async {
    return _data;
  }

  @override
  Future<void> updatePlannedBlock(PlannedBlock block) async {
    lastUpdatedBlock = block;
  }

  @override
  Future<void> removePlannedBlock(String blockId) async {
    lastRemovedBlockId = blockId;
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

  setUp(() {
    mockCacheService = MockEntitiesCacheService();
    when(
      () => mockCacheService.getCategoryById('cat-1'),
    ).thenReturn(testCategory);
    when(() => mockCacheService.getCategoryById(any())).thenReturn(null);

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

  PlannedBlock createTestBlock({
    String? categoryId,
    String? note,
    int startHour = 9,
    int endHour = 11,
  }) {
    return PlannedBlock(
      id: 'block-1',
      categoryId: categoryId ?? testCategory.id,
      startTime: testDate.add(Duration(hours: startHour)),
      endTime: testDate.add(Duration(hours: endHour)),
      note: note,
    );
  }

  DayPlanEntry createTestPlan({
    List<PlannedBlock>? blocks,
  }) {
    return DayPlanEntry(
      meta: Metadata(
        id: dayPlanId(testDate),
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate.add(const Duration(days: 1)),
      ),
      data: DayPlanData(
        planDate: testDate,
        status: const DayPlanStatus.draft(),
        plannedBlocks: blocks ?? [createTestBlock()],
      ),
    );
  }

  DailyTimelineData createTestTimelineData() {
    return DailyTimelineData(
      date: testDate,
      plannedSlots: [],
      actualSlots: [],
      dayStartHour: 8,
      dayEndHour: 18,
    );
  }

  Widget createTestWidget({
    required PlannedBlock block,
    DayPlanEntry? plan,
    List<Override> additionalOverrides = const [],
    _TestUnifiedController? controller,
  }) {
    final effectivePlan = plan ?? createTestPlan();

    final unifiedData = DailyOsData(
      date: testDate,
      dayPlan: effectivePlan,
      timelineData: createTestTimelineData(),
      budgetProgress: [],
    );

    final effectiveController =
        controller ?? _TestUnifiedController(unifiedData);

    return RiverpodWidgetTestBench(
      overrides: [
        dailyOsSelectedDateProvider.overrideWithBuild((_, _) => testDate),
        unifiedDailyOsDataControllerProvider(testDate).overrideWith(
          () => effectiveController,
        ),
        ...additionalOverrides,
      ],
      child: Builder(
        builder: (context) => Scaffold(
          body: PlannedBlockEditModal(block: block, date: testDate),
        ),
      ),
    );
  }

  _TestUnifiedController createController({DayPlanEntry? plan}) {
    final effectivePlan = plan ?? createTestPlan();
    final unifiedData = DailyOsData(
      date: testDate,
      dayPlan: effectivePlan,
      timelineData: createTestTimelineData(),
      budgetProgress: [],
    );
    return _TestUnifiedController(unifiedData);
  }

  group('PlannedBlockEditModal', () {
    testWidgets('renders modal with title', (tester) async {
      when(
        () => mockCacheService.getCategoryById('cat-1'),
      ).thenReturn(testCategory);

      await tester.pumpWidget(createTestWidget(block: createTestBlock()));
      await tester.pump();

      expect(find.text('Edit Planned Block'), findsOneWidget);
    });

    testWidgets('shows time range section', (tester) async {
      when(
        () => mockCacheService.getCategoryById('cat-1'),
      ).thenReturn(testCategory);

      await tester.pumpWidget(createTestWidget(block: createTestBlock()));
      await tester.pump();

      expect(find.text('Time Range'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('End'), findsOneWidget);
    });

    testWidgets('shows start and end times', (tester) async {
      when(
        () => mockCacheService.getCategoryById('cat-1'),
      ).thenReturn(testCategory);

      await tester.pumpWidget(
        createTestWidget(
          block: createTestBlock(),
        ),
      );
      await tester.pump();

      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('11:00'), findsOneWidget);
    });

    testWidgets('shows duration', (tester) async {
      when(
        () => mockCacheService.getCategoryById('cat-1'),
      ).thenReturn(testCategory);

      await tester.pumpWidget(
        createTestWidget(
          block: createTestBlock(),
        ),
      );
      await tester.pump();

      expect(find.text('2 hours'), findsOneWidget);
    });

    testWidgets('shows category section', (tester) async {
      when(
        () => mockCacheService.getCategoryById('cat-1'),
      ).thenReturn(testCategory);

      await tester.pumpWidget(createTestWidget(block: createTestBlock()));
      await tester.pump();

      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
    });

    testWidgets('shows Uncategorized when category not found', (tester) async {
      when(() => mockCacheService.getCategoryById(any())).thenReturn(null);

      await tester.pumpWidget(
        createTestWidget(block: createTestBlock(categoryId: 'unknown')),
      );
      await tester.pump();

      expect(find.text('Uncategorized'), findsOneWidget);
    });

    testWidgets('shows note section', (tester) async {
      when(
        () => mockCacheService.getCategoryById('cat-1'),
      ).thenReturn(testCategory);

      await tester.pumpWidget(createTestWidget(block: createTestBlock()));
      await tester.pump();

      expect(find.text('Note'), findsOneWidget);
      expect(find.text('Add a note...'), findsOneWidget);
    });

    testWidgets('displays existing note', (tester) async {
      when(
        () => mockCacheService.getCategoryById('cat-1'),
      ).thenReturn(testCategory);

      await tester.pumpWidget(
        createTestWidget(block: createTestBlock(note: 'Important meeting')),
      );
      await tester.pump();

      expect(find.text('Important meeting'), findsOneWidget);
    });

    testWidgets('shows action buttons', (tester) async {
      when(
        () => mockCacheService.getCategoryById('cat-1'),
      ).thenReturn(testCategory);

      await tester.pumpWidget(createTestWidget(block: createTestBlock()));
      await tester.pump();

      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('shows delete button', (tester) async {
      when(
        () => mockCacheService.getCategoryById('cat-1'),
      ).thenReturn(testCategory);

      await tester.pumpWidget(createTestWidget(block: createTestBlock()));
      await tester.pump();

      expect(find.byIcon(MdiIcons.delete), findsOneWidget);
    });

    testWidgets('renders PlannedBlockEditModal widget', (tester) async {
      when(
        () => mockCacheService.getCategoryById('cat-1'),
      ).thenReturn(testCategory);

      await tester.pumpWidget(createTestWidget(block: createTestBlock()));
      await tester.pump();

      expect(find.byType(PlannedBlockEditModal), findsOneWidget);
    });

    testWidgets('displays hours and minutes duration', (tester) async {
      when(
        () => mockCacheService.getCategoryById('cat-1'),
      ).thenReturn(testCategory);

      await tester.pumpWidget(
        createTestWidget(
          block: createTestBlock(),
        ),
      );
      await tester.pump();

      // 2 hours exactly
      expect(find.text('2 hours'), findsOneWidget);
    });

    testWidgets('displays minutes only duration for short block', (
      tester,
    ) async {
      when(
        () => mockCacheService.getCategoryById('cat-1'),
      ).thenReturn(testCategory);

      // Create a 30 minute block
      final block = PlannedBlock(
        id: 'block-1',
        categoryId: 'cat-1',
        startTime: testDate.add(const Duration(hours: 9)),
        endTime: testDate.add(const Duration(hours: 9, minutes: 30)),
      );

      await tester.pumpWidget(
        createTestWidget(
          block: block,
          plan: DayPlanEntry(
            meta: Metadata(
              id: dayPlanId(testDate),
              createdAt: testDate,
              updatedAt: testDate,
              dateFrom: testDate,
              dateTo: testDate.add(const Duration(days: 1)),
            ),
            data: DayPlanData(
              planDate: testDate,
              status: const DayPlanStatus.draft(),
              plannedBlocks: [block],
            ),
          ),
        ),
      );
      await tester.pump();

      // 30 minutes
      expect(find.text('30 minutes'), findsOneWidget);
    });

    testWidgets('shows tappable time selectors', (tester) async {
      when(
        () => mockCacheService.getCategoryById('cat-1'),
      ).thenReturn(testCategory);

      await tester.pumpWidget(createTestWidget(block: createTestBlock()));
      await tester.pump();

      // Find InkWell widgets for time selectors
      expect(find.byType(InkWell), findsWidgets);
    });

    testWidgets('tapping delete shows confirmation dialog', (tester) async {
      when(
        () => mockCacheService.getCategoryById('cat-1'),
      ).thenReturn(testCategory);

      await tester.pumpWidget(createTestWidget(block: createTestBlock()));
      await tester.pump();

      // Tap the delete button
      await tester.tap(find.byIcon(MdiIcons.delete));
      await tester.pumpAndSettle();

      // Verify the confirmation dialog appears
      expect(find.text('Delete Block?'), findsOneWidget);
      expect(
        find.text('This will remove the planned block from your timeline.'),
        findsOneWidget,
      );
    });

    testWidgets('cancel button closes dialog without deleting', (tester) async {
      when(
        () => mockCacheService.getCategoryById('cat-1'),
      ).thenReturn(testCategory);

      await tester.pumpWidget(createTestWidget(block: createTestBlock()));
      await tester.pump();

      // Tap delete and then cancel
      await tester.tap(find.byIcon(MdiIcons.delete));
      await tester.pumpAndSettle();

      // Find the cancel button in the dialog (there are multiple Cancel texts)
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();

      // The modal should still be visible
      expect(find.byType(PlannedBlockEditModal), findsOneWidget);
    });

    testWidgets('note field allows text entry', (tester) async {
      when(
        () => mockCacheService.getCategoryById('cat-1'),
      ).thenReturn(testCategory);

      await tester.pumpWidget(createTestWidget(block: createTestBlock()));
      await tester.pump();

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, 'My test note');
      await tester.pump();

      expect(find.text('My test note'), findsOneWidget);
    });

    testWidgets('save button is enabled for valid time range', (tester) async {
      when(
        () => mockCacheService.getCategoryById('cat-1'),
      ).thenReturn(testCategory);

      await tester.pumpWidget(createTestWidget(block: createTestBlock()));
      await tester.pump();

      // Find the Save button
      final saveButton = find.text('Save');
      expect(saveButton, findsOneWidget);

      // It should be enabled (FilledButton with valid onPressed)
      final button = tester.widget<FilledButton>(
        find.ancestor(of: saveButton, matching: find.byType(FilledButton)),
      );
      expect(button.onPressed, isNotNull);
    });

    // -------------------------------------------------------------------------
    // Save flow: calls updatePlannedBlock with correct payload
    // -------------------------------------------------------------------------

    testWidgets(
      'tapping Save calls updatePlannedBlock with correct times and note',
      (tester) async {
        when(
          () => mockCacheService.getCategoryById('cat-1'),
        ).thenReturn(testCategory);

        final controller = createController();
        await tester.pumpWidget(
          createTestWidget(
            block: createTestBlock(note: 'existing note'),
            controller: controller,
          ),
        );
        await tester.pump();

        await tester.ensureVisible(find.text('Save'));
        await tester.tap(find.text('Save'));
        await tester.pump();

        final updated = controller.lastUpdatedBlock;
        expect(updated, isNotNull);
        expect(updated!.id, 'block-1');
        expect(updated.startTime.hour, 9);
        expect(updated.startTime.minute, 0);
        expect(updated.endTime.hour, 11);
        expect(updated.endTime.minute, 0);
        // note is preserved since it is non-empty
        expect(updated.note, 'existing note');
      },
    );

    testWidgets(
      'tapping Save with empty note results in null note on updatedBlock',
      (tester) async {
        when(
          () => mockCacheService.getCategoryById('cat-1'),
        ).thenReturn(testCategory);

        // Block has no note, and TextField is left empty.
        final controller = createController();
        await tester.pumpWidget(
          createTestWidget(
            block: createTestBlock(), // note is null by default
            controller: controller,
          ),
        );
        await tester.pump();

        await tester.ensureVisible(find.text('Save'));
        await tester.tap(find.text('Save'));
        await tester.pump();

        final updated = controller.lastUpdatedBlock;
        expect(updated, isNotNull);
        // empty text → note should be null
        expect(updated!.note, isNull);
      },
    );

    // -------------------------------------------------------------------------
    // Cancel button: closes modal without calling controller
    // -------------------------------------------------------------------------

    testWidgets(
      'tapping Cancel button does not call controller update or remove',
      (tester) async {
        when(
          () => mockCacheService.getCategoryById('cat-1'),
        ).thenReturn(testCategory);

        final controller = createController();

        await tester.pumpWidget(
          createTestWidget(block: createTestBlock(), controller: controller),
        );
        await tester.pump();

        await tester.ensureVisible(find.text('Cancel'));
        await tester.tap(find.text('Cancel'));
        await tester.pump();

        // Controller should not have been called.
        expect(controller.lastUpdatedBlock, isNull);
        expect(controller.lastRemovedBlockId, isNull);
      },
    );

    // -------------------------------------------------------------------------
    // Delete confirm: calls removePlannedBlock
    // -------------------------------------------------------------------------

    testWidgets(
      'confirming delete calls removePlannedBlock with the block id',
      (tester) async {
        when(
          () => mockCacheService.getCategoryById('cat-1'),
        ).thenReturn(testCategory);

        final controller = createController();

        await tester.pumpWidget(
          createTestWidget(block: createTestBlock(), controller: controller),
        );
        await tester.pump();

        await tester.tap(find.byIcon(MdiIcons.delete));
        await tester.pumpAndSettle();

        // Tap the Delete button in the confirmation dialog.
        await tester.tap(find.text('Delete'));
        await tester.pump();

        // The controller received the correct block id.
        expect(controller.lastRemovedBlockId, 'block-1');
      },
    );

    // -------------------------------------------------------------------------
    // _formatDuration branches
    // -------------------------------------------------------------------------

    testWidgets(
      'shows invalid time range label when end is before start',
      (tester) async {
        when(() => mockCacheService.getCategoryById(any())).thenReturn(null);

        // end < start: invalid range
        final block = PlannedBlock(
          id: 'block-inv',
          categoryId: 'unknown',
          startTime: testDate.add(const Duration(hours: 11)),
          endTime: testDate.add(const Duration(hours: 9)),
        );

        await tester.pumpWidget(
          createTestWidget(
            block: block,
            plan: createTestPlan(blocks: [block]),
          ),
        );
        await tester.pump();

        expect(find.text('Invalid time range'), findsOneWidget);

        // Save button should be disabled.
        final button = tester.widget<FilledButton>(
          find.ancestor(
            of: find.text('Save'),
            matching: find.byType(FilledButton),
          ),
        );
        expect(button.onPressed, isNull);
      },
    );

    testWidgets(
      'shows exact hours label when duration is a whole number of hours',
      (tester) async {
        when(
          () => mockCacheService.getCategoryById('cat-1'),
        ).thenReturn(testCategory);

        // 3 hours exactly
        final block = PlannedBlock(
          id: 'block-3h',
          categoryId: 'cat-1',
          startTime: testDate.add(const Duration(hours: 8)),
          endTime: testDate.add(const Duration(hours: 11)),
        );

        await tester.pumpWidget(
          createTestWidget(
            block: block,
            plan: createTestPlan(blocks: [block]),
          ),
        );
        await tester.pump();

        expect(find.text('3 hours'), findsOneWidget);
      },
    );

    testWidgets(
      'shows hours and minutes label when duration has both hours and minutes',
      (tester) async {
        when(
          () => mockCacheService.getCategoryById('cat-1'),
        ).thenReturn(testCategory);

        // 1 hour 30 minutes
        final block = PlannedBlock(
          id: 'block-1h30m',
          categoryId: 'cat-1',
          startTime: testDate.add(const Duration(hours: 9)),
          endTime: testDate.add(const Duration(hours: 10, minutes: 30)),
        );

        await tester.pumpWidget(
          createTestWidget(
            block: block,
            plan: createTestPlan(blocks: [block]),
          ),
        );
        await tester.pump();

        // Format is "{hours}h {minutes}m" per ARB.
        expect(find.text('1h 30m'), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // _TimeSelector: showTimePicker updates displayed time
    // -------------------------------------------------------------------------

    testWidgets(
      'tapping start time selector opens picker and updates displayed time',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        when(
          () => mockCacheService.getCategoryById('cat-1'),
        ).thenReturn(testCategory);

        await tester.pumpWidget(
          createTestWidget(block: createTestBlock()),
        );
        await tester.pump();

        // Initial displayed start time.
        expect(find.text('09:00'), findsOneWidget);

        // Tap the start time selector (InkWell containing '09:00' label).
        await tester.ensureVisible(find.text('09:00'));
        await tester.tap(find.text('09:00'));
        await tester.pumpAndSettle();

        // The time picker dialog should now be visible.
        expect(find.byType(TimePickerDialog), findsOneWidget);

        // Dismiss the picker using OK without changing the time.
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        // The start time should still read 09:00 (picked == initialTime).
        expect(find.text('09:00'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping end time selector opens picker',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        when(
          () => mockCacheService.getCategoryById('cat-1'),
        ).thenReturn(testCategory);

        await tester.pumpWidget(
          createTestWidget(block: createTestBlock()),
        );
        await tester.pump();

        expect(find.text('11:00'), findsOneWidget);

        await tester.ensureVisible(find.text('11:00'));
        await tester.tap(find.text('11:00'));
        await tester.pumpAndSettle();

        expect(find.byType(TimePickerDialog), findsOneWidget);

        // Close by tapping Cancel in the picker dialog.
        final cancelInDialog = find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Cancel'),
        );
        await tester.tap(cancelInDialog);
        await tester.pumpAndSettle();

        // End time unchanged after cancel.
        expect(find.text('11:00'), findsOneWidget);
      },
    );
  });
}
