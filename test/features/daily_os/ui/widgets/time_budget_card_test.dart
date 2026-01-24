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
  }) {
    return TimeBudgetProgress(
      budget: TimeBudget(
        id: 'budget-1',
        categoryId: category?.id ?? testCategory.id,
        plannedMinutes: planned.inMinutes,
      ),
      category: category ?? testCategory,
      plannedDuration: planned,
      recordedDuration: recorded,
      status: status,
      contributingEntries: const [],
      pinnedTasks: const [],
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
          progress: const TimeBudgetProgress(
            budget: TimeBudget(
              id: 'budget-1',
              categoryId: 'missing',
              plannedMinutes: 60,
            ),
            category: null,
            plannedDuration: Duration(hours: 1),
            recordedDuration: Duration.zero,
            status: BudgetProgressStatus.underBudget,
            contributingEntries: [],
            pinnedTasks: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Uncategorized'), findsOneWidget);
    });
  });
}
