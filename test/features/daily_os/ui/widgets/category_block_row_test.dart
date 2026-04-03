import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/daily_os/ui/widgets/category_block_row.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_block_editor.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  final testDate = DateTime(2026, 3, 15);

  final testCategory =
      EntityDefinition.categoryDefinition(
            id: 'cat-work',
            name: 'Work',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
            private: false,
            active: true,
            color: '#6C5CE7',
          )
          as CategoryDefinition;

  final testBlock = PlannedBlock(
    id: 'block-1',
    categoryId: 'cat-work',
    startTime: DateTime(2026, 3, 15, 9),
    endTime: DateTime(2026, 3, 15, 12),
  );

  late MockEntitiesCacheService mockCache;

  setUp(() async {
    mockCache = MockEntitiesCacheService();
    when(() => mockCache.getCategoryById(any())).thenReturn(testCategory);
    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<EntitiesCacheService>(mockCache);
      },
    );
  });

  tearDown(tearDownTestGetIt);

  Future<void> pumpRow(
    WidgetTester tester, {
    List<PlannedBlock> blocks = const [],
    bool isExpanded = false,
    bool isFavorite = false,
    double width = 400,
    VoidCallback? onToggleExpand,
    ValueChanged<List<PlannedBlock>>? onBlocksChanged,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SizedBox(
          width: width,
          child: CategoryBlockRow(
            category: testCategory,
            blocks: blocks,
            planDate: testDate,
            isExpanded: isExpanded,
            isFavorite: isFavorite,
            onToggleExpand: onToggleExpand ?? () {},
            onBlocksChanged: onBlocksChanged ?? (_) {},
          ),
        ),
        theme: DesignSystemTheme.light(),
      ),
    );
  }

  group('CategoryBlockRow — collapsed', () {
    testWidgets('shows category name', (tester) async {
      await pumpRow(tester);

      expect(find.text('Work'), findsOneWidget);
    });

    testWidgets('shows tap hint when no blocks', (tester) async {
      await pumpRow(tester);

      expect(find.text('Tap to add time block'), findsOneWidget);
    });

    testWidgets('shows time chips when blocks exist', (tester) async {
      await pumpRow(tester, blocks: [testBlock]);

      expect(find.text('Tap to add time block'), findsNothing);
      expect(find.textContaining('9:00 AM'), findsOneWidget);
    });

    testWidgets('shows green checkmark when blocks exist', (tester) async {
      await pumpRow(tester, blocks: [testBlock]);

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('no checkmark when no blocks', (tester) async {
      await pumpRow(tester);

      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('shows star icon for favorites', (tester) async {
      await pumpRow(tester, isFavorite: true);

      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('no star icon for non-favorites', (tester) async {
      await pumpRow(tester);

      expect(find.byIcon(Icons.star), findsNothing);
    });

    testWidgets('calls onToggleExpand when tapped', (tester) async {
      var toggled = false;
      await pumpRow(tester, onToggleExpand: () => toggled = true);

      await tester.tap(find.text('Work'));
      await tester.pump();

      expect(toggled, isTrue);
    });
  });

  group('CategoryBlockRow — expanded', () {
    testWidgets('shows TimeBlockEditor for each block', (tester) async {
      await pumpRow(tester, blocks: [testBlock], isExpanded: true);
      await tester.pumpAndSettle();

      expect(find.byType(TimeBlockEditor), findsOneWidget);
    });

    testWidgets('shows "Add new time block" button', (tester) async {
      await pumpRow(tester, isExpanded: true);
      await tester.pumpAndSettle();

      expect(find.text('Add new time block'), findsOneWidget);
    });

    testWidgets('tapping add button calls onBlocksChanged with new block', (
      tester,
    ) async {
      List<PlannedBlock>? result;
      await pumpRow(
        tester,
        isExpanded: true,
        onBlocksChanged: (blocks) => result = blocks,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add new time block'));
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.length, 1);
      expect(result!.first.categoryId, 'cat-work');
    });

    testWidgets('removing a block calls onBlocksChanged without it', (
      tester,
    ) async {
      final block2 = PlannedBlock(
        id: 'block-2',
        categoryId: 'cat-work',
        startTime: DateTime(2026, 3, 15, 14),
        endTime: DateTime(2026, 3, 15, 15),
      );
      List<PlannedBlock>? result;
      await pumpRow(
        tester,
        blocks: [testBlock, block2],
        isExpanded: true,
        onBlocksChanged: (blocks) => result = blocks,
      );
      await tester.pumpAndSettle();

      // Tap the first delete button
      await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
      await tester.pump();

      expect(result, isNotNull);
      expect(result!.length, 1);
      expect(result!.first.id, 'block-2');
    });

    testWidgets('not expanded hides editor and add button', (tester) async {
      await pumpRow(tester, blocks: [testBlock]);

      expect(find.byType(TimeBlockEditor), findsNothing);
      expect(find.text('Add new time block'), findsNothing);
    });
  });

  group('CategoryBlockRow — _addBlock with existing blocks', () {
    testWidgets(
      'adds block starting from last block end time when blocks exist',
      (tester) async {
        final existingBlock = PlannedBlock(
          id: 'block-1',
          categoryId: 'cat-work',
          startTime: DateTime(2026, 3, 15, 14),
          endTime: DateTime(2026, 3, 15, 16, 30),
        );
        List<PlannedBlock>? result;
        await pumpRow(
          tester,
          blocks: [existingBlock],
          isExpanded: true,
          onBlocksChanged: (blocks) => result = blocks,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Add new time block'));
        await tester.pump();

        expect(result, isNotNull);
        expect(result!.length, 2);
        expect(result!.first.id, 'block-1');

        final newBlock = result![1];
        expect(newBlock.categoryId, 'cat-work');
        // startHour = 16.clamp(0, 22) = 16, minute = 30
        expect(newBlock.startTime.hour, 16);
        expect(newBlock.startTime.minute, 30);
        // endHour = 17.clamp(1, 23) = 17
        expect(newBlock.endTime.hour, 17);
        expect(newBlock.endTime.minute, 30);
      },
    );

    testWidgets(
      'clamps start to 22 and end to 23 when last block ends at 23',
      (tester) async {
        final lateBlock = PlannedBlock(
          id: 'late-block',
          categoryId: 'cat-work',
          startTime: DateTime(2026, 3, 15, 22),
          endTime: DateTime(2026, 3, 15, 23),
        );
        List<PlannedBlock>? result;
        await pumpRow(
          tester,
          blocks: [lateBlock],
          isExpanded: true,
          width: 500,
          onBlocksChanged: (blocks) => result = blocks,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Add new time block'));
        await tester.pump();

        expect(result, isNotNull);
        expect(result!.length, 2);

        final newBlock = result![1];
        // startHour = 23.clamp(0, 22) = 22
        expect(newBlock.startTime.hour, 22);
        expect(newBlock.startTime.minute, 0);
        // endHour = (22 + 1).clamp(1, 23) = 23
        expect(newBlock.endTime.hour, 23);
        expect(newBlock.endTime.minute, 0);
      },
    );

    testWidgets(
      'new block defaults to 9-10am when no blocks exist',
      (tester) async {
        List<PlannedBlock>? result;
        await pumpRow(
          tester,
          isExpanded: true,
          onBlocksChanged: (blocks) => result = blocks,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Add new time block'));
        await tester.pump();

        expect(result, isNotNull);
        expect(result!.length, 1);

        final newBlock = result!.first;
        expect(newBlock.startTime.hour, 9);
        expect(newBlock.startTime.minute, 0);
        expect(newBlock.endTime.hour, 10);
        expect(newBlock.endTime.minute, 0);
        // Verify date matches planDate
        expect(newBlock.startTime.year, 2026);
        expect(newBlock.startTime.month, 3);
        expect(newBlock.startTime.day, 15);
      },
    );

    testWidgets(
      'preserves minutes from last block end time',
      (tester) async {
        final blockWithMinutes = PlannedBlock(
          id: 'minute-block',
          categoryId: 'cat-work',
          startTime: DateTime(2026, 3, 15, 10, 15),
          endTime: DateTime(2026, 3, 15, 11, 45),
        );
        List<PlannedBlock>? result;
        await pumpRow(
          tester,
          blocks: [blockWithMinutes],
          isExpanded: true,
          width: 500,
          onBlocksChanged: (blocks) => result = blocks,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Add new time block'));
        await tester.pump();

        expect(result, isNotNull);
        final newBlock = result![1];
        // Minutes from lastEnd (11:45) are preserved
        expect(newBlock.startTime.hour, 11);
        expect(newBlock.startTime.minute, 45);
        expect(newBlock.endTime.hour, 12);
        expect(newBlock.endTime.minute, 45);
      },
    );

    testWidgets(
      'clamps correctly when last block ends at hour 22 with minutes',
      (tester) async {
        final lateBlockWithMinutes = PlannedBlock(
          id: 'late-min-block',
          categoryId: 'cat-work',
          startTime: DateTime(2026, 3, 15, 21),
          endTime: DateTime(2026, 3, 15, 22, 15),
        );
        List<PlannedBlock>? result;
        await pumpRow(
          tester,
          blocks: [lateBlockWithMinutes],
          isExpanded: true,
          width: 500,
          onBlocksChanged: (blocks) => result = blocks,
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Add new time block'));
        await tester.pump();

        expect(result, isNotNull);
        final newBlock = result![1];
        // startHour = 22.clamp(0, 22) = 22, minutes from lastEnd
        expect(newBlock.startTime.hour, 22);
        expect(newBlock.startTime.minute, 15);
        // endHour = 23.clamp(1, 23) = 23
        expect(newBlock.endTime.hour, 23);
        expect(newBlock.endTime.minute, 15);
      },
    );
  });

  group('CategoryBlockRow — _updateBlock', () {
    testWidgets(
      'updating a block replaces it at the correct index',
      (tester) async {
        final block1 = PlannedBlock(
          id: 'block-1',
          categoryId: 'cat-work',
          startTime: DateTime(2026, 3, 15, 9),
          endTime: DateTime(2026, 3, 15, 10),
        );
        final block2 = PlannedBlock(
          id: 'block-2',
          categoryId: 'cat-work',
          startTime: DateTime(2026, 3, 15, 14),
          endTime: DateTime(2026, 3, 15, 15),
        );
        List<PlannedBlock>? result;
        await pumpRow(
          tester,
          blocks: [block1, block2],
          isExpanded: true,
          onBlocksChanged: (blocks) => result = blocks,
        );
        await tester.pumpAndSettle();

        // Find the first TimeBlockEditor and tap the start time label to
        // open the picker, then change it — but that's complex. Instead,
        // we directly call the onChanged callback by finding the editor
        // widget and invoking its callback.
        final editors = tester.widgetList<TimeBlockEditor>(
          find.byType(TimeBlockEditor),
        );
        expect(editors.length, 2);

        // Invoke the onChanged callback of the first editor directly
        final firstEditor = editors.first;
        final updatedBlock = block1.copyWith(
          startTime: DateTime(2026, 3, 15, 8),
        );
        firstEditor.onChanged(updatedBlock);
        await tester.pump();

        expect(result, isNotNull);
        expect(result!.length, 2);
        // First block should be updated
        expect(result![0].startTime.hour, 8);
        expect(result![0].id, 'block-1');
        // Second block should remain unchanged
        expect(result![1].startTime.hour, 14);
        expect(result![1].id, 'block-2');
      },
    );

    testWidgets(
      'updating the second block preserves the first',
      (tester) async {
        final block1 = PlannedBlock(
          id: 'block-1',
          categoryId: 'cat-work',
          startTime: DateTime(2026, 3, 15, 9),
          endTime: DateTime(2026, 3, 15, 10),
        );
        final block2 = PlannedBlock(
          id: 'block-2',
          categoryId: 'cat-work',
          startTime: DateTime(2026, 3, 15, 14),
          endTime: DateTime(2026, 3, 15, 15),
        );
        List<PlannedBlock>? result;
        await pumpRow(
          tester,
          blocks: [block1, block2],
          isExpanded: true,
          onBlocksChanged: (blocks) => result = blocks,
        );
        await tester.pumpAndSettle();

        final editors = tester.widgetList<TimeBlockEditor>(
          find.byType(TimeBlockEditor),
        );
        final secondEditor = editors.last;
        final updatedBlock = block2.copyWith(
          endTime: DateTime(2026, 3, 15, 17),
        );
        secondEditor.onChanged(updatedBlock);
        await tester.pump();

        expect(result, isNotNull);
        expect(result!.length, 2);
        // First block unchanged
        expect(result![0].startTime.hour, 9);
        expect(result![0].endTime.hour, 10);
        // Second block updated
        expect(result![1].endTime.hour, 17);
        expect(result![1].id, 'block-2');
      },
    );
  });

  group('CategoryBlockRow — time chip formatting', () {
    testWidgets('formats AM times in chips', (tester) async {
      final amBlock = PlannedBlock(
        id: 'am-block',
        categoryId: 'cat-work',
        startTime: DateTime(2026, 3, 15, 8, 30),
        endTime: DateTime(2026, 3, 15, 10, 15),
      );
      await pumpRow(tester, blocks: [amBlock]);

      expect(find.textContaining('8:30 AM–10:15 AM'), findsOneWidget);
    });

    testWidgets('formats PM times in chips', (tester) async {
      final pmBlock = PlannedBlock(
        id: 'pm-block',
        categoryId: 'cat-work',
        startTime: DateTime(2026, 3, 15, 13),
        endTime: DateTime(2026, 3, 15, 17),
      );
      await pumpRow(tester, blocks: [pmBlock]);

      expect(find.textContaining('1:00 PM–5:00 PM'), findsOneWidget);
    });

    testWidgets('shows multiple chips for multiple blocks', (tester) async {
      final block2 = PlannedBlock(
        id: 'block-2',
        categoryId: 'cat-work',
        startTime: DateTime(2026, 3, 15, 14),
        endTime: DateTime(2026, 3, 15, 16),
      );
      await pumpRow(tester, blocks: [testBlock, block2]);

      expect(find.byIcon(Icons.schedule_rounded), findsNWidgets(2));
    });
  });
}
