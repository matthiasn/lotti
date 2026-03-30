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
    VoidCallback? onToggleExpand,
    ValueChanged<List<PlannedBlock>>? onBlocksChanged,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SizedBox(
          width: 400,
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
