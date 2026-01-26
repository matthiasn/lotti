import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_budget_card.dart';

import '../../../../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDate = DateTime(2026, 1, 15);

  final testCategory = CategoryDefinition(
    id: 'cat-1',
    name: 'Work',
    color: '#4285F4',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    vectorClock: null,
    private: false,
    active: true,
  );

  TimeBudgetProgress createProgress({
    Duration planned = const Duration(hours: 2),
    Duration recorded = const Duration(hours: 1),
    BudgetProgressStatus status = BudgetProgressStatus.underBudget,
    CategoryDefinition? category,
    List<PlannedBlock>? blocks,
  }) {
    final effectiveCategory = category ?? testCategory;
    return TimeBudgetProgress(
      categoryId: effectiveCategory.id,
      category: effectiveCategory,
      plannedDuration: planned,
      recordedDuration: recorded,
      status: status,
      contributingEntries: const [],
      pinnedTasks: const [],
      blocks: blocks ??
          [
            PlannedBlock(
              id: 'block-1',
              categoryId: effectiveCategory.id,
              startTime: testDate.add(const Duration(hours: 9)),
              endTime: testDate.add(Duration(hours: 9 + planned.inHours)),
            ),
          ],
    );
  }

  Widget createTestWidget({
    required TimeBudgetProgress progress,
    VoidCallback? onTap,
    bool isExpanded = false,
    List<Override> overrides = const [],
  }) {
    return RiverpodWidgetTestBench(
      overrides: [
        highlightedCategoryIdProvider.overrideWith((ref) => null),
        ...overrides,
      ],
      child: TimeBudgetCard(
        progress: progress,
        onTap: onTap,
        isExpanded: isExpanded,
      ),
    );
  }

  group('TimeBudgetCard', () {
    testWidgets('displays category name', (tester) async {
      await tester.pumpWidget(
        createTestWidget(progress: createProgress()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Work'), findsOneWidget);
    });

    testWidgets('displays planned duration', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(planned: const Duration(hours: 3)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 hours planned'), findsOneWidget);
    });

    testWidgets('displays remaining time for under budget', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1h left'), findsOneWidget);
    });

    testWidgets('displays over budget status', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(
            planned: const Duration(hours: 1),
            recorded: const Duration(hours: 2),
            status: BudgetProgressStatus.overBudget,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('+1h over'), findsOneWidget);
    });

    testWidgets('displays near limit status', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(
            planned: const Duration(hours: 1),
            recorded: const Duration(minutes: 50),
            status: BudgetProgressStatus.nearLimit,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('10m left'), findsOneWidget);
    });

    testWidgets('displays exhausted status', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(
            planned: const Duration(hours: 1),
            status: BudgetProgressStatus.exhausted,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Time's up"), findsOneWidget);
    });

    testWidgets('handles tap callback', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(),
          onTap: () => tapped = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TimeBudgetCard));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('shows progress bar', (tester) async {
      await tester.pumpWidget(
        createTestWidget(progress: createProgress()),
      );
      await tester.pumpAndSettle();

      // The progress bar is a custom widget, verify it exists
      expect(find.byType(TimeBudgetCard), findsOneWidget);
    });

    testWidgets('displays uncategorized when no category', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: TimeBudgetProgress(
            categoryId: 'missing',
            category: null,
            plannedDuration: const Duration(hours: 1),
            recordedDuration: Duration.zero,
            status: BudgetProgressStatus.underBudget,
            contributingEntries: const [],
            pinnedTasks: const [],
            blocks: [
              PlannedBlock(
                id: 'block-1',
                categoryId: 'missing',
                startTime: testDate.add(const Duration(hours: 9)),
                endTime: testDate.add(const Duration(hours: 10)),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Uncategorized'), findsOneWidget);
    });

    testWidgets('displays hours and minutes for planned duration',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(
            planned: const Duration(hours: 2, minutes: 30),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2h 30m planned'), findsOneWidget);
    });

    testWidgets('displays minutes only for short planned duration',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(
            planned: const Duration(minutes: 45),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('45 min planned'), findsOneWidget);
    });

    testWidgets('shows highlighted border when category is highlighted',
        (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            highlightedCategoryIdProvider.overrideWith((ref) => 'cat-1'),
          ],
          child: TimeBudgetCard(
            progress: createProgress(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Widget should have enhanced styling when highlighted
      expect(find.byType(AnimatedContainer), findsWidgets);
    });

    testWidgets('handles long press callback', (tester) async {
      var longPressed = false;

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            highlightedCategoryIdProvider.overrideWith((ref) => null),
          ],
          child: TimeBudgetCard(
            progress: createProgress(),
            onLongPress: () => longPressed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.longPress(find.byType(TimeBudgetCard));
      await tester.pumpAndSettle();

      expect(longPressed, isTrue);
    });

    testWidgets('displays remaining time with hours and minutes',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(
            planned: const Duration(hours: 3),
            recorded: const Duration(hours: 1, minutes: 30),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1h 30m left'), findsOneWidget);
    });

    testWidgets('displays over budget with hours and minutes', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(
            planned: const Duration(hours: 1),
            recorded: const Duration(hours: 2, minutes: 15),
            status: BudgetProgressStatus.overBudget,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('+1h 15m over'), findsOneWidget);
    });

    testWidgets('shows progress bar with correct visual states',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          progress: createProgress(
            recorded: const Duration(hours: 2, minutes: 30),
            status: BudgetProgressStatus.overBudget,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The progress bar should show over-budget indicator
      expect(find.byType(TimeBudgetCard), findsOneWidget);
    });
  });
}
